import os
import json
import sys

from subprocess import CalledProcessError, PIPE, run
from typing import Any

BASEDIR = os.environ.get('DEVENV_BASEDIR',
                         os.path.dirname(os.path.abspath(__file__)))

DEBUG = os.environ.get('DEVENV_DEBUG', None)


def execute(cmd: list[str], return_stdout: bool):
    try:
        stream = PIPE if return_stdout else sys.stdout
        p = run(cmd, check=True, stdout=stream, stderr=sys.stderr,
                encoding='utf-8')
        return p.stdout if return_stdout else ''
    except CalledProcessError as e:
        if DEBUG:
            raise e
        else:
            print(str(e), file=sys.stderr)
            exit(1)


class _Interface(object):
    action: str
    id: str = ''
    directory: str = ''
    name: str = ''

    def __init__(self, action: str, return_stdout: bool = False):
        self.action = action
        self.return_stdout = return_stdout

    def _run_nix_shell(self, config: dict[str, Any]) -> str:
        _args = ['--show-trace'] if DEBUG else ['--quiet']
        if self.id:
            _args += ['--argstr', 'id', self.id]
        if self.directory:
            _args += ['--argstr', 'directory', os.path.abspath(self.directory)]
        if self.name:
            _args += ['--argstr', 'name', self.name]
        _args += ['--argstr', 'action', self.action]
        configJSON = json.dumps(config)
        _args += ['--argstr', 'configJSON', configJSON]
        return execute(['nix-shell', BASEDIR] + _args,
                       return_stdout=self.return_stdout)

    def run(self, config: dict[str, Any] = None):
        result = self._run_nix_shell(config or {})
        return self._return(result)

    def _return(self, _: str):
        raise NotImplementedError()


class Modules(_Interface):

    def __init__(self):
        super().__init__('modules', True)

    def _return(self, result: str):
        return json.loads(result)


class Build(_Interface):

    def __init__(self, _directory: str = '', _name: str = ''):
        super().__init__('build')
        self.directory = _directory
        self.name = _name

    def _return(self, result: str):
        return result


class Run(_Interface):

    def __init__(self, _id: str = '', _directory: str = ''):
        super().__init__('run')
        self.id = _id
        self.directory = _directory

    def _return(self, result: str):
        return result


class Rm(_Interface):

    def __init__(self, _id: str = '', _directory: str = ''):
        super().__init__('rm')
        self.id = _id
        self.directory = _directory

    def _return(self, result: str):
        return result
