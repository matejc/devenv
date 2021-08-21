{ pkgs ? import <nixpkgs> {} }:
with pkgs;
with lib;
let
  package = python3Packages.buildPythonPackage {
    pname = "devenv";
    version = "dev";

    src = ./.;

    shellHook = ''
      export PYTHONPATH="./src:$PYTHONPATH"
      export PATH="${python3Packages.python}/bin:$PATH"
      alias devenv="python -m devenv"
    '';
  };
in
  package
