{ nixpkgsSrc ? /home/e/src/nixpkgs, crossSystem ? null
, pkgs ? import nixpkgsSrc { inherit crossSystem; } }:

with pkgs.pkgsStatic;

let
  commonPremakeFlags = [ "gmake" "--deps=false" "--arch=x64" ];
  # commonPremakeFlags = [ "gmake" "--deps=false" "--arch=aarch64" ];
  makeFlags = [ "config=release_aarch64" "verbose=1" ];

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
    # patches = [ ./curses.patch ];
    nativeBuildInputs = [ buildPackages.premake5 ];
    buildInputs = [ llvmPackages_14.libclang llvm_14 ncurses ];
    premakeFlags = commonPremakeFlags ++ [
      "--llvm-path=${
        symlinkJoin {
          name = "llvm-clang";
          paths = [ llvm_14.lib llvmPackages_14.libclang.lib ];
        }
      }"
    ];
    inherit makeFlags;
    enableParallelBuilding = true;
    installPhase = ''
      mkdir -p $out/lib
      cp bin/*/release/*.a --target-directory "$out/lib"
    '';
  };

in stdenv.mkDerivation {
  name = "slang";
  src = nix-gitignore.gitignoreSource [ ] ./.;
  nativeBuildInputs = [ buildPackages.premake5 ];
  buildInputs = [ xorg.libX11 ];
  passthru = { inherit slang-llvm slang-glslang; };

  premakeFlags = commonPremakeFlags ++ [
    "--build-glslang=true"
    "--slang-llvm-path=${slang-llvm}"
    "--slang-glslang-path=${slang-glslang}"
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
}
