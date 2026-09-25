# The public contract. Every builder takes the consumer's pkgs first, so
# clj-build never forces a second nixpkgs instance into package construction.
{ }:
let
  common = import ./common.nix;
in
{
  fetchCljDeps = import ./fetch-deps.nix;
  mkCljCli = import ./cli.nix { inherit common; };
  mkCljUberjar = import ./uberjar.nix { inherit common; };
  mkCljChecks = import ./checks.nix { inherit common; };
}
