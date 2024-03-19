import std.range : iota;
import std.algorithm.iteration : sum;

uint naiveSum(in uint n) => iota(1, n+1).sum;
uint smartSum(in uint n) => (n*(1+n))/2;

static assert(naiveSum(10) == smartSum(10));
static assert(naiveSum(11) == smartSum(11));
