{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    zls-flake = {
      url = "github:zigtools/zls";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        zig-overlay.follows = "zig-overlay";
      };
    };

    picogron-flake = {
      url = "github:hwchen/picogron";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        zig-overlay.follows = "zig-overlay";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay, zls-flake, picogron-flake }:
    flake-utils.lib.eachDefaultSystem (system: let
      odin-overlay = self: super: {
        odin = super.odin.overrideAttrs (old: rec {
          version = "nightly-2024-03-31-0d8dadb";
          src = super.fetchFromGitHub {
            owner = "odin-lang";
            repo = "Odin";
            rev = "0d8dadb0840ced094383193b7fc22dd86d41e403";
            sha256 = "sha256-saAUd6gGJWu8rnA0NR4R0UwDvdvjfXlbNfqPhOJpFBM=";
          };

          nativeBuildInputs = with super; [ makeWrapper which ];

          LLVM_CONFIG = "${super.llvmPackages_17.llvm.dev}/bin/llvm-config";
          postPatch = ''
            sed -i 's/^GIT_SHA=.*$/GIT_SHA=/' build_odin.sh
            sed -i 's/LLVM-C/LLVM/' build_odin.sh
            patchShebangs build_odin.sh
          '';

          installPhase = old.installPhase + "cp -r vendor $out/bin/vendor";
        });
      };

      ols-overlay = self: super: {
        ols = super.ols.overrideAttrs (old: rec {
          version = "nightly-2024-03-31-b398c8c";
          src = super.fetchFromGitHub {
            owner = "DanielGavin";
            repo = "ols";
            rev = "b398c8c817c2b28888e86ebdae84b8deb00a49e0";
            sha256 = "sha256-EgtqdqDu46254QMwgayBgHzCORMOc5+Vfl6NoAMN+U0=";
          };

          installPhase = old.installPhase;
        });
      };

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (zig-overlay.overlays.default)
          (odin-overlay)
          (ols-overlay)
        ];
        };

        zls = zls-flake.packages.${system}.zls;
        picogron = picogron-flake.packages.${system}.picogron;

        # No longer used, as bril2json and bril2txt no longer used,
        # but kept around just in case I need to set up other python
        # deps
        #venvDir = "./.venv";

        lib = pkgs.lib;
        in {
        devShells.default = pkgs.mkShell {
        #inherit venvDir;
        nativeBuildInputs = [
        pkgs.zigpkgs.master-2024-03-16
        zls

        pkgs.odin
        pkgs.ols

        # for brili, check ~/.deno/bin when removing.
        # install brili by deno install brili.ts
        pkgs.deno

        # No longer used, as bril2json and bril2txt no longer used,
        # but kept around just in case I need to set up other python
        # deps
        # bril2json and bril2txt
        # requires
        # ```
        # pip install flit
        # cd <bril-txt dir>
        # flit install --symlink
        # ```
        #pkgs.python311
        # Just using venv, install everything by pip for python for bril2json and bril2txt
        # https://www.reddit.com/r/NixOS/comments/q71v0e/what_is_the_correct_way_to_setup_pip_with_nix_to/
        #pkgs.python311Packages.venvShellHook

        pkgs.graphviz
        pkgs.python311Packages.turnt # for testing
        pkgs.jq # for sorting keys and pretty-printing output
        picogron # also for working with json
        ];
        # for brili executable
        PATH = "/home/hwchen/.deno/bin:$PATH";

        # If needed I can define a postShellHook here.
      };
    });
}
