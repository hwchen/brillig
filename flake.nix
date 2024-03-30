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
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay, zls-flake }:
    flake-utils.lib.eachDefaultSystem (system: let
      odin-overlay = self: super: {
        odin = super.odin.overrideAttrs (old: rec {
          version = "dev-2024-03";
          src = super.fetchFromGitHub {
            owner = "odin-lang";
            repo = "Odin";
            rev = "${version}";
            sha256 = "sha256-oK5OcWAZy9NVH19oep6QU4d5qaiO0p+d9FvxDIrzFLU=";
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
          version = "nightly-2024-03-11-207fe98";
          src = super.fetchFromGitHub {
            owner = "DanielGavin";
            repo = "ols";
            rev = "207fe98a46b28297755608904dbf08d06fc50970";
            sha256 = "sha256-S9cvLf8M0J7Zuf35RmZYtxJ6J215RoECK70SQBR+Kxk=";
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

        venvDir = "./.venv";

        lib = pkgs.lib;
        in {
        devShells.default = pkgs.mkShell {
        inherit venvDir;
        nativeBuildInputs = [
        pkgs.zigpkgs.master-2024-03-16
        zls

        pkgs.odin
        pkgs.ols

        # for brili, check ~/.deno/bin when removing.
        # install brili by deno install brili.ts
        pkgs.deno
        # bril2json and bril2txt
        # requires
        # ```
        # pip install flit
        # cd <bril-txt dir>
        # flit install --symlink
        # ```
        pkgs.python311
        # Just using venv, install everything by pip for python.
        # https://www.reddit.com/r/NixOS/comments/q71v0e/what_is_the_correct_way_to_setup_pip_with_nix_to/
        pkgs.python311Packages.venvShellHook

        pkgs.graphviz
        pkgs.python311Packages.turnt # for testing
        pkgs.jq # for sorting keys and pretty-printing output
        ];
        # for brili executable
        PATH = "/home/hwchen/.deno/bin:$PATH";

        # If needed I can define a postShellHook here.
      };
    });
}
