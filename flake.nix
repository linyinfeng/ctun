{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    crane.url = "github:ipetkov/crane";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        self,
        inputs,
        lib,
        ...
      }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        imports = [
          inputs.flake-parts.flakeModules.easyOverlay
          inputs.treefmt-nix.flakeModule
        ];
        perSystem =
          {
            config,
            self',
            pkgs,
            system,
            ...
          }:
          let
            craneLib = inputs.crane.mkLib pkgs;
            src = craneLib.cleanCargoSource ./.;
            bareCommonArgs = {
              inherit src;
              nativeBuildInputs = with pkgs; [
                pkg-config
              ];
              buildInputs = with pkgs; [
                openssl
                sqlite
              ];
            };
            cargoArtifacts = craneLib.buildDepsOnly bareCommonArgs;
            commonArgs = bareCommonArgs // {
              inherit cargoArtifacts;
            };
          in
          {
            packages = {
              ctun = craneLib.buildPackage commonArgs;
              default = config.packages.ctun;
            };
            overlayAttrs.ctun = config.packages.ctun;
            checks = {
              inherit (self'.packages) ctun;
              doc = craneLib.cargoDoc commonArgs;
              fmt = craneLib.cargoFmt { inherit src; };
              nextest = craneLib.cargoNextest (
                commonArgs
                // {
                  cargoNextestExtraArgs = lib.escapeShellArgs [ "--no-tests=warn" ];
                }
              );
              clippy = craneLib.cargoClippy (
                commonArgs
                // {
                  cargoClippyExtraArgs = "--all-targets -- --deny warnings";
                }
              );
            };
            treefmt = {
              projectRootFile = "flake.nix";
              programs = {
                nixfmt.enable = true;
                shfmt.enable = true;
              };
            };
            devShells.default = pkgs.mkShell {
              inputsFrom = lib.attrValues self'.checks;
              packages = with pkgs; [
                rustup
                rust-analyzer
              ];
            };
          };
      }
    );
}
