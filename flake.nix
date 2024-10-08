{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [];
        };

        lib = pkgs.lib;
        in {
        devShells.default = pkgs.mkShell {
        nativeBuildInputs = [
        # odin/ols not managed by nix

        # for brili, check ~/.deno/bin when removing.
        # install brili by deno install brili.ts
        pkgs.deno

        pkgs.graphviz
        pkgs.python311Packages.turnt # for testing
        pkgs.jq # for sorting keys and pretty-printing output
        ];
        # for brili executable
        PATH = "/home/hwchen/.deno/bin:$PATH";

        # because odin error messages don't pick up light theme
        NO_COLOR=true;

        # If needed I can define a postShellHook here.
      };
    });
}
