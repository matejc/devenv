FROM nixos/nix

RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
RUN nix-channel --update

ADD . /src

RUN nix-build -o /devenv-result /src

ENTRYPOINT ["/devenv-result/bin/devenv"]
