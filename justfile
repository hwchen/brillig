run:
    zig build && ./zig-out/bin/bril-zig

run-with bril-file:
    cat {{bril-file}} | bril2json | just run

test:
    zig test
