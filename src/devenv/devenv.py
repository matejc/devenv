import os
import json
import sys

from subprocess import CalledProcessError, PIPE, run

BASEDIR = os.environ.get('DEVENV_BASEDIR',
                         os.path.dirname(os.path.abspath(__file__)))

DEBUG = os.environ.get('DEVENV_DEBUG', None)


class _Interface(object):
    action: str

    def __init__(self, action: str):
        self.action = action

    def _run_nix_shell(self, config: dict[str, object]) -> str:
        _args = ['--show-trace'] if DEBUG else ['--quiet']
        configJSON = json.dumps(config)
        _args += ['--argstr', 'action', self.action]
        _args += ['--argstr', 'configJSON', configJSON]
        try:
            p = run(['nix-shell', BASEDIR] + _args,
                    check=True, stdout=PIPE, stderr=sys.stderr,
                    encoding='utf-8')
            return p.stdout
        except CalledProcessError as e:
            if DEBUG:
                raise e
            else:
                print(str(e), file=sys.stderr)
                exit(1)

    def run(self, config: dict[str, object] = None):
        result = self._run_nix_shell(config or {})
        return self._return(result)

    def _return(self, _: str):
        raise NotImplementedError()


class Modules(_Interface):

    def __init__(self):
        super().__init__('modules')

    def _return(self, result: str):
        return json.loads(result)


class Create(_Interface):

    def __init__(self):
        super().__init__('create')

    def _return(self, result: str):
        return result


class Run(_Interface):

    def __init__(self):
        super().__init__('run')

    def _return(self, result: str):
        return result


class Rm(_Interface):

    def __init__(self):
        super().__init__('rm')

    def _return(self, result: str):
        return result
