{ pkgs ? import <nixpkgs> {} }:
pkgs.python3Packages.buildPythonPackage {
  pname = "devenv";
  version = "dev";

  src = ./.;

  shellHook = ''
    export PYTHONPATH="./src:$PYTHONPATH"
    export PATH="${pkgs.python3Packages.python}/bin:$PATH"
    alias devenv="python -m devenv"
  '';
}
