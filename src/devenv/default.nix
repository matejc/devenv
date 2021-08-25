{ pkgs ? import <nixpkgs> {}
, action ? ""
, id ? null
, configJSON ? "{}"
, extraModulesPath ? builtins.getEnv "DEVENV_MODULES_PATH" }:
with pkgs;
with lib;
let
  run =
    if action == "modules" then runListModules
    else if action == "build" then runBuild
    else if action == "run" then runRun
    else if action == "rm" then runRm
    else throw "Error: Action '${action}' not supported!";

  config = builtins.fromJSON configJSON;

  devEnvDirectory = if id == null then mkDevEnvDirectoryFromConfig config else mkDevEnvDirectoryFromId id;

  mkDevEnvDirectoryFromId = id:
    if stringLength id == 16 then
      "${builtins.getEnv "HOME"}/.devenv/${id}"
    else
      throw "Id '${id}' is not valid!";

  mkDevEnvDirectoryFromConfig = config:
    let
      setToList = path: set:
        flatten (mapAttrsToList (n: v:
          if (builtins.typeOf v) == "set" then (setToList (path++[n]) v) else "${concatStringsSep "." (path++[n])}=${toString v}"
        ) set);
      content = concatStringsSep "\n" (sort (a: b: a < b) (setToList [] config));
      hash = builtins.hashString "sha1" content;
    in
      "${builtins.getEnv "HOME"}/.devenv/${builtins.substring 0 16 hash}";

  nameToPackage = str:
    getAttrFromPath (splitString "." str) pkgs;

  runInShell = { command, loadEnv ? false }:
    let
      config = importJSON "${devEnvDirectory}/config.json";
    in
      mkShell ({
        shellHook = ''
          #!${stdenv.shell}
          ${optionalString loadEnv "source ${devEnvDirectory}/etc/environment"}
          ${command}
          exitCode=$?
          exit $exitCode
        '';
      } // optionalAttrs loadEnv {
        buildInputs = mkNixPkgs { inherit config; };
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

  runBuild =
    let
      nixPkgs = mkNixPkgs { inherit config; };

      buildCommand = if builtins.hasAttr "buildCommand" module then
        module.buildCommand { inherit config devEnvDirectory nixPkgs; }
        else null;

      env = module.env {
        inherit config devEnvDirectory nixPkgs;
      };

      mkExecutable = { name, executable, loadEnv ? true }:
        writeScriptBin name ''
          #!${stdenv.shell}
          ${optionalString loadEnv "source ${envFile}/etc/environment"}
          exec ${executable} $@
        '';

      envDir = buildEnv {
        name = "devenv-${config.module}-${config.variant}";
        paths = [ envFile ] ++ (
          mapAttrsToList (n: v: mkExecutable ({
            name = n;
            executable = v.executable;
          } // (optionalAttrs (hasAttr "loadEnv" v) {
            loadEnv = v.loadEnv;
          }))) (
            optionalAttrs (hasAttr "executables" env) env.executables
          )
        );
        pathsToLink = [ "/bin" "/etc" ];
      };

      envFile =
        let
          script = writeScript "env" ''
            ${env.env}
            export PATH="${devEnvDirectory}/bin:${concatStringsSep ":" config.paths}:$PATH"
            ${concatMapStringsSep "\n" (e: ''export ${e.name}="${e.value}"'') config.variables}
          '';
        in
          runCommand "devenv-environment" {} ''
            mkdir -p $out/etc
            cp ${script} $out/etc/environment
          '';

      configFile = writeText "devenv-${config.module}-${config.variant}.json" (builtins.toJSON config);
    in runInShell { command = ''
      mkdir -p "${devEnvDirectory}"
      ln -sf ${envDir}/* "${devEnvDirectory}/"
      ln -sf "${configFile}" "${devEnvDirectory}/config.json"
      { ${
        if buildCommand != "" && buildCommand != null then buildCommand else "true"
      }; } && echo -e "\n$(basename ${devEnvDirectory})"
    ''; };

  runRun =
    runInShell { command = config.cmd; loadEnv = true; };

  runRm = runInShell { command = ''
    if [ ! -d "${devEnvDirectory}" ]; then
      echo "Environment '$(basename ${devEnvDirectory})' does not exist" >&2
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
