{ pkgs ? import <nixpkgs> {} }:
with pkgs;
with lib;
let
  env = { config, nixPkgs, devEnvDirectory }:
    assert (assertMsg (config.variant == "") "Error: variant option is not used by generic module");
    assert (assertMsg (config.installPackages == [] &&
                       config.installUrls == [] &&
                       config.installDirectories == [] &&
                       config.installFiles == [])
      "Error: install pkg, url and dir option is not used by generic module");
    ''
      export PATH="${concatStringsSep ":" config.paths}:$PATH"
    '';
in {
  name = "generic";
  inherit env;
}
