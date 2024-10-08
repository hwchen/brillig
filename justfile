@obril-build:
    odin build obril

@obril *args="":
    just obril-build && ./obril.bin {{args}} | just clean-nulls

@obril-raw *args="":
    just obril-build && ./obril.bin {{args}}

@obril-file bril-file *args="":
    cat {{bril-file}} | bril2json | just obril {{args}}

@zbril-build:
    cd zbril && zig build

@zbril *args="":
    just zbril-build && ./zbril/zig-out/bin/zbril {{args}}

@zbril-file bril-file *args="":
    cat {{bril-file}} | bril2json | just zbril {{args}}

turnt *args="":
    #! /usr/bin/env bash
    echo "building..."
    just obril-build
    just zbril-build
    echo "testing..."
    time turnt {{args}} test/**/*.bril -j

# -e for envs name
# --save
# --diff
@turnt-path glob-path *args="":
    just zbril-build && just obril-build && turnt {{args}} {{glob-path}}

# use zbril or obril
@graphviz exe bril-file:
    just {{exe}}-file {{bril-file}} --graphviz | dot -Tpdf -o scratch/cfg.pdf && evince scratch/cfg.pdf

# round trip to test conversion of bril.Program to basic blocks and back.
# jq sorts keys with `-S`
# Can be used like `find bril bril/test/interp/core --exec just roundtrip`
# Be careful with obril, as odin compiles from scratch every time, so need to set
# threads to 1 by `find -j=1`
# TODO put this into test suite
@roundtrip exe bril-file:
    diff <(just {{exe}}-file {{bril-file}} --unoptimized | jq -S) <(cat {{bril-file}} | bril2json)

# try with bril/examples/test/tdce/simple.bril
# shows before and after.
@dce exe bril-file:
    just {{exe}}-file {{bril-file}} --unoptimized | bril2txt
    just {{exe}}-file {{bril-file}} --dead-code-elimination | bril2txt

@brili *args="":
    deno run bril/brili.ts {{args}}
