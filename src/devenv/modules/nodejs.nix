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
    concatStringsSep " " (config.installPackages ++
                          config.installUrls ++
                          config.installDirectories ++
                          config.installFiles);

  env = { config, nixPkgs, devEnvDirectory }: {
    env = ''
      export NODE_PATH="${devEnvDirectory}/npm/lib/node_modules"
      export npm_config_prefix="${devEnvDirectory}/npm"
      export PATH="${devEnvDirectory}/npm/bin:${getNodejs config.variant}/bin:$PATH"
    '';
    executables.node.executable = "${getNodejs config.variant}/bin/node";
  };

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
      if deps == "" then "" else script;
in {
  name = "nodejs";
  inherit env createCommand;
}
