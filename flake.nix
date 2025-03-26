{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
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

          rustPlatform = pkgs.makeRustPlatform {
            cargo = rust-bin;
            rustc = rust-bin;
          };

          pnpmDeps = pkgs.pnpm.fetchDeps {
            pname = "ltrait-ui-tauri-pnpmdeps";
            version = "0.1.0";
            src = ./.;
            hash = "sha256-zbPyJhqvzXSoWbQ/QNFybNlypbFwBv4cCA3INAJu7Ow=";
          };
        in
        {

          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.rust-overlay.overlays.default
            ];
          };

          packages = {
            default = rustPlatform.buildRustPackage rec {
              pname = "ltrait-ui-tauri";
              version = "0.1.0";
              src = ./.;

              cargoLock.lockFile = ./src-tauri/Cargo.lock;

              inherit pnpmDeps;

              nativeBuildInputs = with pkgs; [
                cargo-tauri.hook

                nodejs
                pnpm.configHook

                pkg-config
                wrapGAppsHook4
              ];

              buildInputs =
                with pkgs;
                [ openssl ]
                ++ lib.optionals stdenv.hostPlatform.isLinux [
                  glib-networking # Most Tauri apps need networking
                  webkitgtk_4_1
                ];

              cargoRoot = "src-tauri";
              buildAndTestSubdir = cargoRoot;
            };
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              self'.packages.default
            ];

            name = "ltrait";

            buildInputs =
              with pkgs;
              [
                pnpm

                rust-bin

                cargo-nextest
                cargo-tauri
              ]
              ++ [
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
        };
    };
}
