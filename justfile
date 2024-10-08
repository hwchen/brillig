@build:
    odin build obril

@run *args="":
    odin run obril -- {{args}}

@run-file bril-file *args="":
    cat {{bril-file}} | bril2json | just run {{args}}

turnt *args="":
    #! /usr/bin/env bash
    echo "building..."
    just build
    echo "testing..."
    time turnt {{args}} test/**/*.bril -j

# -e for envs name
# --save
# --diff
@turnt-path glob-path *args="":
    just obril-build && turnt {{args}} {{glob-path}}

# use zbril or obril
@graphviz bril-file:
    just run-file {{bril-file}} --graphviz | dot -Tpdf -o scratch/cfg.pdf && evince scratch/cfg.pdf

# round trip to test conversion of bril.Program to basic blocks and back.
# jq sorts keys with `-S`
# Can be used like `find bril bril/test/interp/core --exec just roundtrip`
# Be careful with obril, as odin compiles from scratch every time, so need to set
# threads to 1 by `find -j=1`
# TODO put this into test suite
@roundtrip bril-file:
    diff <(just run-file {{bril-file}} --unoptimized | jq -S) <(cat {{bril-file}} | bril2json)

# try with bril/examples/test/tdce/simple.bril
# shows before and after.
@dce bril-file:
    just run-file {{bril-file}} --unoptimized | bril2txt
    just run-file {{bril-file}} --dead-code-elimination | bril2txt

@brili *args="":
    deno run bril/brili.ts {{args}}
