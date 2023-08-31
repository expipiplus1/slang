{
  description = "The Slang compiler";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, gitignore }: {
    packages = nixpkgs.lib.attrsets.genAttrs [
      "i686-linux"
      "x86_64-linux"
      "aarch64-linux"
    ] (system:
      let
        # Put the cuda libraries in LD_LIBRARY_PATH and build with the cuda and
        # optix toolkits
        enableCuda = true;
        # Allow loading and running DXC to generate DXIL output
        enableDXC = true;
        # Use dxvk and vkd3d-proton for dx11 and dx12 support (dx11 is not
        # very useful, as we don't have FXC so can't generate shaders, dxvk
        # is necessary however to supply libdxgi)
        enableDirectX = true;

        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (self: super: {

              # DXVK with the none-wsi patch, we don't need SDL or GLFW
              dxvk_2 = (super.dxvk_2.override {
                sdl2Support = false;
                glfwSupport = false;
              }).overrideAttrs (old: {
                src = self.fetchFromGitHub {
                  owner = "doitsujin";
                  repo = "dxvk";
                  rev = "c611baac8c3a84051309c2d8111d533ad229de7b"; # pin
                  sha256 =
                    "0ra11yv7dg99z1896mr4m3cgdh0sp4mr6fsy07swn869yvl1nclp";
                  fetchSubmodules = true;
                };
                mesonFlags = old.mesonFlags or [ ]
                  ++ [ "-Ddxvk_native_wsi=none" ];
              });

              optix-headers = pkgs.fetchzip {
                url =
                  "https://developer.download.nvidia.com/redist/optix/v7.3/OptiX-7.3.0-Include.zip";
                sha256 = "0max1j4822mchj0xpz9lqzh91zkmvsn4py0r174cvqfz8z8ykjk8";
              };

              # Sadly there's no unified place to get Linux compatible DX
              # headers which include a compatible <windows.h> shim, so
              # construct them ourselves from the dxvk headers (with a bumped
              # version of the d3d12 headers)
              dxvk-native-headers = pkgs.symlinkJoin {
                name = "dxvk-native-headers";
                paths = [
                  (pkgs.fetchFromGitHub {
                    owner = "expipiplus1";
                    repo = "mingw-directx-headers";
                    rev = "aa5dc120215c9ef929a41b636e635c582a88d771"; # headers
                    sha256 =
                      "0v0f5z7kbdhny31i8w3iw6pn8iikyczadjr9acmq5cv6s2q98zba";
                  })
                  (self.dxvk_2.src + "/include/native/windows")
                  (self.dxvk_2.src + "/include/native")
                ];
                postBuild = ''
                  ln -s . $out/include
                '';
              };
            })
          ];
        };

        # A helper to construct a vk layer path from a list of packages
        makeVkLayerPath = with pkgs.lib;
          ps:
          # Eww, some packages put things in etc and others in share. This ruins the
          # order, but ehh
          concatStringsSep ":" [
            (makeSearchPathOutput "lib" "share/vulkan/explicit_layer.d" ps)
            (makeSearchPathOutput "lib" "share/vulkan/implicit_layer.d" ps)
            (makeSearchPathOutput "lib" "etc/vulkan/explicit_layer.d" ps)
            (makeSearchPathOutput "lib" "etc/vulkan/implicit_layer.d" ps)
          ];

        # A script in the devshell which calls `make` with the correct options
        # for the arch, call like `mk` (for a debug build) or `mk release` for
        # a release build. It also starts `slangc` to generate stdlib as early
        # as possible and waits for that to complete.
        make-helper = pkgs.writeShellScriptBin "mk" ''
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
        # regenerates it with clang, capturing a `compile_commands.json` file
        # for use with any build tool which supports that, for example the
        # clangd LSP server.
        gen-compile-commands =
          pkgs.writeShellScriptBin "gen-compile-commands" ''
            git clean -x -f \
              Makefile \
              bin/ \
              build/ \
              intermediate/ \
              source/slang/slang-generated-* \
              source/slang/*.meta.slang.h \
              prelude/slang-*-prelude.h.cpp

            export CC=${pkgs.clang_16}/bin/clang
            export CXX=${pkgs.clang_16}/bin/clang++
            premake5 $premakeFlags --cc=clang "$@"
            ${pkgs.bear}/bin/bear --append -- make --ignore-errors --keep-going config=debug_${arch} -j$(nproc)
          '';

        # Some helpful utils for constructing the below derivations
        arch = {
          x86_64-linux = "x64";
          i686-linux = "x86";
          aarch64-linux = "aarch64";
        }.${system};
        commonPremakeFlags = [ "gmake2" "--deps=false" "--arch=${arch}" ];
        makeFlags = [ "config=release_${arch}" "verbose=1" ];

      in rec {
        default = slang;

        # We build slang-glslang from source, ignoring whatever's in the
        # submodule
        slang-glslang = with pkgs;
          stdenv.mkDerivation {
            name = "slang-glslang";
            src = fetchFromGitHub {
              owner = "expipiplus1";
              repo = "slang-glslang";
              rev = "8c732f5d1868cba621bffc1d5085a5a18dae2683";
              sha256 = "sha256-cCFYd/VIGUvFN3ZpswH4DwTTJkWXXavWbY9B3QZ+UgY=";
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
        slang-llvm = with pkgs;
          stdenv.mkDerivation {
            name = "slang-llvm";
            src = fetchFromGitHub {
              owner = "shader-slang";
              repo = "slang-llvm";
              rev = "3a97b3861cf663b47c9151b83e4a9b1a7eb1a36a";
              sha256 = "1plbyp2f6m3v9ap23hvbp8aarvd6skjqf6s7zgcmb6pcmqfca454";
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
            buildInputs =
              [ llvmPackages_13.libclang llvmPackages_13.llvm ncurses ];
            premakeFlags = commonPremakeFlags ++ [
              "--llvm-path=${
                symlinkJoin {
                  name = "llvm-and-clang";
                  paths =
                    [ llvmPackages_13.llvm.lib llvmPackages_13.libclang.lib ];
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

        slang = with pkgs;
          stdenv.mkDerivation {
            name = "slang";
            src = gitignore.lib.gitignoreSource ./.;
            nativeBuildInputs = [ premake5 ] ++
              # So we can find libcuda.so at runtime in /run/opengl or wherever
              lib.optional enableCuda cudaPackages.autoAddOpenGLRunpathHook;
            NIX_LDFLAGS =
              lib.optional enableCuda "-L${cudaPackages.cudatoolkit}/lib/stubs";
            autoPatchelfIgnoreMissingDeps =
              lib.optional enableCuda "libcuda.so";

            buildInputs = [ spirv-tools xorg.libX11 ]
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
            ] ++ lib.optionals enableDirectX [ "--dx-on-vk=true" ];
            makeFlags = [ "config=release_x64" ];
            enableParallelBuilding = true;

            installPhase = ''
              mkdir -p $out/bin
              mkdir -p $out/lib
              mv bin/*/release/*.so $out/lib
              rm bin/*/release/*.a
              cp bin/*/release/* $out/bin
            '';

            # TODO: We should wrap slanc and add most of the env variables used here.
            shellHook = ''
              export PATH="''${PATH:+''${PATH}:}${
                lib.makeBinPath [
                  # Useful for testing, although the actual glslang implementation used in the compiler comes from slang-glslang above
                  glslang
                  # Build utilities from this flake
                  gen-compile-commands
                  make-helper
                  # Used in the bump-glslang.sl script
                  cmake
                  python3
                ]
              }"

              # Vulkan, dxc
              export LD_LIBRARY_PATH="${
                lib.makeLibraryPath ([ vulkan-loader slang-llvm ]
                  ++ lib.optional enableDXC directx-shader-compiler)
              }''${LD_LIBRARY_PATH:+:''${LD_LIBRARY_PATH}}"

              # cuda
              ${lib.optionalString enableCuda ''
                export CUDA_PATH="${cudaPackages.cudatoolkit}''${CUDA_PATH:+:''${CUDA_PATH}}"
                export LD_LIBRARY_PATH="${
                  lib.makeLibraryPath [
                    # for libcuda.so
                    addOpenGLRunpath.driverLink
                    # for libnvrtc.so
                    cudaPackages.cudatoolkit.out
                  ]
                }''${LD_LIBRARY_PATH:+:''${LD_LIBRARY_PATH}}"
              ''}

              # dxvk and vkd3d-proton
              ${lib.optionalString enableDirectX ''
                # Make dxvk and vkd3d-proton less noisy
                export VKD3D_DEBUG=err
                export DXVK_LOG_LEVEL=error
                export LD_LIBRARY_PATH="${
                  lib.makeLibraryPath [
                    # for dx11
                    dxvk_2
                    # for vkd3d-shader.sh (d3dcompiler)
                    vkd3d
                    # for dx12
                    vkd3d-proton
                  ]
                }''${LD_LIBRARY_PATH:+:''${LD_LIBRARY_PATH}}"
              ''}

              # Provision several handy Vulkan tools and make them available
              export VK_LAYER_PATH="${
                makeVkLayerPath [
                  vulkan-validation-layers
                  vulkan-tools-lunarg
                  renderdoc
                ]
              }''${VK_LAYER_PATH:+:''${VK_LAYER_PATH}}"

              # Disable 'fortify' hardening as it makes warnings in debug mode
              # Disable 'format' hardening as some of the tests generate offending output
              export NIX_HARDENING_ENABLE=$(echo "$NIX_HARDENING_ENABLE" | sed -i 's/fortify//;s/format//')
            '';
          };
      });
  };
}
