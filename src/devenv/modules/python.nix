{ pkgs ? import <nixpkgs> {} }:
let
  mkEnvironment = { package, config, nixpkgs, prefix }: ''
    export PYTHONPATH="${pkgs.lib.concatStringsSep ":" config.srcs}:${prefix}/venv/lib/${package.libPrefix}/site-packages:$PYTHONPATH"
    export VIRTUAL_ENV="${prefix}/venv"
    export PATH="${prefix}/venv/bin:${package}/bin:$PATH"
  '';

  mkExecutables = { package, config, nixpkgs, prefix }: {
    python.executable = "${package}/bin/python";
  };

  mkBuild = { package, config, nixpkgs, prefix }: ''
    export PATH="${pkgs.lib.makeBinPath nixpkgs}:$PATH"
    mkdir -p ${prefix}/venv
    ${pkgs.virtualenv}/bin/virtualenv --python ${package}/bin/python --pip bundle "${prefix}/venv"
    ${prefix}/venv/bin/pip install ${pkgs.lib.concatStringsSep " " (
      config.install.packages ++
      config.install.urls ++
      config.install.directories ++
      config.install.files
    )}
  '';
in {
  name = "python";
  defaultPackage = pkgs.python3Packages.python;
  inherit mkEnvironment mkExecutables mkBuild;
}
