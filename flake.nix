{
  description = "clj-build — shared Nix build library for LiGoldragon Clojure (-clj) tools";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      lib = forSystems (system: import ./lib { });

      checks = forSystems (
        system:
        import ./tests {
          pkgs = nixpkgs.legacyPackages.${system};
          clj = self.lib.${system};
        }
      );
    };
}
