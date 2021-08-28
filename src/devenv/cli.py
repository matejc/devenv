import argparse
import json
import os

from devenv import Rm, Run, Modules, Build


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

    instance = Build()
    config = {
        'module': args.module,
        'variant': args.variant,
        'installPackages': installPackages,
        'installDirectories': installDirectories,
        'installUrls': installUrls,
        'installFiles': installFiles,
        'nixPackages': nixPackages,
        'nixScripts': nixScripts,
        'paths': [os.path.abspath(p) for p in args.path],
        'variables': [{'name': n, 'value': v} for n, v in args.variable],
        'directory': args.directory
    }
    result = instance.run(config)
    return result


def run(args: argparse.Namespace) -> str:
    instance = Run()
    config = {
        'module': args.module,
        'variant': args.variant,
        'cmd': ' '.join(args.cmd),
        'directory': args.directory
    }
    result = instance.run(config)
    return result


def run_by_id(args: argparse.Namespace) -> str:
    instance = Run(args.id)
    config = {
        'cmd': ' '.join(args.cmd)
    }
    result = instance.run(config)
    return result


def rm(args: argparse.Namespace) -> str:
    instance = Rm()
    config = {
        'module': args.module,
        'variant': args.variant,
        'directory': args.directory
    }
    result = instance.run(config)
    return result


def rm_by_id(args: argparse.Namespace) -> str:
    instance = Rm(args.id)
    config = {}
    result = instance.run(config)
    return result


def get_configs() -> str:
    env_prefix = os.path.join(os.environ['HOME'], '.devenv')
    if not os.path.isdir(env_prefix):
        return {}

    results = {}
    for d in os.listdir(env_prefix):
        env_dir = os.path.abspath(os.path.join(env_prefix, d))
        if os.path.isdir(env_dir):
            with open(os.path.join(env_dir, 'config.json'), 'r') as f:
                config = json.load(f)
                config['id'] = d
                results[d] = config
    return results


def search_configs(query: dict[str, object]):
    configs = get_configs()
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
    query = {n: v for n, v in args.option}
    configs = get_configs() if len(args.option) == 0 else search_configs(query)
    results = []
    for _id, config in configs.items():
        module = config['module']
        variant = config['variant']
        directory = config['directory']
        results += [f'{_id} - {module} ({variant}) {directory}']
    return '\n'.join(sorted(results))


def run_devenv():
    parser = argparse.ArgumentParser(
        prog='devenv',
        description='Development environment builder command line interface')

    subparsers = parser.add_subparsers()

    modules_parser = subparsers.add_parser('modules')
    modules_parser.set_defaults(func=modules)

    build_parser = subparsers.add_parser('build')
    build_parser.add_argument('module', type=str)
    build_parser.add_argument('-v', '--variant', type=str, default='')
    build_parser.add_argument(
        '-i', '--install', type=str, action='append', default=[])
    build_parser.add_argument(
        '-p', '--path', type=str, action='append', default=[])
    build_parser.add_argument(
        '-e', '--variable', type=str, nargs=2, metavar=('NAME', 'VALUE'),
        action='append', default=[])
    build_parser.add_argument(
        '-d', '--directory', type=str, default=os.getcwd())
    build_parser.set_defaults(func=build_func)

    run_parser = subparsers.add_parser('run')
    run_parser.add_argument('module', type=str)
    run_parser.add_argument('-v', '--variant', type=str, default='')
    run_parser.add_argument('-d', '--directory', type=str, default=os.getcwd())
    run_parser.add_argument('cmd', type=str, nargs='+')
    run_parser.set_defaults(func=run)

    run_id_parser = subparsers.add_parser('run-by-id')
    run_id_parser.add_argument('id', type=str)
    run_id_parser.add_argument('cmd', type=str, nargs='+')
    run_id_parser.set_defaults(func=run_by_id)

    rm_parser = subparsers.add_parser('rm')
    rm_parser.add_argument('module', type=str)
    rm_parser.add_argument('-v', '--variant', type=str, default='')
    rm_parser.add_argument('-d', '--directory', type=str, default=os.getcwd())
    rm_parser.set_defaults(func=rm)

    rm_id_parser = subparsers.add_parser('rm-by-id')
    rm_id_parser.add_argument('id', type=str)
    rm_id_parser.set_defaults(func=rm_by_id)

    list_parser = subparsers.add_parser('list')
    list_parser.add_argument(
        '-o', '--option', type=str, nargs=2, metavar=('NAME', 'VALUE'),
        action='append', default=[])
    list_parser.set_defaults(func=list_func)

    args = parser.parse_args()

    if hasattr(args, 'func'):
        print(args.func(args))
    elif not vars(args):
        parser.print_help()
