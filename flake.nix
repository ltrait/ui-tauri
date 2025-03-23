{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    crane.url = "github:ipetkov/crane";

    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      crane,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
      ];

      perSystem =
        {
          system,
          pkgs,
          lib,
          self',
          ...
        }:
        let
          rust-bin = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

          craneLib = (crane.mkLib pkgs).overrideToolchain rust-bin;
          src = craneLib.cleanCargoSource ./src-tauri;

          commonArgs = {
            inherit src;
            strictDeps = true;

            preBuild = ''
              export PERMISSION_FILES_PATH=$TMPDIR
              echo $TMPDIR
            '';

            nativeBuildInputs = with pkgs; [
              pkg-config

              gobject-introspection
            ];

            buildInputs =
              with pkgs;
              [
                at-spi2-atk
                atkmm
                cairo
                gdk-pixbuf
                glib
                gtk3
                harfbuzz
                librsvg
                libsoup_3
                pango
              ]
              ++ lib.optionals stdenv.hostPlatform.isLinux [
                webkitgtk_4_1
              ];
          };

          cargoArtifacts = craneLib.buildDepsOnly commonArgs;

          pnpmDeps = pkgs.pnpm.fetchDeps {
            pname = "ltrait-ui-tauri-pnpmdeps";
            version = "0.1.0";
            src = ./.;
            hash = "sha256-zbPyJhqvzXSoWbQ/QNFybNlypbFwBv4cCA3INAJu7Ow=";
          };

          ltrait-ui-tauri = craneLib.buildPackage (
            commonArgs
            // {
              inherit cargoArtifacts pnpmDeps;

              nativeBuildInputs = with pkgs; [
                cargo-tauri.hook
                pnpm.configHook
                wrapGAppsHook4

                nodejs
              ];
            }
          );
        in
        {

          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.rust-overlay.overlays.default
            ];
          };

          packages = {
            # TODO: nixでビルドできない
            default = ltrait-ui-tauri;
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              self'.packages.default
            ];

            name = "ltrait";

            buildInputs = with pkgs; [
              pnpm

              rust-bin

              cargo-nextest
              cargo-tauri
            ];
          };
        };
    };
}
