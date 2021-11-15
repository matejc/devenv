{ pkgs ? import <nixpkgs> {} }:
with pkgs;
with lib;
let
  mkExecutables = { package, config, nixpkgs, prefix }: { };

  mkBuild = { package, config, nixpkgs, prefix }: "true";

  mkEnvironment = { package, config, nixpkgs, prefix}:
    assert (assertMsg (config.package == "") "Error: package option is not used by generic module");
    assert (assertMsg (config.install.packages == [] &&
                       config.install.urls == [] &&
                       config.install.directories == [] &&
                       config.install.files == [])
      "Error: install pkg, url, file and dir option is not used by generic module");
    ''
      export PATH="${concatStringsSep ":" config.srcs}:${pkgs.lib.makeBinPath nixpkgs}:$PATH"
    '';
in {
  name = "nix";
  defaultPackage = nix;
  inherit mkEnvironment mkExecutables mkBuild;
}
