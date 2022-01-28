import argparse
import hashlib
import json
import os

from typing import Any

from devenv import Rm, Run, Modules, Build


CWD = os.getcwd()


def modules(_: argparse.Namespace) -> str:
    instance = Modules()
    results = instance.run()
    return '\n'.join(sorted(
        [f' - {name} ({location})' for name, location in results.items()]))


def build_func(args: argparse.Namespace) -> str:
    installPackages = []
    installUrls = []
    installDirectories = []
    installFiles = []
    nixPackages = []
    nixScripts = []

    for item in args.install:
        if os.path.isdir(item):
            installDirectories += [os.path.abspath(item)]

        elif '://' in item:
            installUrls += [item]

        elif item.startswith('pkgs.'):
            nixPackages += [item]

        elif item.endswith('.nix') and os.path.isfile(item):
            nixScripts += [os.path.abspath(item)]

        elif os.path.isfile(item):
            installFiles += [os.path.abspath(item)]

        else:
            installPackages += [item]

    instance = Build(_directory=args.directory, _name=args.name)
    config = {
        'module': args.module,
        'package': args.package,
        'install': {
            'packages': installPackages,
            'directories': installDirectories,
            'urls': installUrls,
            'files': installFiles,
        },
        'nixPackages': nixPackages,
        'nixScripts': nixScripts,
        'srcs': [os.path.abspath(p) for p in args.source],
        'variables': [{'name': n, 'value': v} for n, v in args.variable],
    }
    result = instance.run(config)
    return result


def run(args: argparse.Namespace) -> str:
    instance = Run(_id=args.id, _directory=args.directory)
    config = {
        'cmd': ' '.join(args.cmd)
    }
    result = instance.run(config)
    return result


def rm(args: argparse.Namespace) -> str:
    instance = Rm(_id=args.id, _directory=args.directory)
    config = {}
    result = instance.run(config)
    return result


def get_configs(directory: str = '') -> dict[str, Any]:
    env_prefix = os.path.join(os.environ['HOME'], '.devenv')
    if not os.path.isdir(env_prefix):
        return {}

    envs = []
    if directory:
        directoryHash = hashlib.sha1(directory.encode()).hexdigest()[:16]
        try:
            with open(os.path.join(env_prefix, 'dirs', directoryHash), 'r') as f:
                envs = [line.strip() for line in f.readlines()]
                envs = [line for line in envs if line]
        except FileNotFoundError:
            envs = []
    else:
        envs = os.listdir(env_prefix)

    results = {}
    for d in envs:
        if len(d) != 16:
            continue
        env_dir = os.path.abspath(os.path.join(env_prefix, d))
        if os.path.isdir(env_dir):
            with open(os.path.join(env_dir, 'config.json'), 'r') as f:
                config = json.load(f)
                config['id'] = d
                results[d] = config
    return results


def search_configs(query: dict[str, object], directory: str = ''):
    configs = get_configs(directory=directory)
    results = {}
    for qk, qv in query.items():
        for _id, config in configs.items():
            if config[qk] == qv:
                if results.get(_id, False):
                    results[_id]['count'] += 1
                else:
                    results[_id] = {'config': config, 'count': 1}
    out = {k: v['config']
           for k, v in results.items() if v['count'] == len(query)}
    return out


def list_func(args: argparse.Namespace) -> str:
    env_prefix = os.path.join(os.environ['HOME'], '.devenv')
    directory = ''
    if not args.all:
        directory = os.path.abspath(args.directory)
    query = {n: v for n, v in args.option}
    configs = get_configs(directory=directory) if len(args.option) == 0 else search_configs(query, directory=directory)
    results = []
    for _id, config in configs.items():
        module = config['module']
        package = config['package'] or 'default'
        installs = '\n - '.join(sorted(
            config['install']['packages'] +
            config['install']['directories'] +
            config['install']['files'] +
            config['install']['urls'] +
            config['nixPackages'] +
            config['nixScripts']
        ))
        env_dir = os.path.abspath(os.path.join(env_prefix, config['id']))
        path = ''
        try:
            with open(os.path.join(env_dir, 'name'), 'r') as f:
                path = os.path.join(env_prefix, 'names', f.read().strip())
            if os.path.realpath(path) != env_dir:
                raise FileNotFoundError(path)
        except FileNotFoundError:
            path = env_dir

        results += [
            f'Id: {_id}\nModule: {module}\nPackage: {package}\nEnvironment: {path}/etc/environment\nDependencies:\n - {installs}\n'
        ]
    return '\n'.join(results)


def run_devenv():
    parser = argparse.ArgumentParser(
        prog='devenv',
        description='Development environment builder command line interface')

    subparsers = parser.add_subparsers()

    modules_parser = subparsers.add_parser('modules')
    modules_parser.set_defaults(func=modules)

    build_parser = subparsers.add_parser('build')
    build_parser.add_argument('module', type=str)
    build_parser.add_argument('-d', '--directory', type=str, default=CWD)
    build_parser.add_argument('-p', '--package', type=str, default='')
    build_parser.add_argument('-n', '--name', type=str, default='')
    build_parser.add_argument(
        '-i', '--install', type=str, action='append', default=[])
    build_parser.add_argument(
        '-s', '--source', type=str, action='append', default=[])
    build_parser.add_argument(
        '-v', '--variable', type=str, nargs=2, metavar=('NAME', 'VALUE'),
        action='append', default=[])
    build_parser.set_defaults(func=build_func)

    run_parser = subparsers.add_parser('run')
    run_parser_group = run_parser.add_mutually_exclusive_group(
        required=False)
    run_parser_group.add_argument('--id', type=str, default='')
    run_parser_group.add_argument(
        '-d', '--directory', type=str, default=CWD)
    run_parser.add_argument('cmd', type=str, nargs='*')
    run_parser.set_defaults(func=run)

    rm_parser = subparsers.add_parser('remove')
    rm_parser_group = rm_parser.add_mutually_exclusive_group(
        required=True)
    rm_parser_group.add_argument('--id', type=str,  default='')
    rm_parser_group.add_argument('-d', '--directory', type=str, default=CWD)
    rm_parser.set_defaults(func=rm)

    list_parser = subparsers.add_parser('list')
    list_parser_group = list_parser.add_mutually_exclusive_group(
        required=False)
    list_parser_group.add_argument('-d', '--directory', type=str, default=CWD)
    list_parser_group.add_argument('-a', '--all', action='store_true')
    list_parser.add_argument(
        '-o', '--option', type=str, nargs=2, metavar=('NAME', 'VALUE'),
        action='append', default=[])
    list_parser.set_defaults(func=list_func)

    args = parser.parse_args()

    if hasattr(args, 'func'):
        print(args.func(args))
    elif not vars(args):
        parser.print_help()
