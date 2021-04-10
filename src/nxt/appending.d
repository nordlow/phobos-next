module nxt.appending;

/** Append arguments $(args) to `data`.
 *
 * See_Also: http://forum.dlang.org/thread/mevnosveagdiswkxtbrv@forum.dlang.org?page=1
 */
ref R append(R, Args...)(ref R data,
                         auto ref Args args)
if (args.length != 0)
{
    import std.range.primitives : ElementType, isRandomAccessRange;

    alias E = ElementType!R;

    import std.traits : isAssignable;
    enum isElementType(U) = isAssignable!(E, U);

    import std.meta : allSatisfy;

    static if (args.length == 1)
    {
        data ~= args[0];
    }
    else static if (isRandomAccessRange!R && // TODO: generalize to is(typeof(data.length += 0))
                    allSatisfy!(isElementType, Args))
    {
        data.length += args.length;
        foreach (i, arg; args)
            data[$ - args.length + i] = arg;
    }
    else                        // TODO: only when all `args' has length
    {
        static size_t estimateLength(Args args)
        {
            import std.traits : isArray;
            import std.range.primitives : hasLength;
            size_t result;
            foreach (arg; args)
            {
                alias Arg = typeof(arg);
                static if (isArray!Arg && // TODO: generalize to hasIndexing
                           is(E == ElementType!Arg) &&
                           hasLength!Arg)
                    result += arg.length;
                else
                    result += 1;
            }
            return result;
        }

        // TODO: add case for when data += length

        import std.range: appender;
        auto app = appender!(R)(data);

        app.reserve(data.length + estimateLength(args));

        foreach (arg; args)
            app.put(arg);

        data = app.data;
    }

    return data;
}

///
@safe pure nothrow unittest
{
    int[] data;
    import std.range: only, iota;

    data.append(-1, 0, only(1, 2, 3), iota(4, 9));
    assert(data == [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8]);

    data.append(9, 10);
    assert(data == [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

    data.append([11, 12], [13, 14]);
    assert(data == [-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]);

    // int[3] d;
    // data.append(d, d);

    static assert(!__traits(compiles, { data.append(); }));
}
