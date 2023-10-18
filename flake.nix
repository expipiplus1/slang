{
  description = "The Slang compiler";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mini-compile-commands = {
      url = "github:expipiplus1/mini_compile_commands";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, gitignore, mini-compile-commands }:
    let
      sysHelper = stdenv: rec {
        # Some helpful utils for constructing the below derivations
        arch = {
          x86_64-linux = "x64";
          i686-linux = "x86";
          aarch64-linux = "aarch64";
        }.${stdenv.hostPlatform.system};
        commonPremakeFlags = [ "gmake2" "--deps=false" "--arch=${arch}" ]
          ++ nixpkgs.lib.optional stdenv.cc.isClang "--cc=clang";
        makeFlags = [ "config=release_${arch}" "verbose=1" ];
      };

      # We build slang-glslang from source, ignoring whatever's in the
      # submodule
      slang-glslang = { stdenv, fetchFromGitHub, premake5 }:
        with sysHelper stdenv;
        stdenv.mkDerivation {
          name = "slang-glslang";
          src = fetchFromGitHub {
            owner = "shader-slang";
            repo = "slang-glslang";
            rev = "8c732f5d1868cba621bffc1d5085a5a18dae2683";
            sha256 = "01jjgq3dshcgdpbanpcp8lkd610gz00v6sbn6z2ln6a8ymvmh8bh";
            fetchSubmodules = true;
          };
          nativeBuildInputs = [ premake5 ];
          premakeFlags = commonPremakeFlags;
          inherit makeFlags;
          enableParallelBuilding = true;

          installPhase = ''
            mkdir -p $out/lib
            cp bin/*/release/*.so "$out/lib"
          '';
        };

      # We build slang-llvm using the LLVM in nixpkgs, speeds things up
      slang-llvm = { stdenv, fetchFromGitHub, symlinkJoin, premake5, ncurses
        , libclang, llvm }:
        with sysHelper stdenv;
        stdenv.mkDerivation {
          name = "slang-llvm";
          src = fetchFromGitHub {
            owner = "shader-slang";
            repo = "slang-llvm";
            rev = "0e48669c5a8e94589f5614104bdee77cf165be25";
            sha256 = "13jkvyrhfixvij4rqvis6azq5sdhfqfq6pv1z6aybynfcxr6wdg4";
            fetchSubmodules = true;
          };
          # patches = [ ./hidden-llvm.patch ];
          NIX_LDFLAGS = [
            "-lncurses"
            # We need `--exclude-libs All` (or at least `--exclude-libs
            # llvm1,llvm2...`) to avoid exporting anything from llvm which could
            # clash with other LLVM's loaded at runtime, for example from LLVMPipe.
            # This typically manifests with a message like:
            # "inconsistency in registered CommandLine options" followed by segfault.
            # (TODO: On macOS use: -hidden-l... instead of -l...)
            "--exclude-libs"
            "ALL"
          ];
          nativeBuildInputs = [ premake5 ];
          buildInputs = [ libclang llvm ncurses ];
          premakeFlags = commonPremakeFlags ++ [
            "--llvm-path=${
              symlinkJoin {
                name = "llvm-and-clang";
                paths = [ llvm.lib libclang.lib ];
                postBuild = ''
                  ln -s . $out/build
                '';
              }
            }"
          ];
          inherit makeFlags;
          shellHook = ''
            export NIX_HARDENING_ENABLE="stackprotector pic strictoverflow format relro bindnow";
          '';
          enableParallelBuilding = true;
          installPhase = ''
            mkdir -p $out/lib
            # TODO: Neaten
            cp bin/*/release/*.a --target-directory "$out/lib"
            cp bin/*/release/*.so --target-directory "$out/lib"
          '';
        };

      shader-slang = {
        # build tools
        lib, stdenv, premake5, makeWrapper
        # internal deps
        , slang-glslang, slang-llvm
        # external deps
        , spirv-tools, libX11, gcc
        # cuda
        , cudaPackages, optix-headers, addOpenGLRunpath
        # vulkan
        , vulkan-loader, vulkan-validation-layers, vulkan-tools-lunarg
        # directx
        , dxvk_2, vkd3d, vkd3d-proton, dxvk-native-headers
        , directx-shader-compiler
        # devtools
        , glslang, cmake, python3, clang_16, bear, renderdoc
        , writeShellScriptBin, swiftshader, vulkan-tools, spirv-cross
        # "release" or "debug"
        , buildConfig ? "release"
          # Put the cuda libraries in LD_LIBRARY_PATH and build with the cuda and
          # optix toolkits
        , enableCuda ? false
          # Allow loading and running DXC to generate DXIL output
        , enableDXC ? true
          # Use dxvk and vkd3d-proton for dx11 and dx12 support (dx11 is not
          # very useful, as we don't have FXC so can't generate shaders, dxvk
          # is necessary however to supply libdxgi)
          # This is only for the test suite, not for the compiler itself
        , enableDirectX ? true
          # Put Swiftshader in the shell environment and force its usage via
          # VK_ICD_FILENAMES, again, only used for tests
        , enableSwiftshader ? false }:
        with sysHelper stdenv;
        let
          # A script in the devshell which calls `make` with the
          # correct options for the arch, call like `mk` (for a debug
          # build) or `mk release` for a release build. It also starts
          # `slangc` to generate stdlib as early as possible and waits
          # for that to complete.
          make-helper = writeShellScriptBin "mk" ''
            if [ -z "$1" ]
            then
              config=debug
            else
              config="$1"
            fi
            make config="$config""_${arch}" -j$(nproc) slangc
            "./bin/linux-${arch}/$config/slangc" & slangc=$!
            make config="$config""_${arch}" -j$(nproc)
            echo "done building, waiting for slangc..."
            wait $slangc
            echo ...done
          '';

          # A script in the devshell which cleans the build output and
          # regenerates it with clang, capturing a
          # `compile_commands.json` file for use with any build tool
          # which supports that, for example the clangd LSP server.
          gen-compile-commands = writeShellScriptBin "gen-compile-commands" ''
            git clean -x -f \
              Makefile \
              bin/ \
              build/ \
              intermediate/ \
              source/slang/slang-generated-* \
              source/slang/*.meta.slang.h \
              prelude/slang-*-prelude.h.cpp

            export CC=${clang_16}/bin/clang
            export CXX=${clang_16}/bin/clang++
            premake5 $premakeFlags --cc=clang "$@"
            ${bear}/bin/bear \
              --append \
              -- make --ignore-errors --keep-going config=debug_${arch} -j$(nproc)
          '';

          test-helper = writeShellScriptBin "t" ''
            shopt -s nullglob

            bins=("bin/linux-${arch}"/{release,debug}/slang-test)
            bin=
            for file in "''${bins[@]}"; do
              [[ $file -nt "$bin" ]] && bin=$file
            done

            exec "$bin" "$@"
          '';

          test-shader-helper = writeShellScriptBin "auto" ''
            shopt -s nullglob

            bins=("bin/linux-${arch}"/{release,debug}/slangc)
            bin=
            for file in "''${bins[@]}"; do
              [[ $file -nt $bin ]] && bin=$file
            done

            [ -z "$bin" ] && echo "Unable to find any of ''${bins[@]}" && exit 1

            file=
            stage=
            entry=

            go(){
              for e in $(grep --only-matching --no-messages "$2" -- "$arg"); do
                stage=$1
                entry=$e
              done
            }

            for arg in "$@"; do
              if [ "$explicit" ]; then
                stage="$arg"
                entry="$arg"Main
                break
              fi
              if [[ "$arg" == -stage ]]; then
                explicit=1
              fi
            done

            if ! [ "$explicit" ]; then
              for arg in "$@"; do
                if [[ "$arg" == *.slang ]]; then
                  file="$arg"
                  for s in compute vertex fragment; do
                    go "$s" "$s"Main
                  done
                fi
              done

              [ -z "$file" ] && echo "Unable to find a .slang file in args" && exit 1
              [ ! -f "$file" ] && echo "$file doesn't exist" && exit 1
              [ -z "$stage" ] && echo "Unable to determine stage for $file" && exit 1
              [ -z "$entry" ] && echo "Unable to determine entry point for $file" && exit 1
            fi

            if [ "$explicit" ]; then
              set -x
              "$bin" \
                -line-directive-mode none \
                "$@"
            else
              set -x
              "$bin" \
                -line-directive-mode none \
                -entry "$entry" \
                -stage "$stage" \
                "$@"
            fi
          '';

          runtimeLibraries = [ slang-llvm ]
            ++ lib.optional enableDXC directx-shader-compiler;
          runtimeLibraryPath = lib.makeLibraryPath runtimeLibraries;
          testsRuntimeLibraryPath = lib.makeLibraryPath (runtimeLibraries
            ++ [ vulkan-loader ] ++ lib.optionals enableCuda [
              # for libcuda.so
              addOpenGLRunpath.driverLink
              # for libnvrtc.so
              cudaPackages.cudatoolkit.out
            ] ++ lib.optionals enableDirectX [
              # for dx11
              dxvk_2
              # for vkd3d-shader.sh (d3dcompiler)
              vkd3d
              # for dx12
              vkd3d-proton
            ] ++ lib.optional enableSwiftshader libX11);

        in stdenv.mkDerivation {
          name = "slang";
          src = self;
          nativeBuildInputs = [ premake5 makeWrapper ] ++
            # So we can find libcuda.so at runtime in /run/opengl or wherever
            lib.optional enableCuda cudaPackages.autoAddOpenGLRunpathHook;
          NIX_LDFLAGS =
            lib.optional enableCuda "-L${cudaPackages.cudatoolkit}/lib/stubs";
          autoPatchelfIgnoreMissingDeps = lib.optional enableCuda "libcuda.so";

          buildInputs = [ spirv-tools libX11 ]
            ++ lib.optional enableDirectX dxvk-native-headers
            ++ lib.optional enableCuda cudaPackages.cudatoolkit;

          premakeFlags = commonPremakeFlags ++ [
            "--build-glslang=true"
            "--slang-llvm-path=${slang-llvm}"
            "--slang-glslang-path=${slang-glslang}"
            "--deploy-slang-llvm=false"
            "--deploy-slang-glslang=false"
          ] ++ lib.optionals enableCuda [
            "--cuda-sdk-path=${cudaPackages.cudatoolkit}"
            "--optix-sdk-path=${optix-headers}"
          ] ++ lib.optional enableDirectX "--dx-on-vk=true"
            ++ lib.optional enableSwiftshader "--enable-xlib=false";
          makeFlags = [ "config=${buildConfig}_${arch}" ];
          enableParallelBuilding = true;
          hardeningDisable = lib.optional (buildConfig == "debug") "fortify";

          installPhase = ''
            runHook preInstall

            mkdir -p $out/include/
            cp slang.h $out/include/
            cp slang-com-helper.h $out/include/
            cp slang-com-ptr.h $out/include/
            cp slang-tag-version.h $out/include/
            cp slang-gfx.h $out/include/

            mkdir -p $out/share/prelude
            cp prelude/*.h $out/share/prelude/

            mkdir -p $out/lib
            mv bin/*/${buildConfig}/*.so $out/lib
            rm bin/*/${buildConfig}/*.a

            mkdir -p $out/bin
            cp bin/*/${buildConfig}/* $out/bin

            mkdir -p $out/share/doc
            cp docs/*.md $out/share/doc/

            runHook postInstall
          '';

          postFixup = ''
            for bin in $(find "$out" -executable -type f -not -name slangc); do
              if [[ $bin == */slangc ]] then
                wrapProgram $bin \
                  --prefix PATH : ${lib.makeBinPath [ spirv-tools gcc ]} \
                  --prefix LD_LIBRARY_PATH : ${runtimeLibraryPath}
              else
                wrapProgram $bin \
                  --prefix PATH : ${lib.makeBinPath [ spirv-tools gcc ]} \
                  --prefix LD_LIBRARY_PATH : ${testsRuntimeLibraryPath}
              fi
            done
          '';

          shellHook = ''
            export PATH="''${PATH:+''${PATH}:}${
              lib.makeBinPath [
                # Useful for testing, although the actual glslang
                # implementation used in the compiler comes from slang-glslang
                # above, similarly dxc is loaded via shared library
                glslang
                directx-shader-compiler
                renderdoc
                vulkan-tools
                spirv-cross
                # Build utilities from this flake
                gen-compile-commands
                make-helper
                test-shader-helper
                test-helper
                # Used in the bump-glslang.sl script
                cmake
                python3
              ]
            }"

            export LD_LIBRARY_PATH="${testsRuntimeLibraryPath}''${LD_LIBRARY_PATH:+:''${LD_LIBRARY_PATH}}"

            # cuda
            ${lib.optionalString enableCuda ''
              export CUDA_PATH="${cudaPackages.cudatoolkit}''${CUDA_PATH:+:''${CUDA_PATH}}"
            ''}

            # dxvk and vkd3d-proton
            ${lib.optionalString enableDirectX ''
              # Make dxvk and vkd3d-proton less noisy
              export VKD3D_DEBUG=err
              export DXVK_LOG_LEVEL=error
            ''}

            # Provision several handy Vulkan tools and make them available
            export VK_LAYER_PATH="${
              let
                # A helper to construct a vk layer path from a list of packages
                makeVkLayerPath = ps:
                  # Eww, some packages put things in etc and others in share. This ruins the
                  # order, but ehh
                  lib.concatStringsSep ":"
                  (map (p: lib.makeSearchPathOutput "lib" p ps) [
                    "share/vulkan/explicit_layer.d"
                    "share/vulkan/implicit_layer.d"
                    "etc/vulkan/explicit_layer.d"
                    "etc/vulkan/implicit_layer.d"
                  ]);
              in makeVkLayerPath ([
                vulkan-validation-layers
                vulkan-tools-lunarg
                renderdoc
              ])
            }''${VK_LAYER_PATH:+:''${VK_LAYER_PATH}}"

            ${lib.optionalString enableSwiftshader ''
              export VK_ICD_FILENAMES=${swiftshader}/share/vulkan/icd.d/vk_swiftshader_icd.json
            ''}

            # Disable 'fortify' hardening as it makes warnings in debug mode
            # Disable 'format' hardening as some of the tests generate offending output
            export NIX_HARDENING_ENABLE="stackprotector pic strictoverflow relro bindnow"
          '';
        };

      overlay = (self: super: {
        # The Slang packages themselves
        slang-glslang = self.callPackage slang-glslang { };
        slang-llvm = self.callPackage slang-llvm {
          inherit (self.llvmPackages_13) libclang llvm;
        };
        shader-slang = self.callPackage shader-slang { };

        #
        # A few tweaks to other things
        #

        # DXVK with the none-wsi patch, we don't need SDL or GLFW
        dxvk_2 = (super.dxvk_2.override {
          sdl2Support = false;
          glfwSupport = false;
        }).overrideAttrs (old: {
          src = self.fetchFromGitHub {
            owner = "doitsujin";
            repo = "dxvk";
            rev = "9cf84f8ac2314796e70515c481dab8b102f6bcf6"; # pin
            sha256 = "0rmglwb81v5f2afgwskhrzx03l8finz3454zn42xpwjyl9jg5arv";
            fetchSubmodules = true;
          };
          mesonFlags = old.mesonFlags or [ ] ++ [ "-Ddxvk_native_wsi=none" ];
        });

        optix-headers = self.fetchzip {
          url =
            "https://developer.download.nvidia.com/redist/optix/v7.3/OptiX-7.3.0-Include.zip";
          sha256 = "0max1j4822mchj0xpz9lqzh91zkmvsn4py0r174cvqfz8z8ykjk8";
        };

        # Sadly there's no unified place to get Linux compatible DX
        # headers which include a compatible <windows.h> shim, so
        # construct them ourselves from the dxvk headers (with a bumped
        # version of the d3d12 headers)
        dxvk-native-headers = self.symlinkJoin {
          name = "dxvk-native-headers";
          paths = [
            (self.fetchFromGitHub {
              owner = "expipiplus1";
              repo = "mingw-directx-headers";
              rev = "aa5dc120215c9ef929a41b636e635c582a88d771"; # headers
              sha256 = "0v0f5z7kbdhny31i8w3iw6pn8iikyczadjr9acmq5cv6s2q98zba";
            })
            (self.dxvk_2.src + "/include/native/windows")
            (self.dxvk_2.src + "/include/native")
          ];
          postBuild = ''
            ln -s . $out/include
          '';
        };

      });
    in {
      packages = nixpkgs.lib.attrsets.genAttrs [
        "i686-linux"
        "x86_64-linux"
        "aarch64-linux"
      ] (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ overlay ];
          };
        in rec {
          inherit (pkgs) slang-llvm slang-glslang;
          slang = pkgs.shader-slang;
          slang-debug =
            pkgs.enableDebugging (slang.override { buildConfig = "debug"; });

          slang-compile-commands = let
            mcc-env = (pkgs.callPackage mini-compile-commands { }).wrap
              pkgs.llvmPackages_13.stdenv;
            mcc-hook = (pkgs.callPackage mini-compile-commands { }).hook;
          in (slang.override {
            stdenv = mcc-env;
            buildConfig = "debug";
          }).overrideAttrs
          (old: { buildInputs = (old.buildInputs or [ ]) ++ [ mcc-hook ]; });

          default = slang;
        });
    };
}
