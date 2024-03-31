# Language-specific commands
@brilo-build:
    odin build brilo

@brilo *args="":
    just brilo-build && ./brilo.bin {{args}} | just clean-nulls -c

@brilo-file bril-file *args="":
    cat {{bril-file}} | bril2json | just brilo {{args}}

@brilz-build:
    cd brilz && zig build

@brilz *args="":
    just brilz-build && ./brilz/zig-out/bin/bril-zig {{args}}

@brilz-file bril-file *args="":
    cat {{bril-file}} | bril2json | just brilz {{args}}

# None-language-specific commands

# -e for envs name
# --save
# --diff
@test *args="":
    just brilz-build && turnt {{args}} test/**/*.bril

# use brilz or brilo
@graphviz exe bril-file:
    just {{exe}}-file {{bril-file}} --graphviz | dot -Tpdf -o scratch/cfg.pdf && evince scratch/cfg.pdf

# round trip to test conversion of bril.Program to basic blocks and back.
# jq sorts keys with `-S`
# Can be used like `find bril bril/test/interp/core --exec just roundtrip`
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

# Utils

# Used for brilo, as there doesn't appear to be a way
# to print json w/out nulls.
@clean-nulls *args="":
    jq {{args}} 'del(..|nulls)'

