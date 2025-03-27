{
  description = "Messing around with Nix NAR archives in Zig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    zig-deps-fod.url = "github:water-sucks/zig-deps-fod";
  };

  outputs = {
    nixpkgs,
    flake-parts,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem = {pkgs, ...}: {
        packages = let
          narz = pkgs.callPackage (import ./package.nix) {inherit (inputs.zig-deps-fod.lib) fetchZigDeps;};
        in {
          inherit narz;
          default = narz;
        };

        devShells.default = pkgs.mkShell {
          name = "narz-shell";
          buildInputs = [
            pkgs.zig
          ];
        };
      };
    };
}
