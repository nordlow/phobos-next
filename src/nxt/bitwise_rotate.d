module nxt.bitwise_rotate;

/** Rotate `x` left by `n` bits.
 *
 * Should compile to a single CPU instruction (ROL).
 *
 * TODO: `core.bitop.rol` instead.
 */
ulong rotateLeft(const scope ulong x,
                 const scope uint n) @safe pure nothrow @nogc
{
    version(D_Coverage) {} else pragma(inline, true);
    return (x << n) | (x >> (8*typeof(x).sizeof - n));
}

///
@safe pure nothrow @nogc unittest
{
    assert(rotateLeft(ulong.max, 1) == ulong.max);
    assert(rotateLeft(1UL, 1) == 2);
    assert(rotateLeft(2UL, 2) == 8);
    assert(rotateLeft(3UL, 3) == 24);
    assert(rotateLeft(2UL^^63, 1) == 1);
}

/** Rotate `x` right by `n` bits.
 *
 * Should compile to a single CPU instruction (ROR).
 *
 * TODO: `core.bitop.ror` instead.
 */
ulong rotateRight(const scope ulong x,
                  const scope uint n) @safe pure nothrow @nogc
{
    version(D_Coverage) {} else pragma(inline, true);
    return (x >> n) | (x << (8*typeof(x).sizeof - n));
}

///
@safe pure nothrow @nogc unittest
{
    assert(rotateRight(ulong.max, 1) == ulong.max);
    assert(rotateRight(1UL, 1) == 2UL^^63);
}
