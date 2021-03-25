import std.stdio, std.conv, std.random;
import core.time : Duration;
import std.datetime.stopwatch : StopWatch;

Duration lookup(in uint[uint] m, in uint[] b) @safe
{
    ulong tot = 0;

    StopWatch sw;
    sw.start;
    foreach (immutable bi; b)
    {
        const ptr = bi in m;
        if (ptr != null)
            tot += *ptr;
    }
    sw.stop;

    return sw.peek;
}

void randomizeInput(RNG)(uint[] a,
                         uint[] b,
                         in double p,
                         ref RNG rng) @safe pure
{
    foreach (ref ai; a)
        ai = uniform!"[]"(0, uint.max, rng);
    foreach (ref bi; b)
        bi = ((uniform01(rng) <= p) ?
              a[uniform(0, $, rng)] :
              uniform!"[]"(0, uint.max, rng));
}

int main(const scope string[] args)
{
    if (args.length != 4)
    {
        writeln("Usage: benchmark <size> <requests>
<measurements> <hit probability>");
        return 1;
    }

    immutable n = args[1].to!uint;
    immutable r = args[2].to!uint;
    immutable k = args[3].to!uint;
    immutable p = args[4].to!double;

    auto rng = Xorshift(0);
    auto a = new uint[n];
    auto b = new uint[r];
    Duration t;

    foreach (immutable _; 0 .. k)
    {
        uint[uint] m;
        randomizeInput(a, b, p, rng);
        foreach (immutable i, immutable ai; a)
            m[ai] = cast(typeof(n))i;

        t += lookup(m, b);
        m.destroy; // previously .clear
    }

    writefln("%.2f MOPS\n", double(r.msecs) * k / t);
    return 0;
}
