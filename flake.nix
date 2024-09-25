{
  description = "The Slang compiler";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      shader-slang = {
        # build tools
        lib, stdenv, makeWrapper, cmake, ninja, pkg-config, premake5
        # external deps
        , spirv-tools, libX11, gcc, llvm, libclang, zlib, libxml2
        # cuda
        , cudaPackages, optix-headers, addOpenGLRunpath, autoAddDriverRunpath
        # vulkan
        , vulkan-loader, vulkan-validation-layers, vulkan-tools-lunarg
        # directx
        , dxvk_2, vkd3d, vkd3d-proton, dxvk-native-headers
        , directx-shader-compiler
        # devtools
        , glslang, python3, clang_16, bear, renderdoc, writeShellScriptBin
        , swiftshader, vulkan-tools, spirv-cross, gersemi, pkgsCross
        # "release" or "debug"
        , buildConfig ? "release"
          # Put the cuda libraries in LD_LIBRARY_PATH and build with the cuda and
          # optix toolkits
        , enableCuda ? true
          # Allow loading and running DXC to generate DXIL output
        , enableDXC ? true
          # Use dxvk and vkd3d-proton for dx11 and dx12 support (dx11 is not
          # very useful, as we don't have FXC so can't generate shaders, dxvk
          # is necessary however to supply libdxgi)
          # This is only for the test suite, not for the compiler itself
        , enableDirectX ? false
          # Put Swiftshader in the shell environment and force its usage via
          # VK_ICD_FILENAMES, again, only used for tests
        , enableSwiftshader ? false }:
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
            cmake --build --preset debug --target slangc
            "./build/Debug/bin/slangc" & slangc=$!
            cmake --build --preset debug
            echo "done building, waiting for slangc..."
            wait $slangc
            echo ...done
          '';

          clean-build-helper = writeShellScriptBin "clean-build" ''
            rm -rf ./build

            cmake --preset default \
              $cmakeFlags \
              -DSLANG_EMBED_STDLIB=1 \
              -DSLANG_EMBED_STDLIB_SOURCE=0 \
              -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
              -DCMAKE_CXX_COMPILER=clang++ \
              -DCMAKE_C_COMPILER=clang \
              --fresh
            cp build/compile_commands.json .
            cmake --build --preset debug --target spirv-dis --target spirv-val --target spirv-opt --target glslang-standalone
            cmake --preset default \
              $cmakeFlags \
              --fresh
            mk "$@"
          '';

          worktree-helper = writeShellScriptBin "new-worktree" ''
            git worktree add ../"slang-$1" -b "slang-$1" origin/master
          '';

          test-helper = writeShellScriptBin "t" ''
            shopt -s nullglob

            bins=(build/{Release,Debug}/bin/slang-test)
            bin=
            for file in "''${bins[@]}"; do
              [[ $file -nt "$bin" ]] && bin=$file
            done

            set -x
            exec "$bin" -use-test-server "$@"
          '';

          test-shader-helper = writeShellScriptBin "a" ''
            shopt -s nullglob

            bins=(build/{Release,Debug}/bin/slangc)
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
                if [[ "$arg" == *.slang ]] || [[ "$arg" == *.hlsl ]]; then
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

          runtimeLibraries = lib.optional enableDXC directx-shader-compiler;
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
          nativeBuildInputs =
            [ pkg-config cmake ninja makeWrapper gersemi clang_16 premake5 ] ++
            # So we can find libcuda.so at runtime in /run/opengl or wherever
            lib.optional enableCuda autoAddDriverRunpath;
          NIX_LDFLAGS =
            lib.optional enableCuda "-L${cudaPackages.cudatoolkit}/lib/stubs";
          autoPatchelfIgnoreMissingDeps = lib.optional enableCuda "libcuda.so";

          cmakeFlags = [
            "-DSLANG_SLANG_LLVM_FLAVOR=USE_SYSTEM_LLVM"
            "-DSLANG_ENABLE_DX_ON_VK=${if enableDirectX then "1" else "0"}"
          ];

          buildInputs = [ spirv-tools libX11 llvm libclang zlib libxml2 ] ++ [
            # For any cross build of llvm
            pkgsCross.aarch64-multiplatform.ncurses
            pkgsCross.aarch64-multiplatform.libxml2
            pkgsCross.aarch64-multiplatform.xz
            pkgsCross.aarch64-multiplatform.zlib
          ] ++ lib.optional enableDirectX dxvk-native-headers
            ++ lib.optional enableCuda cudaPackages.cudatoolkit;

          enableParallelBuilding = true;
          hardeningDisable = lib.optional (buildConfig == "debug") "fortify";

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
                # glslang
                directx-shader-compiler
                renderdoc
                spirv-cross
                # Build utilities from this flake
                make-helper
                clean-build-helper
                worktree-helper
                test-shader-helper
                test-helper
                # Used in the bump-glslang.sh script
                python3
                # For cross builds
                pkgsCross.aarch64-multiplatform.buildPackages.gcc
              ]
            }"

            export LD_LIBRARY_PATH="${testsRuntimeLibraryPath}''${LD_LIBRARY_PATH:+:''${LD_LIBRARY_PATH}}"

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
                vulkan-tools-lunarg
                renderdoc
              ])
            }''${VK_LAYER_PATH:+:''${VK_LAYER_PATH}}"

            # Disable 'fortify' hardening as it makes warnings in debug mode
            # Disable 'format' hardening as some of the tests generate offending output
            export NIX_HARDENING_ENABLE="stackprotector pic strictoverflow relro bindnow"
          '' + lib.optionalString enableSwiftshader ''
            export VK_ICD_FILENAMES=${swiftshader}/share/vulkan/icd.d/vk_swiftshader_icd.json
          '' + lib.optionalString enableCuda ''
            # cuda
            export CUDA_PATH="${cudaPackages.cudatoolkit}''${CUDA_PATH:+:''${CUDA_PATH}}"
          '' + lib.optionalString enableDirectX ''
            # dxvk and vkd3d-proton
            # Make dxvk and vkd3d-proton less noisy
            export VKD3D_DEBUG=err
            export DXVK_LOG_LEVEL=error
          '';
        };

      modifyLlvmPackages = base:
        { toolsFunc ? final: prev: { }, libsFunc ? final: prev: { } }:
        let
          tools = base.tools.extend toolsFunc;
          libraries = base.libraries.extend libsFunc;
        in {
          inherit (base) release_version;
          inherit tools libraries;
        } // tools // libraries;

      overlay = (self: super: {
        # The Slang package itself
        shader-slang = self.callPackage shader-slang {
          # inherit (self.llvmPackages_13) libclang llvm;
          inherit (modifyLlvmPackages self.llvmPackages_13 {
            toolsFunc = lself: lsuper: {
              libllvm =
                lsuper.libllvm.override { enableSharedLibraries = false; };
              # libllvm = lsuper.libllvm.overrideAttrs (old: {
              #   cmakeFlags = old.cmakeFlags or [ ]
              #     ++ [ "-DLLVM_LINK_LLVM_DYLIB=OFF" ];
              # });
            };
          })
            libclang llvm;
        };

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
          sha256 = "sha256-Nqs/6UBDapq9zk+tYYdszhVQY8Cg9koFjvKxHcBQrGg=";
          postFetch = ''
            mkdir -p $out/include
            shopt -s extglob
            mv --target-directory $out/include $out/!(include)
          '';
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
              rev = "353b4c7606126f00bd0c9264b6ab1da48391eb00"; # headers
              sha256 = "0pixlxk17a1l91xyai98jw5zm7kddy5lyqq9xdknn443ycy0b6kp";
            })
            (self.dxvk_2.src + "/include/native/windows")
            (self.dxvk_2.src + "/include/native")
          ];
          postBuild = ''
            ln -s . $out/include

            # Also pull in the d3dx12 headers from the official repo
            # These require a little wrapper
            cp ${
              (self.fetchFromGitHub {
                owner = "Microsoft";
                repo = "DirectX-Headers";
                rev = "3654cebda60262111c7b43ea140d33f21e0daa0b"; # pin
                sha256 = "1z1j23lpjvvv2pm660ad46gvfnid4xf4flrqjk3710my4mgldqv7";
              })
            }/include/directx/d3dx12*.h $out/
            mv $out/d3dx12.h $out/d3dx12-unwrapped.h
            cat > $out/d3dx12.h <<EOF
            #pragma once

            #include <limits.h>

            // SAL defines
            #define _In_
            #define _Out_
            #define _Outptr_
            #define _In_reads_(x)
            #define _In_reads_opt_(x)
            #define _In_range_(x, y)
            #define _In_opt_
            #define _Always_(x)
            #define __analysis_assume(x)

            inline HANDLE GetProcessHeap(){ return 0; }
            inline void* HeapAlloc(HANDLE, DWORD flags, SIZE_T size){
              const DWORD HEAP_ZERO_MEMORY = 0x00000008;
              return flags & HEAP_ZERO_MEMORY ? calloc(1, size) : malloc(size);
            }
            inline void HeapFree(HANDLE, DWORD, void* ptr){
              free(ptr);
            }

            #include "d3dx12-unwrapped.h"
            EOF
          '';
        };

        vulkan-validation-layers = super.vulkan-validation-layers.overrideAttrs
          (old: { separateDebugInfo = true; });

        gersemi = self.python3Packages.buildPythonApplication rec {
          pname = "gersemi";
          version = "0.9.3";
          src = self.fetchPypi {
            inherit pname version;
            sha256 = "sha256-fNhmq9KKOwlc50iDEd9pqHCM0br9Yt+nKtrsoS1d5ng=";
          };
          doCheck = false;
          propagatedBuildInputs = [
            self.python3Packages.appdirs
            self.python3Packages.lark
            self.python3Packages.pyyaml
          ];
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
          # slang = pkgs.pkgsCross.aarch64-multiplatform.shader-slang.override {
          #   enableCuda = false;
          #   enableDirectX = false;
          #   enableDXC = false;
          # };
          slang = (pkgs.shader-slang.override {
            stdenv = pkgs.stdenvAdapters.useMoldLinker pkgs.stdenv;
          }).overrideAttrs (old: {
            CMAKE_CXX_COMPILER_LAUNCHER = "${pkgs.sccache}/bin/sccache";
            CMAKE_C_COMPILER_LAUNCHER = "${pkgs.sccache}/bin/sccache";
          });
          slang-debug = pkgs.enableDebugging (slang.override {
            buildConfig = "debug";
            stdenv = pkgs.stdenvAdapters.useMoldLinker pkgs.ccacheStdenv;
            vkd3d-proton = pkgs.vkd3d-proton.overrideAttrs
              (old: { separateDebugInfo = true; });
            vkd3d =
              pkgs.vkd3d.overrideAttrs (old: { separateDebugInfo = true; });
            vulkan-validation-layers =
              pkgs.vulkan-validation-layers.overrideAttrs
              (old: { separateDebugInfo = true; });
          });

          default = slang;
        });
    };
}
