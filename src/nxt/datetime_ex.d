module nxt.datetime_ex;

@safe:

/** UTC Offset.
    See_Also: https://en.wikipedia.org/wiki/List_of_UTC_time_offsets
    See_Also: http://forum.dlang.org/post/csurwdcdyfocrotojons@forum.dlang.org
*/
@safe struct UTCOffset
{
    enum minHour = -12, maxHour = +14;
    enum minMinute = 0, maxMinute = 45;

    static immutable hourNames = [`-12`, `-11`, `-10`, `-09`, `-08`, `-07`, `-06`, `-05`, `-04`, `-03`, `-02`, `-01`,
                                  `±00`,
                                  `+01`, `+02`, `+03`, `+04`, `+05`, `+06`, `+07`, `+08`, `+09`, `+10`, `+11`, `+12`,
                                  `+13`, `+14`];

    static immutable quarterNames = ["00", "15", "30", "45"];

    @property void toString(scope void delegate(scope const(char)[]) sink) const @trusted
    {
        if (isDefined)
        {
            // tag prefix
            sink(`UTC`);

            sink(hourNames[_hour + 12]);

            sink(`:`);

            // minute
            immutable minute = quarterNames[_quarter];
            sink(minute);
        }
        else
            sink("<Uninitialized UTCOffset>");
    }

    @property string toString() const @trusted pure
    {
        import nxt.assuming : assumePure;
        return assumePure(&toStringUnpure)(); // TODO: can we avoid this?
    }

    string toStringUnpure() const
    {
        import std.conv : to;
        return to!string(this);
    }

    pure:

    this(scope const(char)[] code, bool strictFormat = false)
    {
        import std.conv : to;

        import nxt.skip_ex : skipOverEither;
        import nxt.array_algorithm : startsWith, skipOver;

        // TODO: support and use CT-arguments in skipOverEither()
        if (strictFormat && !code.startsWith("UTC"))
        {
            this(0, 0);
            _initializedFlag = false;
        }
        else
        {
            code.skipOverEither("UTC", "GMT");

            code.skipOver(" ");
            code.skipOverEither("+", "±", `\u00B1`, "\u00B1");
            // try in order of probability
            immutable sign = code.skipOverEither(`-`,
                                                 "\u2212", "\u2011", "\u2013", // quoting
                                                 `\u2212`, `\u2011`, `\u2013`,  // UTF-8
                                                 `&minus;`, `&dash;`, `&ndash;`) ? -1 : +1; // HTML
            code.skipOver(" ");

            import std.algorithm.comparison : among;

            if (code.length == 4 && code[1].among!(':', '.')) // H:MM
            {
                immutable hour = sign*(code[0 .. 1].to!byte);
                this(cast(byte)hour,
                     code[2 .. $].to!ubyte);
            }
            else if (code.length == 5 && code[2].among!(':', '.')) // HH:MM
            {
                immutable hour = sign*(code[0 .. 2].to!byte);
                this(cast(byte)hour,
                     code[3 .. $].to!ubyte);
            }
            else
            {
                try
                {
                    immutable hour = sign*code.to!byte;
                    this(cast(byte)hour, 0);
                }
                catch (Exception E)
                    _initializedFlag = false;
            }
        }

    }

    nothrow:

    this(byte hour, ubyte minute)
    {
        if (hour >= minHour &&
            hour <= maxHour &&
            minute >= minMinute &&
            minute <= maxMinute)
        {
            _hour = hour;
            _initializedFlag = true;
            switch (minute)
            {
            case 0: _quarter = 0; break;
            case 15: _quarter = 1; break;
            case 30: _quarter = 2; break;
            case 45: _quarter = 3; break;
            default: _initializedFlag = false; break;
            }
        }
        else
        {
            _hour = 0;
            _quarter = 0;
            _initializedFlag = false;
        }
    }

    /// Cast to `bool`, meaning 'true' if defined, `false` otherwise.
    bool opCast(U : bool)() const
    {
        version(D_Coverage) {} else pragma(inline, true);
        return isDefined();
    }

    int opCmp(in typeof(this) that) const @trusted
    {
        version(D_Coverage) {} else pragma(inline, true);
        immutable a = *cast(ubyte*)&this;
        immutable b = *cast(ubyte*)&that;
        return a < b ? -1 : a > b ? 1 : 0;
    }

    @property auto hour()      const { return _hour; }
    @property auto minute()    const { return _quarter * 15; }
    @property bool isDefined() const { return _initializedFlag; }

private:
    import std.bitmanip : bitfields;
    mixin(bitfields!(byte, "_hour", 5, // Hours: [-12 up to +14]
                     ubyte, "_quarter", 2, // Minutes in Groups of 15: 0, 15, 30, 45
                     bool, "_initializedFlag", 1));
}

@safe pure // nothrow
unittest
{
    static assert(UTCOffset.sizeof == 1); // assert packet storage

    assert(UTCOffset(-12, 0));

    assert(UTCOffset(-12, 0) !=
           UTCOffset(  0, 0));

    assert(UTCOffset(-12, 0) ==
           UTCOffset(-12, 0));

    assert(UTCOffset(-12, 0) <
           UTCOffset(-11, 0));

    assert(UTCOffset(-11, 0) <=
           UTCOffset(-11, 0));

    assert(UTCOffset(-11, 0) <=
           UTCOffset(-11, 15));

    assert(UTCOffset(-12, 0) <
           UTCOffset(+14, 15));

    assert(UTCOffset(+14, 15) <=
           UTCOffset(+14, 15));

    assert(UTCOffset(-12, 0).hour == -12);
    assert(UTCOffset(+14, 0).hour == +14);

    assert(UTCOffset("").toString == "<Uninitialized UTCOffset>");
    assert(UTCOffset(UTCOffset.minHour - 1, 0).toString == "<Uninitialized UTCOffset>");
    assert(UTCOffset(UTCOffset.maxHour + 1, 0).toString == "<Uninitialized UTCOffset>");
    assert(UTCOffset(UTCOffset.minHour, 1).toString == "<Uninitialized UTCOffset>");
    assert(UTCOffset(UTCOffset.minHour, 46).toString == "<Uninitialized UTCOffset>");

    assert(UTCOffset(-12,  0).toString == "UTC-12:00");
    assert(UTCOffset(-11,  0).toString == "UTC-11:00");
    assert(UTCOffset(-10,  0).toString == "UTC-10:00");
    assert(UTCOffset(- 9,  0).toString == "UTC-09:00");
    assert(UTCOffset(- 8,  0).toString == "UTC-08:00");
    assert(UTCOffset(- 7,  0).toString == "UTC-07:00");
    assert(UTCOffset(- 6,  0).toString == "UTC-06:00");
    assert(UTCOffset(- 5,  0).toString == "UTC-05:00");
    assert(UTCOffset(- 4,  0).toString == "UTC-04:00");
    assert(UTCOffset(- 3,  0).toString == "UTC-03:00");
    assert(UTCOffset(- 2,  0).toString == "UTC-02:00");
    assert(UTCOffset(- 1,  0).toString == "UTC-01:00");
    assert(UTCOffset(+ 0,  0).toString == "UTC±00:00");
    assert(UTCOffset(+ 1,  0).toString == "UTC+01:00");
    assert(UTCOffset(+ 2,  0).toString == "UTC+02:00");
    assert(UTCOffset(+ 3,  0).toString == "UTC+03:00");
    assert(UTCOffset(+ 4,  0).toString == "UTC+04:00");
    assert(UTCOffset(+ 5,  0).toString == "UTC+05:00");
    assert(UTCOffset(+ 6,  0).toString == "UTC+06:00");
    assert(UTCOffset(+ 7,  0).toString == "UTC+07:00");
    assert(UTCOffset(+ 8, 15).toString == "UTC+08:15");
    assert(UTCOffset(+ 9, 15).toString == "UTC+09:15");
    assert(UTCOffset(+10, 15).toString == "UTC+10:15");
    assert(UTCOffset(+11, 15).toString == "UTC+11:15");
    assert(UTCOffset(+12, 15).toString == "UTC+12:15");
    assert(UTCOffset(+13, 15).toString == "UTC+13:15");
    assert(UTCOffset(+14,  0).toString == "UTC+14:00");

    import std.conv : to;
    // assert(UTCOffset(+14, 0).to!string == "UTC+14:00");

    assert(UTCOffset("-1"));
    assert(UTCOffset(-12, 0) == UTCOffset("-12"));
    assert(UTCOffset(-12, 0) == UTCOffset("\u221212"));
    assert(UTCOffset(+14, 0) == UTCOffset("+14"));

    assert(UTCOffset(+14, 0) == UTCOffset("UTC+14"));

    assert(UTCOffset(+03, 30) == UTCOffset("+3:30"));
    assert(UTCOffset(+03, 30) == UTCOffset("+03:30"));
    assert(UTCOffset(+14, 00) == UTCOffset("UTC+14:00"));

    assert(UTCOffset(+14, 00) == "UTC+14:00".to!UTCOffset);

    assert(!UTCOffset("+14:00", true)); // strict faiure
    assert(UTCOffset("UTC+14:00", true)); // strict pass
}

/** Year and Month.

    If month is specified we probably aren't interested in years before 0 so
    store only years 0 .. 2^12-1 (4095). This makes this struct fit in 2 bytes.
 */
@safe struct YearMonth
{
    import std.datetime : Month;

    import std.bitmanip : bitfields;
    mixin(bitfields!(ushort, "year", 12,
                     Month, "month", 4));

    pragma(inline) this(int year, Month month) pure nothrow @nogc
    {
        assert(0 <= year && year <= 2^^12 - 1); // assert within range
        this.year = cast(ushort)year;
        this.month = month;
    }

    /// No explicit destruction needed.
    ~this() pure nothrow @nogc {} // needed for @nogc use

    pure:

    this(scope const(char)[] s)
    {
        import std.algorithm.searching : findSplit;
        auto parts = s.findSplit(` `); // TODO: s.findSplitAtElement(' ')
        if (parts &&
            parts[0].length >= 3) // at least three letters in month
        {
            import std.conv : to;

            // decode month
            import core.internal.traits : Unqual;
            Unqual!(typeof(s[0])[3]) tmp = parts[0][0 .. 3]; // TODO: functionize to parts[0].staticSubArray!(0, 3)
            import std.ascii : toLower;
            tmp[0] = tmp[0].toLower;
            month = tmp.to!Month;

            // decode year
            year = parts[2].to!(typeof(year));

            return;
        }

        import std.conv;
        throw new std.conv.ConvException("Couldn't decode year and month from string");
    }

    @property string toString() const
    {
        import std.conv : to;
        return year.to!string ~ `-` ~ (cast(ubyte)month).to!string; // TODO: avoid GC allocation
    }

    hash_t toHash() const @trusted nothrow @nogc
    {
        alias ThisUnsigned = short;
        assert(this.sizeof == ThisUnsigned.sizeof);
        return *((cast(ThisUnsigned*)&this));
    }

pragma(inline):

    int opCmp(in typeof(this) that) const nothrow @nogc
    {
        if (this.year < that.year)
            return -1;
        else if (this.year > that.year)
            return +1;
        else
        {
            if (this.month < that.month)
                return -1;
            else if (this.month > that.month)
                return +1;
            else
                return 0;
        }
    }
}

@safe pure /*TODO: @nogc*/ unittest
{
    import std.datetime : Month;
    Month month;

    static assert(YearMonth.sizeof == 2); // assert packed storage

    const a = YearMonth(`April 2016`);

    assert(a != YearMonth.init);

    assert(a == YearMonth(2016, Month.apr));
    assert(a != YearMonth(2016, Month.may));
    assert(a != YearMonth(2015, Month.apr));

    assert(a.year == 2016);
    assert(a.month == Month.apr);

    assert(YearMonth(`April 1900`) == YearMonth(1900, Month.apr));
    assert(YearMonth(`april 1900`) == YearMonth(1900, Month.apr));
    assert(YearMonth(`apr 1900`) == YearMonth(1900, Month.apr));
    assert(YearMonth(`Apr 1900`) == YearMonth(1900, Month.apr));

    assert(YearMonth(`Apr 1900`) != YearMonth(1901, Month.apr));
    assert(YearMonth(`Apr 1900`) < YearMonth(1901, Month.apr));
    assert(YearMonth(`Apr 1901`) > YearMonth(1900, Month.apr));

    assert(YearMonth(`Apr 1900`) < YearMonth(1901, Month.may));

    assert(YearMonth(`Apr 1900`) < YearMonth(1901, Month.may));
    assert(YearMonth(`May 1900`) < YearMonth(1901, Month.apr));
}
