{ pkgs ? import <nixpkgs> {}
, action ? ""
, module ? ""
, variant ? ""
, cmd ? ""
, path ? ""
, install ? ""
, directory ? builtins.getEnv "PWD"
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

  splitInstallItems = items:
    map (item:
      if hasSuffix "/" item then { inherit item; type = "dir"; }
      else if hasInfix "://" item then { inherit item; type = "url"; }
      else { inherit item; type = "pkg"; }
    ) items;

  envDirectory =
    let
      hash = builtins.hashString "sha1" "${module}:${variant}:${directory}";
    in
      "${builtins.getEnv "HOME"}/.devenv/${hash}";

  runListModules =
    concatMapStringsSep "\n" (m: "echo '${m.name}:${m.location}'") (mapAttrsToList (n: v: v) modules);

  runCreate =
    let
      paths = splitString ":" path;
      installItems = splitInstallItems (splitString ":" install);
      env =
        if builtins.hasAttr module modules then
          modules."${module}".module {
            inherit variant paths installItems;
          }
        else
          throw "Error: Module '${module}' not supported!";
    in ''
      mkdir -p "${envDirectory}"
      ln -sf "${env}" "${envDirectory}/env"
    '';

  runRun =
    if builtins.hasAttr module modules then
      ''
        if [ ! -f "${envDirectory}/env" ]; then
          echo "Environment for directory $PWD does not exist" >&2
          exit 1
        fi
        source "${envDirectory}/env"
        ${cmd}
      ''
    else
      throw "Error: Module '${module}' not supported!";

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
