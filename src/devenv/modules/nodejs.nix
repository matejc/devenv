{ pkgs ? import <nixpkgs> {} }:
with pkgs;
with lib;
let
  mkEnvironment = { package, config, nixPkgs, devEnvDirectory }: {
    environment = ''
      export NODE_PATH="${devEnvDirectory}/npm/lib/node_modules"
      export npm_config_prefix="${devEnvDirectory}/npm"
      export PATH="${devEnvDirectory}/npm/bin:${package}/bin:$PATH"
    '';
    executables.node.executable = "${package}/bin/node";
  };

  mkBuild = { package, config, nixPkgs, devEnvDirectory }:
    let
      deps = concatStringsSep " " (config.installPackages ++
                                   config.installUrls ++
                                   config.installDirectories ++
                                   config.installFiles);
      script = writeScript "build.sh" ''
        #!${stdenv.shell}
        set -e

        export PATH="${makeBinPath nixPkgs}:$PATH"
        export npm_config_prefix="${devEnvDirectory}/npm"

        mkdir -p $npm_config_prefix
        ${package}/bin/npm install -g ${deps}
      '';
    in
      optionalString (deps != "") script;
in {
  name = "nodejs";
  inherit mkEnvironment mkBuild;
}
