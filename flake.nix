{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        flake-utils.url = "github:numtide/flake-utils";
        veridian = {
            url = "github:vivekmalneedi/veridian";
            flake = false;
        };
    };

    outputs = { self, nixpkgs, flake-utils, ... } @ inputs: flake-utils.lib.eachDefaultSystem (system: 
    let 
        pkgs = nixpkgs.legacyPackages.${system};
    in { 
        packages.veridian = with pkgs; let
            libfmt = fmt_11;
            libboost = boost182;
            slang-git = let 
                version = "8.0";
                fmtsrc = fetchFromGitHub {
                    owner = "fmtlib";
                    repo = "fmt";
                    rev = "11.1.3";
                    hash = "sha256-6r9D/csVSgS+T/H0J8cSR+YszxnH/h2V2odi2s6VYN8=";
                };
            in sv-lang.overrideAttrs{
                inherit version;
                src = fetchFromGitHub {
                    owner = "MikePopoloski";
                    repo = "slang";
                    rev = "v${version}";
                    hash = "sha256-UZwMxnzprOjN5DlV1zLd0I6rgrBMBhcZ+dSx8t2sJF8=";
                };
                cmakeFlags = [
                    # fix for https://github.com/NixOS/nixpkgs/issues/144170
                    "-DCMAKE_INSTALL_INCLUDEDIR=include"
                    "-DCMAKE_INSTALL_LIBDIR=lib"

                    "-DSLANG_INCLUDE_TESTS=${if !stdenv.hostPlatform.isDarwin then "ON" else "OFF"}"
                    "-DSLANG_USE_MIMALLOC=OFF"
                    "-DFETCHCONTENT_SOURCE_DIR_FMT=${fmtsrc}"
                ];
                nativeBuildInputs = [
                    cmake
                    python3
                    ninja
                ];
                buildInputs = [
                    (stdenv.mkDerivation rec {
                        version = "2.0.1";
                        pname = "unordered_dense";
                        src = fetchFromGitHub {
                          owner = "martinus";
                          repo = pname;
                          rev = "v${version}";
                          sha256 = "sha256-9zlWYAY4lOQsL9+MYukqavBi5k96FvglRgznLIwwRyw=";
                        };
                        nativeBuildInputs = [
                          cmake
                        ];
                    })
                    libboost
                    libfmt
                    catch2_3
                ];
            };
        in rustPlatform.buildRustPackage {
            inherit system;
            pname = "veridian";
            version = "git-${builtins.substring 0 6 inputs.veridian.rev}";
            src = inputs.veridian;
            useFetchCargoVendor = true;
            cargoLock.lockFile = "${inputs.veridian}/Cargo.lock";
            buildFeatures = [ "slang" ];

            # env vars for building the slang wrapper
            SLANG_INSTALL_PATH = slang-git;
            OPENSSL_NO_VENDOR = 1;
            OPENSSL_DIR = openssl.dev;
            OPENSSL_LIB_DIR = "${openssl.out}/lib";

            nativeBuildInputs = [
                rustPlatform.bindgenHook
                pkg-config
                cmake
                verilator
                verible
            ];
            buildInputs = [
                #verilator
                libfmt
                verible
                slang-git
            ];
            patches = [
                (writeText "slang-cmake-patch" ''
                    diff --git a/veridian-slang/build.rs b/veridian-slang/build.rs
                    index d42c02d..2b1e745 100644
                    --- a/veridian-slang/build.rs
                    +++ b/veridian-slang/build.rs
                    @@ -43,7 +43,7 @@ fn build_slang(slang_src: &Path, slang_install: &Path) {
                     fn build_slang_wrapper(slang: &Path, wrapper_install: &Path) {
                         cmake::Config::new("slang_wrapper")
                             .profile("Release")
                    -        .define("CMAKE_PREFIX_PATH", slang)
                    +        .define("CMAKE_PREFIX_PATH", slang.join(";${libfmt.dev};${libboost.dev}"))
                             .out_dir(wrapper_install)
                             .build();
                     }
                '')
                (writeText "slang-version-patch" ''
                    diff --git a/veridian-slang/slang_wrapper/CMakeLists.txt b/veridian-slang/slang_wrapper/CMakeLists.txt
                    index a3cf824..9941e92 100644
                    --- a/veridian-slang/slang_wrapper/CMakeLists.txt
                    +++ b/veridian-slang/slang_wrapper/CMakeLists.txt
                    @@ -6,7 +6,7 @@ project(
                     )
                     
                     # Keep the version the same as the one in `build.rs`
                    -find_package(slang 7.0 REQUIRED)
                    +find_package(slang 8.0 REQUIRED)
                     
                     set(CMAKE_CXX_STANDARD 20)
                     set(CMAKE_CXX_STANDARD_REQUIRED ON)
                '')
            ];

            meta = {
                homepage = "https://github.com/vivekmalneedi/veridian";
                description = "A SystemVerilog Language Server";
            };
        };
    });
}