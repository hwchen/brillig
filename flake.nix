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
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (zig-overlay.overlays.default)
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
        ];
        # for brili executable
        PATH = "/home/hwchen/.deno/bin:$PATH";

        # If needed I can define a postShellHook here.
      };
    });
}
