import argparse
import os

from devenv import Rm, Run, Modules, Create


def modules(_: argparse.Namespace) -> str:
    instance = Modules()
    results = instance.run()
    return 'Supported modules:\n' + '\n'.join(
        [f' - {name} ({location})' for name, location in results.items()])


def create(args: argparse.Namespace) -> str:
    def installItems(install: list[str]) -> list[str]:
        items = []
        for item in install:
            if item[0] == '@':
                with open(item[1:], 'r') as f:
                    items += f.readlines()
            elif os.path.isdir(item):
                items += [f'{os.path.abspath(item)}{os.path.sep}']
            else:
                items += [item]
        return items

    instance = Create()
    args = {
        'module': args.module,
        'variant': args.variant,
        'install': ':'.join(installItems(args.install)),
        'path': ':'.join([os.path.abspath(p) for p in args.path]),
        'directory': args.directory
    }
    result = instance.run(args)
    return result


def run(args: argparse.Namespace) -> str:
    instance = Run()
    args = {
        'module': args.module,
        'variant': args.variant,
        'cmd': ' '.join(args.cmd),
        'directory': args.directory
    }
    result = instance.run(args)
    return result


def rm(args: argparse.Namespace) -> str:
    instance = Rm()
    args = {
        'module': args.module,
        'variant': args.variant,
        'directory': args.directory
    }
    result = instance.run(args)
    return result


def run_devenv():
    parser = argparse.ArgumentParser(
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
        print(args.func(args) or "Exited with 0")
    elif not vars(args):
        parser.print_help()
