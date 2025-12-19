{
  pkgs,
  flake,
}:
pkgs.callPackage ./package.nix {
  patchy-cnb = flake.packages.${pkgs.system}.patchy-cnb;
}
