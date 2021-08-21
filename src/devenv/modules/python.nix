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

  filterByItemType = type: items:
    map (i: i.item) (filter (i: i.type == type) items);

  env = python: installItems: (machNix python).mkPython {
    requirements = concatStringsSep "\n" (filterByItemType "pkg" installItems);
    packagesExtra = (filterByItemType "url" installItems) ++ (
      map (i: builtins.path { path = i; }) (filterByItemType "dir" installItems)
    );
  };

  module = { variant, paths, installItems }:
    let
      python = "python${variant}";
      env' = env python installItems;
    in
      ''
        export PYTHONPATH="${concatStringsSep ":" paths}:${env'}/lib/${env'.python.libPrefix}/site-packages:$PYTHONPATH"
        export VIRTUAL_ENV="${env'}"
        export PATH="${env'}/bin:$PATH"
      '';
in {
  name = "python";
  inherit module;
}
