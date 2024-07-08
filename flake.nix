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
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (zig-overlay.overlays.default)
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

        # because odin error messages don't pick up light theme
        NO_COLOR=true;

        # If needed I can define a postShellHook here.
      };
    });
}
