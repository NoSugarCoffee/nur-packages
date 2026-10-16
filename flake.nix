{
  description = "Nix packages nixpkgs lacks or lags on, mostly macOS apps. Updated automatically 4x daily.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      # nixpkgs-unstable dropped x86_64-darwin (26.05 is its last release).
      # Pins keep their x86_64-darwin hashes, so the overlay still serves an
      # Intel Mac on 26.05.
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    {
      # Every package, whether or not it supports the system.
      legacyPackages = forAllSystems (system: import ./default.nix { pkgs = pkgsFor system; });

      # Only what builds on the system, so consumers can take the whole set
      # (or check `? name`) without tripping over platform errors.
      packages = forAllSystems (
        system:
        lib.filterAttrs (
          _: lib.meta.availableOn (pkgsFor system).stdenv.hostPlatform
        ) self.legacyPackages.${system}
      );

      # Built against the consumer's nixpkgs, namespaced so nothing here
      # shadows a nixpkgs package of the same name.
      overlays.default = final: _prev: {
        nosugarcoffee = import ./default.nix { pkgs = final; };
      };

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
