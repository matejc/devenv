{ pkgs ? import <nixpkgs> {} }:
with pkgs;
with lib;
let
  default = primary: secondary:
    if primary != "" then primary else secondary;

  pypiDataRev = default (builtins.getEnv "DEVENV_PYPI_DATA_REV")
    "c8393888d97e74f2217aaafae70bf5bc5c913535";

  pypiDataSha256 = default (builtins.getEnv "DEVENV_PYPI_DATA_SHA256")
    "0pfivp1w3pdbsamnmmyy4rsnc4klqnmisjzcq0smc4pp908b6sc3";

  machNix = python: import (builtins.fetchGit {
    url = "https://github.com/DavHau/mach-nix/";
    ref = "refs/tags/3.3.0";
  }) {
    inherit pkgs python pypiDataRev pypiDataSha256;
  };

  packagesFromFiles = files:
    let
      lines = flatten (map (file: splitString "\n" (readFile (builtins.path { path = file; }))) files);
      removeComments = filter (line: line != "" && !(hasPrefix "#" line));
    in
      removeComments lines;

  mkEnv = { python, nixPkgs, installPackages, installUrls, installDirectories }:
    (machNix python).mkPython {
      requirements = concatStringsSep "\n" installPackages;
      packagesExtra = installUrls ++ (
        map (i: builtins.path { path = i; }) installDirectories
      ) ++ nixPkgs;
    };

  env = { config, nixPkgs, devEnvDirectory }:
    let
      python = "python${config.variant}";
      installPackages = config.installPackages ++ (packagesFromFiles config.installFiles);
      env = mkEnv {
        inherit python nixPkgs installPackages;
        inherit (config) installUrls installDirectories;
      };
    in {
      env = ''
        export PYTHONPATH="${concatStringsSep ":" config.paths}:${env}/lib/${env.python.libPrefix}/site-packages:$PYTHONPATH"
        export VIRTUAL_ENV="${env}"
        export PATH="${env}/bin:$PATH"
      '';
      executables.python.executable = "${env}/bin/python";
    };
in {
  name = "python";
  inherit env;
}
