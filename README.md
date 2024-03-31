Uses submodules to track bril for dependencies `brili` and `bril2json` and `bril2text`.

Nix sets up a venv for the python utils.

`./bin/setup.sh` should be called to set up a existing venv. This can mean either a fresh clone, or `rm -r .venv` and applying the flake again (this is necessary when moving the dir, as the paths related to the venv get messed up).

## quickstart

```shell
nix develop # (or automatic using direnv)
git submodule init && git submodule update
./bin/setup.sh
```
