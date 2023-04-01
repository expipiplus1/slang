{ nixpkgsSrc ? /home/e/src/nixpkgs, crossSystem ? null
, pkgs ? import nixpkgsSrc { inherit crossSystem; } }:

with pkgs;

let
  # Eww, some packages put things in etc and others in share. This ruins the
  # order, but ehh
  makeVkLayerPath = ps:
    pkgs.lib.concatStringsSep ":" [
      (pkgs.lib.makeSearchPathOutput "lib" "share/vulkan/explicit_layer.d" ps)
      (pkgs.lib.makeSearchPathOutput "lib" "etc/vulkan/explicit_layer.d" ps)
    ];

  commonPremakeFlags = [ "gmake2" "--deps=false" "--arch=x64" ];
  makeFlags = [ "config=release_x64" "verbose=1" ];

  slang-glslang = stdenv.mkDerivation {
    name = "slang-glslang";
    src = fetchFromGitHub {
      owner = "expipiplus1";
      repo = "slang-glslang";
      rev = "a1d133f12c0b5bbff6aecb474cb3eadb0fc7afd4"; # submodule-protocol
      sha256 = "0c1xkcxan3vvv8sxg61advdd842jly9ig8kxg8m9h9kgimgch84f";
      fetchSubmodules = true;
    };
    nativeBuildInputs = [ buildPackages.premake5 ];
    premakeFlags = commonPremakeFlags;
    inherit makeFlags;
    enableParallelBuilding = true;

    installPhase = ''
      mkdir -p $out/lib
      cp bin/*/release/*.so "$out/lib"
    '';
  };

  slang-llvm = stdenv.mkDerivation {
    name = "slang-llvm";
    # src = /home/e/work/slang-llvm;
    src = fetchFromGitHub {
      owner = "shader-slang";
      repo = "slang-llvm";
      rev = "35fbe560fda7d1ba638be41b167faf7c5f140b3d";
      sha256 = "13773w5dfgydi02h239vmb7hapi34r89l20m97dc8yjvq0kz761c";
      fetchSubmodules = true;
    };
    NIX_LDFLAGS = "-lncurses";
    nativeBuildInputs = [ buildPackages.premake5 ];
    buildInputs = [ llvmPackages_13.libclang llvm_13 ncurses ];
    premakeFlags = commonPremakeFlags ++ [
      "--llvm-path=${
        symlinkJoin {
          name = "llvm-clang";
          paths = [ llvm_13.lib llvmPackages_13.libclang.lib ];
          postBuild = ''
            ln -s . $out/build
          '';
        }
      }"
    ];
    inherit makeFlags;
    enableParallelBuilding = true;
    installPhase = ''
      mkdir -p $out/lib
      # TODO: Neaten
      cp bin/*/release/*.a --target-directory "$out/lib"
      cp bin/*/release/*.so --target-directory "$out/lib"
    '';
  };

  directx-shader-compiler = pkgs.directx-shader-compiler.overrideAttrs (old: {
    patches = old.patches or [ ] ++ [ ./fix-shutdown-use-after-free.patch ];
  });

  optix = fetchzip {
    # url taken from the archlinux blender PKGBUILD
    url =
      "https://developer.download.nvidia.com/redist/optix/v7.3/OptiX-7.3.0-Include.zip";
    sha256 = "0max1j4822mchj0xpz9lqzh91zkmvsn4py0r174cvqfz8z8ykjk8";
  };

in stdenv.mkDerivation {
  name = "slang";
  src = nix-gitignore.gitignoreSource [ ] ./.;
  nativeBuildInputs = [
    premake5
    # So we can find libcuda.so at runtime in /run/opengl or wherever
    cudaPackages.autoAddOpenGLRunpathHook
  ];
  NIX_LDFLAGS = [ "-L${cudaPackages.cudatoolkit}/lib/stubs" ];
  autoPatchelfIgnoreMissingDeps = [ "libcuda.so" ];

  buildInputs = [ xorg.libX11 cudaPackages.cudatoolkit ];
  passthru = { inherit slang-llvm slang-glslang; };

  preConfigure = ''
    ls external/slang-binaries
    cat ${external/slang-binaries/README.md}
  '';
  premakeFlags = commonPremakeFlags ++ [
    "--build-glslang=true"
    "--slang-llvm-path=${slang-llvm}"
    "--slang-glslang-path=${slang-glslang}"
    "--cuda-sdk-path=${cudatoolkit}"
    "--optix-sdk-path=${optix}"
    "--deploy-slang-llvm=false"
    "--deploy-slang-glslang=false"
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
    export LD_LIBRARY_PATH=${
      lib.makeLibraryPath [
        directx-shader-compiler
        vulkan-loader
        # for libcuda.so
        addOpenGLRunpath.driverLink
        # for libnvrtc.so
        cudaPackages.cudatoolkit.out
      ]
    }
    export CUDA_PATH="${cudaPackages.cudatoolkit}"

    export VK_LAYER_PATH=${
      makeVkLayerPath [ vulkan-validation-layers vulkan-tools-lunarg ]
    }
    # Disable 'fortify' hardening as it makes warnings in debug mode
    export NIX_HARDENING_ENABLE="stackprotector pic strictoverflow format relro bindnow"
  '';
}
