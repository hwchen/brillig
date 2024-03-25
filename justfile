@run *args="":
    zig build && ./zig-out/bin/bril-zig {{args}}

@run-with bril-file *args="":
    cat {{bril-file}} | bril2json | just run {{args}}

@test *args="":
    zig build && turnt {{args}} test/**/*.bril

@graphviz bril-file:
    just run-with {{bril-file}} --graphviz | dot -Tpdf -o scratch/cfg.pdf && evince scratch/cfg.pdf

# round trip to test conversion of bril.Program to basic blocks and back.
# jq sorts keys with `-S`
# Can be used like `find bril bril/test/interp/core --exec just roundtrip`
# TODO put this into test suite
@roundtrip bril-file:
    diff <(just run-with {{bril-file}} --unoptimized | jq -S) <(cat {{bril-file}} | bril2json)
