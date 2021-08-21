import argparse
import os

from devenv import Rm, Run, Modules, Create


def modules(_: argparse.Namespace) -> str:
    instance = Modules()
    results = instance.run()
    return 'Supported modules:\n' + '\n'.join(
        [f' - {name} ({location})' for name, location in results.items()])


def create(args: argparse.Namespace) -> str:
    installPackages = []
    installUrls = []
    installDirectories = []
    nixPackages = []
    nixScripts = []

    for item in args.install:
        if item[0] == '@':
            with open(item[1:], 'r') as f:
                for line in f.readlines():
                    if line[0] == '#':
                        continue
                    elif line:
                        installPackages += [line]

        elif os.path.isdir(item):
            installDirectories += [os.path.abspath(item)]

        elif '://' in item:
            installUrls += [item]

        elif item.startswith('pkgs.'):
            nixPackages += [item]

        elif item.endswith('.nix') and os.path.isfile(item):
            nixScripts += [os.path.abspath(item)]

        else:
            installPackages += [item]

    instance = Create()
    config = {
        'module': args.module,
        'variant': args.variant,
        'installPackages': installPackages,
        'installDirectories': installDirectories,
        'installUrls': installUrls,
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


def rm(args: argparse.Namespace) -> str:
    instance = Rm()
    config = {
        'module': args.module,
        'variant': args.variant,
        'directory': args.directory
    }
    result = instance.run(config)
    return result


def run_devenv():
    parser = argparse.ArgumentParser(
        prog='devenv',
        description='Development environment builder command line interface')

    subparsers = parser.add_subparsers()

    modules_parser = subparsers.add_parser('modules')
    modules_parser.set_defaults(func=modules)

    create_parser = subparsers.add_parser('create')
    create_parser.add_argument('module', type=str)
    create_parser.add_argument('-v', '--variant', type=str, default='')
    create_parser.add_argument(
        '-i', '--install', type=str, action='append', default=[])
    create_parser.add_argument(
        '-p', '--path', type=str, action='append', default=[])
    create_parser.add_argument(
        '-e', '--variable', type=str, nargs=2, metavar=('NAME', 'VALUE'),
        action='append', default=[])
    create_parser.add_argument(
        '-d', '--directory', type=str, default=os.getcwd())
    create_parser.set_defaults(func=create)

    run_parser = subparsers.add_parser('run')
    run_parser.add_argument('module', type=str)
    run_parser.add_argument('cmd', type=str, nargs='+')
    run_parser.add_argument('-v', '--variant', type=str, default='')
    run_parser.add_argument('-d', '--directory', type=str, default=os.getcwd())
    run_parser.set_defaults(func=run)

    rm_parser = subparsers.add_parser('rm')
    rm_parser.add_argument('module', type=str)
    rm_parser.add_argument('-v', '--variant', type=str, default='')
    rm_parser.add_argument('-d', '--directory', type=str, default=os.getcwd())
    rm_parser.set_defaults(func=rm)

    args = parser.parse_args()

    if hasattr(args, 'func'):
        print(args.func(args))
    elif not vars(args):
        parser.print_help()
