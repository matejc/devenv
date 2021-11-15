{ pkgs ? import <nixpkgs> {} }:
let
  mkEnvironment = { package, config, nixpkgs, prefix }: ''
    export NODE_PATH="${prefix}/npm/lib/node_modules"
    export npm_config_prefix="${prefix}/npm"
    export PATH="${prefix}/npm/bin:${package}/bin:$PATH"
  '';

  mkExecutables = { package, config, nixpkgs, prefix }: {
    node.executable = "${package}/bin/node";
  };

  mkBuild = { package, config, nixpkgs, prefix }: ''
    export PATH="${pkgs.lib.makeBinPath nixpkgs}:$PATH"
    export npm_config_prefix="${prefix}/npm"
    mkdir -p $npm_config_prefix
    ${package}/bin/npm install -g ${pkgs.lib.concatStringsSep " " (
      config.install.packages ++
      config.install.urls ++
      config.install.directories ++
      config.install.files
    )}
  '';
in {
  name = "nodejs";
  defaultPackage = pkgs.nodejs;
  inherit mkEnvironment mkExecutables mkBuild;
}
