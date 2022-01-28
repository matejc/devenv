{ pkgs ? import <nixpkgs> {}
, action ? ""
, id ? null
, directory ? null
, name ? null
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

  _name = if name == null then "" else name;

  _id = if id == null then mkIdFromConfig config else id;
  prefix = mkPrefixFromId _id;

  homePrefix = "${builtins.getEnv "HOME"}/.devenv";

  mkPrefixFromId = id:
    if stringLength id == 16 then
      "${homePrefix}/${id}"
    else
      throw "Id '${id}' is not valid!";

  directoryHash = if directory == null then null else
    builtins.substring 0 16 (builtins.hashString "sha1" directory);

  mkIdFromConfig = config:
    let
      setToList = path: set:
        flatten (mapAttrsToList (n: v:
          if (builtins.typeOf v) == "set" then (setToList (path++[n]) v) else "${concatStringsSep "." (path++[n])}=${toString v}"
        ) set);
      content = concatStringsSep "\n" (sort (a: b: a < b) (setToList [] config));
      hash = builtins.hashString "sha1" content;
    in
      "${builtins.substring 0 16 hash}";

  nameToPackage = str:
    getAttrFromPath (splitString "." str) pkgs;

  runInShell = { command, loadEnv ? false, prefix ? prefix }:
    let
      envExists = builtins.pathExists prefix;
      config = if envExists then importJSON "${prefix}/config.json" else throw "Id '${_id}' does not exist!";
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
    [ stdenv.cc.cc.lib ] ++
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
          export LD_LIBRARY_PATH="${makeLibraryPath nixpkgs}"
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

      if [ ! -z "${directoryHash}" ]
      then
        mkdir -p "${homePrefix}/dirs/"
        touch "${homePrefix}/dirs/${directoryHash}"
        ${gnused}/bin/sed -i '/${_id}/d' "${homePrefix}/dirs/${directoryHash}"
        echo "${_id}" >> "${homePrefix}/dirs/${directoryHash}"
      fi

      if [ ! -z "${_name}" ]
      then
        mkdir -p "${homePrefix}/names/"
        rm "${homePrefix}/names/${name}/name"
        rm "${homePrefix}/names/${name}"
        ln -s "${prefix}" "${homePrefix}/names/${name}"
        echo "${name}" > "${prefix}/name"
      fi

      { ${
        if doBuild then buildScript else "true"
      }; } && echo -e "\n$(basename ${prefix})"
    ''; };

  readLastId =
  let
    content = builtins.readFile "${homePrefix}/dirs/${directoryHash}";
    contentFiltered = filter (l: l != "") (splitString "\n" content);
    lastId = if length contentFiltered > 0 then last contentFiltered else null;
  in
    if builtins.pathExists "${homePrefix}/dirs/${directoryHash}" then lastId else null;

  runRun =
    runInShell {
      command = config.cmd;
      loadEnv = true;
      prefix = if readLastId != null then "${homePrefix}/${readLastId}" else prefix;
    };

  runRm = runInShell { command =
    let
      idStr = builtins.toString id;
    in ''
      if [ -f "${prefix}/name" ]
      then
        rm "${homePrefix}/names/$(cat ${prefix}/name)"
      fi

      if [ ! -z "${idStr}" ]
      then
        if [ ! -d "${prefix}" ]
        then
          echo "Environment '${_id}' does not exist!" >&2
          exit 1
        fi
        rm -Irf "${prefix}"
        if [ -f "${homePrefix}/dirs/${directoryHash}" ]
        then
          ${gnused}/bin/sed -i '/${_id}/d' "${homePrefix}/dirs/${directoryHash}"
        fi
      else
        if [ -f "${homePrefix}/dirs/${directoryHash}" ]
        then
          cat "${homePrefix}/dirs/${directoryHash}" | ${findutils}/bin/xargs -i rm -Irf '${homePrefix}/{}'
          rm "${homePrefix}/dirs/${directoryHash}"
        else
          echo "Directory '${directory}' does not have environments!" >&2
          exit 1
        fi
      fi
    '';
  };

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
