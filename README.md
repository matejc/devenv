# devenv

Pluggable development environments builder that has potential to support *any* language or framework environment.

Nix is being used for building environments, but you do not need to interact with Nix for using this tool (except installing it).

DevEnv is what virtualenv is for Python, just for *any* supported language.


## Requirements

- Nix (https://nixos.org/download.html#nix-quick-install)


## Install

With Nix:

```shell
$ git clone git://github.com/matejc/devenv
$ nix-env -f ./devenv -i
$ devenv modules  # to try out if it lists modules
```

With PIP inside venv:

```shell
$ git clone git://github.com/matejc/devenv
$ python3 -m venv ./devenv
$ ./devenv/bin/pip install ./devenv
$ ./devenv/bin/devenv modules  # to try out if it lists modules
```

With Docker:

```
$ git clone git://github.com/matejc/devenv

```


## Usage (Python module)

### Build the environment

This will not litter in your environment or your project directory.

Dependencies will be installed in `/nix/store` like the behavior of Nix.

Environment files will be saved in your home directory as `~/.devenv/<hash>/env`.

Example for python project, before doing this you need to `cd` into project directory:

```shell
$ devenv build python -v 39 -i @requirements.txt -i robotframework==3.2.2 -p ./src
```

Command will build the environment for Python 3.9 with dependencies from
the `./requirements.txt` and with Robot Framework 3.2.2. Additionally it will add
`./src` to the start of `PYTHONPATH`.
On it's own this procedure will not touch your current shell in any way.


### Using the environment

For running command under the environment you need to specify module name (in our example that is `python`)
and a variant if it was used at creation time, since you can have multiple environments
with different variants (Python versions in this example). Additionally you need
to run this command in same directory (or override working directory with `--directory` flag).

```shell
$ devenv run python -v 39 -- python -m yourpackage ...
```

If you want to create a sub-shell environment, you can do this:

```shell
$ devenv run python -v 39 -- $SHELL
```


### Removing the environment

Like `run`, this command needs to have same module name, module variant and working directory.

```shell
$ devenv rm python -v 39
```

Additionally you can run the:

```shell
nix-collect-garbage -d
```

For more info about Nix garbage collector: https://nixos.org/guides/nix-pills/garbage-collector.html


### List currently supported modules

```shell
$ devenv modules
```


## Development

With Nix:

```shell
$ git clone git://github.com/matejc/devenv
$ cd devenv
$ nix-shell
```

With PIP inside venv:

```shell
$ git clone git://github.com/matejc/devenv
$ python3 -m venv ./devenv
$ ./devenv/bin/pip install -e ./devenv
$ ./devenv/bin/devenv modules  # to try out if it lists modules
```


### Develop more modules

For example there is Python module:
https://github.com/matejc/devenv/blob/master/src/devenv/modules/python.nix

You can override or add more modules by creating DevEnv module files in empty directory.
Then include absolute paths to directories (separated by ':' if you have more)
to `DEVENV_MODULES_PATH` environment variable before running `devenv`.

To check which module is picked up, use the list supported modules command.
