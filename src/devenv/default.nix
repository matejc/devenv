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

  devEnvDirectory =
    let
      hash = builtins.hashString "sha1" "${config.module}:${config.variant}:${config.directory}";
    in
      "${builtins.getEnv "HOME"}/.devenv/${hash}";

  nameToPackage = str:
    getAttrFromPath (splitString "." str) pkgs;

  runInShell = { command, loadEnv ? false }:
    let
      envAttrs = importJSON "${devEnvDirectory}/env.json";
      env = optionalString loadEnv envAttrs.env;
    in
      mkShell ({
        shellHook = ''
          #!${stdenv.shell}
          ${env}
          ${command}
          exitCode=$?
          exit $exitCode
        '';
      } // optionalAttrs loadEnv {
        buildInputs = mkNixPkgs { config = envAttrs; };
      });

  runListModules =
    runInShell { command = "echo '${builtins.toJSON (mapAttrs (n: v: v.location) modules)}'"; };

  mkNixPkgs = { config }:
    (map (p: nameToPackage p) config.nixPackages) ++
    (map (s: callPackage s {}) config.nixScripts);

  module =
    if builtins.hasAttr config.module modules then
      modules."${config.module}"
    else
      throw "Error: Module '${config.module}' not supported!";

  runCreate =
    let
      nixPkgs = mkNixPkgs { inherit config; };

      env = module.env {
        inherit config devEnvDirectory nixPkgs;
      };

      createCommand = if builtins.hasAttr "createCommand" module then
        module.createCommand { inherit config devEnvDirectory nixPkgs; }
        else "";

      envAttrs = { inherit (config) module variant directory; };
      envAttrs.env = ''
        ${env}

        ${concatMapStringsSep "\n" (e: ''export ${e.name}="${e.value}"'') config.variables}
        export PATH="${concatStringsSep ":" config.paths}:$PATH"
      '';
      envAttrs.nixPackages = config.nixPackages;
      envAttrs.nixScripts = config.nixScripts;

      envFile = writeScript "devenv-${config.module}-${config.variant}.json" (builtins.toJSON envAttrs);
    in runInShell { command = ''
      mkdir -p "${devEnvDirectory}"
      ln -sf "${envFile}" "${devEnvDirectory}/env.json"
      ${createCommand}
    ''; };

  runRun =
    runInShell { command = config.cmd; loadEnv = true; };

  runRm = runInShell { command = ''
    if [ ! -d "${devEnvDirectory}" ]; then
      echo "Environment for directory $PWD does not exist" >&2
      exit 1
    fi
    rm -Irf "${devEnvDirectory}"
  ''; };

  mkModule = location: path:
    let
      m = import path { inherit pkgs; };
    in m // {
      inherit location;
    };

  builtinModules = map (path: mkModule "builtin" path) (filesystem.listFilesRecursive "${./.}/modules");
  extraModules =
    let
      getNixFiles = path:
        filter (p: hasSuffix ".nix" p) (filesystem.listFilesRecursive path);
    in
    if extraModulesPath != "" then
      map (modulePath: mkModule modulePath modulePath) (flatten (
        map (modulesPath: getNixFiles modulesPath) (splitString ":" extraModulesPath)
      ))
    else [];

  modules =
    let
      allModules = map (m: {name = "${m.name}"; value = m;}) (builtinModules ++ extraModules);
      uniqueModules = builtins.listToAttrs (reverseList allModules);
    in
      uniqueModules;
in
  run
