Uses submodules to track bril for dependencies `brili` and `bril2json` and `bril2text`.

Nix sets up a venv for the python utils.

`./bin/setup.sh` should be called to set up bril2json and bril2txt. Unfortunately they are installed to local rust/cargo folders instead of a project .venv, but the python versions were too slow.

## quickstart

```shell
nix develop # (or automatic using direnv)
git submodule init && git submodule update
./bin/setup.sh
```
