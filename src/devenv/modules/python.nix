{ pkgs ? import <nixpkgs> {} }:
with pkgs;
with lib;
let
  mkEnvironment = { package, config, nixPkgs, devEnvDirectory }: {
    environment = ''
      export PYTHONPATH="${concatStringsSep ":" config.srcs}:${package}/lib/${package.libPrefix}/site-packages:$PYTHONPATH"
      export VIRTUAL_ENV="${devEnvDirectory}/venv"
      export PATH="${devEnvDirectory}/venv/bin:${package}/bin:$PATH"
    '';
    executables.python.executable = "${package}/bin/python";
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
        export venv_prefix="${devEnvDirectory}/venv"

        mkdir -p $venv_prefix
        ${package}/bin/python -m venv "$venv_prefix"
        $venv_prefix/bin/python3 -m pip install ${deps}
      '';
    in
      optionalString (deps != "") script;
in {
  name = "python3";
  inherit mkEnvironment mkBuild;
}
