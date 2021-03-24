import std.stdio;

@safe unittest
{
    enum KiB = 2UL^^10;    ///< Kibibyte
    enum MiB = 2UL^^20;    ///< Mebibyte
    enum GiB = 2UL^^30;    ///< Gibibyte
    enum TiB = 2UL^^40;    ///< Tebibyte
    enum PiB = 2UL^^50;    ///< Pebibyte
    enum EiB = 2UL^^60;    ///< Exbibyte
    enum ZiB = 2UL^^70;    ///< Zebibyte
    enum YiB = 2UL^^80;    ///< Yobibyte
    const n = TiB;
    writeln("n:", n);
    // auto x = new int[TiB];
    // writeln(x.length);
}
