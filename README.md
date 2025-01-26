Uses submodules to track bril for dependencies `brili` and `bril2json` and `bril2text`. (And for lifting examples for testing).

`./bin/setup.sh` should be called to set up bril2json and bril2txt. Unfortunately they are installed to local rust/cargo folders instead of a project .venv, but the python versions were too slow.

## quickstart

```shell
git submodule init && git submodule update
./bin/setup.sh
```

Note some other required deps:
- turnt (for testing), install from pip.
- jq (for sorting keys, and working with json format generally).
- graphviz if using visualization.
