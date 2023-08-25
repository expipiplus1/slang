{
  description = "The Slang compiler";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs/f564a7b4acf7777bf16615401b95c5ab269ecea6";

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
        enableCuda = true;
        enableDXC = true;
        enableDirectX = true;

        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (self: super: {
              dxvk_2 = (super.dxvk_2.override {
                sdl2Support = false;
                glfwSupport = false;
              }).overrideAttrs (old: {
                src = pkgs.fetchFromGitHub {
                  owner = "doitsujin";
                  repo = "dxvk";
                  rev = "2069fd25147dcd0a4b24de2abfac1e305cd4a19c"; # pin
                  sha256 =
                    "sha256-x7OQ0s4Tcavpw3nTEhXMBwYjMrdSv8fjPFjVxYRZ4ms=";
                  fetchSubmodules = true;
                };
              });
              optix-headers = pkgs.fetchzip {
                url =
                  "https://developer.download.nvidia.com/redist/optix/v7.3/OptiX-7.3.0-Include.zip";
                sha256 = "0max1j4822mchj0xpz9lqzh91zkmvsn4py0r174cvqfz8z8ykjk8";
              };
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

        # Eww, some packages put things in etc and others in share. This ruins the
        # order, but ehh
        makeVkLayerPath = with pkgs.lib;
          ps:
          concatStringsSep ":" [
            (makeSearchPathOutput "lib" "share/vulkan/explicit_layer.d" ps)
            (makeSearchPathOutput "lib" "share/vulkan/implicit_layer.d" ps)
            (makeSearchPathOutput "lib" "etc/vulkan/explicit_layer.d" ps)
            (makeSearchPathOutput "lib" "etc/vulkan/implicit_layer.d" ps)
          ];

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

        arch = {
          x86_64-linux = "x64";
          i686-linux = "x86";
          aarch64-linux = "aarch64";
        }.${system};
        commonPremakeFlags = [ "gmake2" "--deps=false" "--arch=${arch}" ];
        makeFlags = [ "config=release_${arch}" "verbose=1" ];

      in rec {
        default = slang;

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
            # TODO: We should wrap slanc and add these.
            shellHook = ''
              export PATH=$PATH:${
                lib.makeBinPath [ glslang gen-compile-commands make-helper ]
              }
              export LD_LIBRARY_PATH=${
                lib.makeLibraryPath ([ vulkan-loader slang-llvm ]
                  ++ lib.optional enableDXC directx-shader-compiler
                  ++ lib.optionals enableCuda [
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
                  ])
              }:$LD_LIBRARY_PATH
              ${lib.optionalString enableCuda ''
                export CUDA_PATH="${cudaPackages.cudatoolkit}"
              ''}

              export VK_LAYER_PATH=${
                makeVkLayerPath [
                  vulkan-validation-layers
                  vulkan-tools-lunarg
                  renderdoc
                ]
              }
              # Disable 'fortify' hardening as it makes warnings in debug mode
              # export NIX_HARDENING_ENABLE="stackprotector pic strictoverflow format relro bindnow"
              # Disable 'format' hardening as some of the tests generate offending output
              export NIX_HARDENING_ENABLE="stackprotector pic strictoverflow relro bindnow"
            '' + lib.optionalString enableDirectX ''
              export VKD3D_DEBUG=err
              export DXVK_LOG_LEVEL=error
            '';
          };
      });
  };
}
