{ pkgs ? import <nixpkgs> {} }:
with pkgs;
with lib;
let
  nameToPackage = str:
    getAttrFromPath (splitString "." str) pkgs;

  getNodejs = variant:
    assert (assertMsg (variant != "") "Error: variant option is required by nodejs module");
    nameToPackage "pkgs.nodejs-${variant}_x";

  mkDependencies = config:
    concatStringsSep " " (config.installPackages ++ config.installUrls ++ config.installDirectories);

  env = { config, nixPkgs, devEnvDirectory }:
    let
      nodejs = getNodejs config.variant;
      nodeDependencies = "${devEnvDirectory}/npm";
    in
      ''
        export NODE_PATH="${nodeDependencies}/lib/node_modules"
        export npm_config_prefix="${nodeDependencies}"
        export PATH="${nodeDependencies}/bin:${nodejs}/bin:$PATH"
      '';

  createCommand = { config, nixPkgs, devEnvDirectory }:
    let
      deps = mkDependencies config;
      script = writeScript "create-command.sh" ''
        #!${stdenv.shell}
        set -e

        export PATH="${makeBinPath nixPkgs}:$PATH"
        export npm_config_prefix="${devEnvDirectory}/npm"

        mkdir -p $npm_config_prefix
        ${getNodejs config.variant}/bin/npm install -g ${deps}
      '';
    in
      if deps == "" then null else script;
in {
  name = "nodejs";
  inherit env createCommand;
}
