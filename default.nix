{ nixpkgsSrc ? /home/e/src/nixpkgs, crossSystem ? null }:

let
  pkgs = import nixpkgsSrc {
    inherit crossSystem;
    overlays = [
      (self: super: {
        # llvmPackages_13 = super.llvmPackages_13 // (let
        #   tools = super.llvmPackages_13.tools.extend (selfT: superT: {
        #     libclang = superT.libclang.overrideAttrs (old: {
        #       cmakeFlags = old.cmakeFlags ++ [
        #         # "-DCLANG_BUILD_TOOLS=0"
        #         "-DCMAKE_CXX_VISIBILITY_PRESET=hidden"
        #         # -DCLANG_BUILD_TOOLS=0
        #         # -DCLANG_ENABLE_STATIC_ANALYZER=0
        #         # -DCLANG_ENABLE_ARCMT=0
        #         # -DCLANG_INCLUDE_DOCS=0
        #         # -DCLANG_INCLUDE_TESTS=0

        #       ];
        #     });
        #     libllvm = superT.libllvm.overrideAttrs (old: {
        #       doCheck = false;
        #       cmakeFlags = old.cmakeFlags ++ [
        #         "-DCMAKE_CXX_VISIBILITY_PRESET=hidden"
        #         # "-DLLVM_BUILD_LLVM_C_DYLIB=NO"
        #         # "-DLLVM_BUILD_LLVM_DYLIB=NO"
        #         # "-DLLVM_INCLUDE_BENCHMARKS=NO"
        #         # "-DLLVM_INCLUDE_DOCS=NO"
        #         # "-DLLVM_INCLUDE_EXAMPLES=NO"
        #         # "-DLLVM_BUILD_TOOLS=YES"
        #         # "-DLLVM_INCLUDE_TESTS=NO"
        #         # "-DLLVM_ENABLE_TERMINFO=NO"
        #         "-DLLVM_LINK_LLVM_DYLIB=NO"
        #       ];
        #     });
        #   });
        #   libraries = super.llvmPackages_13.libraries;
        # in { inherit tools libraries; } // tools // libraries);
        # llvmPackages = self.llvmPackages_13;
        dxvk_2 = # self.enableDebugging
          (super.dxvk_2.override { sdl2Support = false; }).overrideAttrs
          (old: { src = /home/e/work/dxvk; });
        directx-shader-compiler = super.directx-shader-compiler.overrideAttrs
          (old: {
            patches = old.patches or [ ]
              ++ [ ./fix-shutdown-use-after-free.patch ];
          });
        vkd3d-proton = self.enableDebugging (self.callPackage
          ({ stdenv, meson, ninja, wine64, glslang, git }:
            stdenv.mkDerivation {
              name = "vkd3d-proton";
              src = /home/e/work/tmp/vkd3d-proton;
              nativeBuildInputs = [ meson ninja wine64 glslang git ];
            }) { });
      })
    ];
  };

  enableCuda = true;

  # Eww, some packages put things in etc and others in share. This ruins the
  # order, but ehh
  makeVkLayerPath = ps:
    pkgs.lib.concatStringsSep ":" [
      (pkgs.lib.makeSearchPathOutput "lib" "share/vulkan/explicit_layer.d" ps)
      (pkgs.lib.makeSearchPathOutput "lib" "share/vulkan/implicit_layer.d" ps)
      (pkgs.lib.makeSearchPathOutput "lib" "etc/vulkan/explicit_layer.d" ps)
      (pkgs.lib.makeSearchPathOutput "lib" "etc/vulkan/implicit_layer.d" ps)
    ];

  commonPremakeFlags = [ "gmake2" "--deps=false" "--arch=x64" ];
  makeFlags = [ "config=release_x64" "verbose=1" ];

  slang-glslang = pkgs.callPackage ({ stdenv, fetchFromGitHub, premake5 }:
    stdenv.mkDerivation {
      name = "slang-glslang";
      src = fetchFromGitHub {
        owner = "expipiplus1";
        repo = "slang-glslang";
        rev = "a1d133f12c0b5bbff6aecb474cb3eadb0fc7afd4"; # submodule-protocol
        sha256 = "0c1xkcxan3vvv8sxg61advdd842jly9ig8kxg8m9h9kgimgch84f";
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
    }) { };

  # llvmPackages = pkgsStatic.llvmPackages_13;
  # llvmPackages = llvmPackages_13;

  slang-llvm = pkgs.callPackage
    ({ stdenv, fetchFromGitHub, symlinkJoin, premake5, llvmPackages, ncurses }:
      stdenv.mkDerivation {
        name = "slang-llvm";
        src = /home/e/work/slang-llvm;
        # src = fetchFromGitHub {
        #   owner = "shader-slang";
        #   repo = "slang-llvm";
        #   rev = "35fbe560fda7d1ba638be41b167faf7c5f140b3d";
        #   sha256 = "13773w5dfgydi02h239vmb7hapi34r89l20m97dc8yjvq0kz761c";
        #   fetchSubmodules = true;
        # };
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
        buildInputs = [ llvmPackages.libclang llvmPackages.llvm ncurses ];
        premakeFlags = commonPremakeFlags ++ [
          "--llvm-path=${
            symlinkJoin {
              name = "llvm-and-clang";
              paths = [ llvmPackages.llvm.lib llvmPackages.libclang.lib ];
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
      }) { llvmPackages = pkgs.llvmPackages_13; };

  optix = pkgs.fetchzip {
    # url taken from the archlinux blender PKGBUILD
    url =
      "https://developer.download.nvidia.com/redist/optix/v7.3/OptiX-7.3.0-Include.zip";
    sha256 = "0max1j4822mchj0xpz9lqzh91zkmvsn4py0r174cvqfz8z8ykjk8";
  };

  dxvk-native-headers = pkgs.symlinkJoin {
    name = "dxvk-native-headers";
    paths = [
      /home/e/work/dxvk/include/native/windows
      /home/e/work/dxvk/include/native/directx
      /home/e/work/dxvk/include/native
    ];
    postBuild = ''
      ln -s . $out/include
    '';
  };

  gen-compile-commands = pkgs.writeShellScriptBin "gen-compile-commands" ''
    git clean -x -f \
      Makefile \
      bin/ \
      build/ \
      intermediate/ \
      source/slang/slang-generated-* \
      source/slang/*.meta.slang.h \
      prelude/slang-*-prelude.h.cpp

    export CC=${pkgs.clang}/bin/clang
    export CXX=${pkgs.clang}/bin/clang++
    premake5 $premakeFlags --cc=clang "$@"
    ${pkgs.bear}/bin/bear --append -- make --ignore-errors --keep-going config=debug_x64 -j$(nproc)
  '';

  slang = pkgs.callPackage ({ stdenv, lib, nix-gitignore, premake5, xorg
    , cudaPackages, directx-shader-compiler, vulkan-loader
    , vulkan-validation-layers, vulkan-tools-lunarg, addOpenGLRunpath, dxvk_2
    , vkd3d, vkd3d-proton, SDL2, glslang, renderdoc }:
    stdenv.mkDerivation {
      name = "slang";
      # src = nix-gitignore.gitignoreSource [ "default.nix" ] ./.;
      src =
        nix-gitignore.gitignoreSource [ "default.nix" ] ./CODE_OF_CONDUCT.md;
      nativeBuildInputs = [
        premake5
        # So we can find libcuda.so at runtime in /run/opengl or wherever
      ] ++ lib.optional enableCuda cudaPackages.autoAddOpenGLRunpathHook;
      NIX_LDFLAGS = [ "-lSDL2" ]
        ++ lib.optional enableCuda "-L${cudaPackages.cudatoolkit}/lib/stubs";
      autoPatchelfIgnoreMissingDeps = lib.optional enableCuda "libcuda.so";

      buildInputs = [ dxvk-native-headers xorg.libX11 SDL2 ]
        ++ lib.optional enableCuda cudaPackages.cudatoolkit;
      passthru = { inherit slang-llvm slang-glslang gen-compile-commands; };

      preConfigure = ''
        ls external/slang-binaries
        cat ${external/slang-binaries/README.md}
      '';
      premakeFlags = commonPremakeFlags ++ [
        "--build-glslang=true"
        "--slang-llvm-path=${slang-llvm}"
        "--slang-glslang-path=${slang-glslang}"
        "--deploy-slang-llvm=false"
        "--deploy-slang-glslang=false"
      ] ++ lib.optionals enableCuda [
        "--cuda-sdk-path=${cudaPackages.cudatoolkit}"
        "--optix-sdk-path=${optix}"
      ];
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
        export PATH=${lib.makeBinPath [ glslang gen-compile-commands ]}:$PATH
        export LD_LIBRARY_PATH=${
          lib.makeLibraryPath
          ([ directx-shader-compiler vulkan-loader slang-llvm ]
            ++ lib.optionals enableCuda [
              # for libcuda.so
              addOpenGLRunpath.driverLink
              # for libnvrtc.so
              cudaPackages.cudatoolkit.out
              # for dx11
              dxvk_2
              # for vkd3d-shader.sh (d3dcompiler)
              (pkgs.enableDebugging vkd3d)
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

        export VKD3D_DEBUG=err
        export DXVK_LOG_LEVEL=error
      '';
    });

in slang { }
