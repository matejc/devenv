{ pkgs ? import <nixpkgs> {} }:
with pkgs;
with lib;
let
  package = python3Packages.buildPythonPackage {
    pname = "devenv";
    version = "dev";

    src = ./.;
  };
in
  package
