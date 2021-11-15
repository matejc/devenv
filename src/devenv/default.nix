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

  prefix = if id == null then mkPrefixFromConfig config else mkPrefixFromId id;

  mkPrefixFromId = id:
    if stringLength id == 16 then
      "${builtins.getEnv "HOME"}/.devenv/${id}"
    else
      throw "Id '${id}' is not valid!";

  mkPrefixFromConfig = config:
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
      config = importJSON "${prefix}/config.json";
    in
      mkShell ({
        shellHook = ''
          #!${stdenv.shell}
          ${optionalString loadEnv "source ${prefix}/etc/environment"}
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

  package = if config.package == "" then module.defaultPackage else (nameToPackage config.package);

  nixpkgs = mkNixPkgs { inherit config; };

  doBuild = length (flatten (attrValues config.install)) != 0;

  runBuild =
    let
      build = module.mkBuild {
        inherit package config prefix nixpkgs; };

      environment = module.mkEnvironment {
        inherit package config prefix nixpkgs; };

      executables = module.mkExecutables {
        inherit package config prefix nixpkgs; };

      mkExecutable = { name, executable, loadEnv ? true }:
        writeScriptBin name ''
          #!${stdenv.shell}
          ${optionalString loadEnv "source ${envFile}/etc/environment"}
          exec ${executable} $@
        '';

      envDir = buildEnv {
        name = "devenv-${config.module}-${config.package}";
        paths = [ envFile ] ++ (
          mapAttrsToList (n: v: mkExecutable ({
            name = n;
            executable = v.executable;
            loadEnv = if hasAttr "loadEnv" v then v.loadEnv else true;
          })) executables
        );
        pathsToLink = [ "/bin" "/etc" ];
      };

      envFile = writeTextFile {
        name = "devenv-${config.module}-${package.name}.env";
        text = ''
          ${environment}
          export PATH="${prefix}/bin:${concatStringsSep ":" config.srcs}:$PATH"
          ${concatMapStringsSep "\n" (e: ''export ${e.name}="${e.value}"'') config.variables}
        '';
        executable = true;
        destination = "/etc/environment";
      };

      configFile = writeText "devenv-${config.module}-${package.name}.json" (builtins.toJSON config);

      buildScript = writeScript "devenv-${config.module}-${package.name}.sh" ''
        #!${stdenv.shell}
        set -e
        ${build}
      '';
    in runInShell { command = ''
      mkdir -p "${prefix}"
      ln -sf ${envDir}/* "${prefix}/"
      ln -sf "${configFile}" "${prefix}/config.json"
      { ${
        if doBuild then buildScript else "true"
      }; } && echo -e "\n$(basename ${prefix})"
    ''; };

  runRun =
    runInShell { command = config.cmd; loadEnv = true; };

  runRm = runInShell { command = ''
    if [ ! -d "${prefix}" ]; then
      echo "Environment '$(basename ${prefix})' does not exist" >&2
      exit 1
    fi
    rm -Irf "${prefix}"
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
