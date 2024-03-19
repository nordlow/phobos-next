# Inlined AliasThisTypeOf benchmark

This benchmark shows the significant difference in time and space in failing
path for `BooleanTypeOf` compared to `BooleanTypeOf2` that has its call to
`AliasThisTypeOf` inlined.

To benchmark run

    ./test

.
