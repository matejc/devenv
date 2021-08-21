import os

from subprocess import CalledProcessError, PIPE, run
import sys

BASEDIR = os.environ.get('DEVENV_BASEDIR',
                         os.path.dirname(os.path.abspath(__file__)))

DEBUG = os.environ.get('DEVENV_DEBUG', None)


class _Interface(object):
    action: str
    result: str

    def __init__(self, action: str):
        self.action = action

    def _run_nix_shell(self, args: dict[str, str]) -> str:
        _args = ['--show-trace'] if DEBUG else ['--quiet']
        for k, v in args.items():
            _args += ['--argstr', f'{k}', f'{v}']
        try:
            p = run(['nix-shell', BASEDIR] + _args,
                    check=True, stdout=PIPE, stderr=sys.stderr,
                    encoding='utf-8')
            return p.stdout
        except CalledProcessError as e:
            raise e

    def run(self, args: dict[str, str] = None):
        _args = {'action': self.action}
        for k, v in (args or {}).items():
            _args[k] = v
        self.result = self._run_nix_shell(_args)
        return self._return()

    def _return(self):
        raise NotImplementedError()


class Modules(_Interface):

    def __init__(self):
        super().__init__('modules')

    def _return(self):
        module_list = [line.split(':') for line in self.result.splitlines()]
        return {name: location for name, location in module_list}


class Create(_Interface):

    def __init__(self):
        super().__init__('create')

    def _return(self):
        return self.result


class Run(_Interface):

    def __init__(self):
        super().__init__('run')

    def _return(self):
        return self.result


class Rm(_Interface):

    def __init__(self):
        super().__init__('rm')

    def _return(self):
        return self.result
