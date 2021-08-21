{ pkgs ? import <nixpkgs> {}
, action ? ""
, configJSON ? "{}"
, extraModulesPath ? builtins.getEnv "DEVENV_MODULES_PATH" }:
with pkgs;
with lib;
let
  run =
    if action == "modules" then runListModules
    else if action == "create" then runCreate
    else if action == "run" then runRun
    else if action == "rm" then runRm
    else throw "Error: Action '${action}' not supported!";

  config = builtins.fromJSON configJSON;

  splitInstallItems = items:
    map (item:
      if hasSuffix "/" item then { inherit item; type = "dir"; }
      else if hasInfix "://" item then { inherit item; type = "url"; }
      else { inherit item; type = "pkg"; }
    ) items;

  envDirectory =
    let
      hash = builtins.hashString "sha1" "${config.module}:${config.variant}:${config.directory}";
    in
      "${builtins.getEnv "HOME"}/.devenv/${hash}";

  nameToPackage = str:
    getAttrFromPath (splitString "." str) pkgs;

  runListModules =
    "echo '${builtins.toJSON (mapAttrs (n: v: v.location) modules)}'";

  runCreate =
    let
      nixPkgs = (map (p: nameToPackage p) config.nixPackages) ++ (
        map (s: callPackage s {}) config.nixScripts);

      env =
        if builtins.hasAttr config.module modules then
          modules."${config.module}".module {
            inherit (config) variant paths installPackages installUrls installDirectories;
            inherit nixPkgs;
          }
        else
          throw "Error: Module '${config.module}' not supported!";

      envFile = writeScript "devenv-${config.module}-${config.variant}" ''
        ${env}

        export PATH="${buildEnv {name = "devenv-nix-pkgs"; paths = nixPkgs;}}/bin:$PATH"

        ${concatMapStringsSep "\n" (e: ''export ${e.name}="${e.value}"'') config.variables}
      '';
    in ''
      mkdir -p "${envDirectory}"
      ln -sf "${envFile}" "${envDirectory}/env"
    '';

  runRun =
    if builtins.hasAttr config.module modules then
      ''
        if [ ! -f "${envDirectory}/env" ]; then
          echo "Environment for directory $PWD does not exist" >&2
          exit 1
        fi
        source "${envDirectory}/env"
        ${config.cmd}
      ''
    else
      throw "Error: Module '${config.module}' not supported!";

  runRm = ''
    if [ ! -f "${envDirectory}/env" ]; then
      echo "Environment for directory $PWD does not exist" >&2
      exit 1
    fi
    rm "${envDirectory}/env"
    rmdir "${envDirectory}"
  '';

  mkModule = location: path:
    let
      m = import path { inherit pkgs; };
    in {
      inherit location;
      module = m.module;
      name = m.name;
    };

  builtinModules = map (path: mkModule "builtin" path) (filesystem.listFilesRecursive "${./.}/modules");
  extraModules =
    if extraModulesPath != "" then
      map (modulePath: mkModule modulePath modulePath) (flatten (
        map (modulesPath: filesystem.listFilesRecursive modulesPath) (splitString ":" extraModulesPath)
      ))
    else [];

  modules =
    let
      allModules = map (m: {name = "${m.name}"; value = m;}) (builtinModules ++ extraModules);
      uniqueModules = builtins.listToAttrs (reverseList allModules);
    in
      uniqueModules;
in
  mkShell {
    shellHook = ''
      #!${stdenv.shell}

      ${run}

      exitCode=$?
      exit $exitCode
    '';
  }
