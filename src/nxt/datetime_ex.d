module nxt.datetime_ex;

@safe:

/** UTC Offset.
	See_Also: https://en.wikipedia.org/wiki/List_of_UTC_time_offsets
	See_Also: http://forum.dlang.org/post/csurwdcdyfocrotojons@forum.dlang.org
*/
@safe struct UTCOffset
{
	import nxt.assuming : assumePure;
	import std.conv : to;

	enum hourMin = -12;
	enum hourMax = +14;
	enum minuteMin = 0;
	enum minuteMax = 45;

	static immutable hourNames = [`-12`, `-11`, `-10`, `-09`, `-08`, `-07`, `-06`, `-05`, `-04`, `-03`, `-02`, `-01`,
								  `±00`,
								  `+01`, `+02`, `+03`, `+04`, `+05`, `+06`, `+07`, `+08`, `+09`, `+10`, `+11`, `+12`,
								  `+13`, `+14`];

	static immutable quarterNames = ["00", "15", "30", "45"];

	void toString(Sink)(ref scope Sink sink) const @trusted
	{
		if (isDefined) {
			// tag prefix
			sink(`UTC`);

			sink(hourNames[this.hour0]);

			sink(`:`);

			// minute
			immutable minute = quarterNames[this.quarter];
			sink(minute);
		}
		else
			sink("<Uninitialized UTCOffset>");
	}

	string toString() const @trusted pure => assumePure(&toStringUnpure)(); /+ TODO: can we avoid this? +/

	string toStringUnpure() const => to!string(this);

	pure:

	this(scope const(char)[] code, bool strictFormat = false) {
		import std.conv : to;

		import nxt.skip_ex : skipOverAmong;
		import nxt.algorithm.searching : startsWith, skipOver;

		/+ TODO: support and use CT-arguments in skipOverAmong() +/
		if (strictFormat && !code.startsWith("UTC")) {
			this(0, 0);
			this.isDefined = false;
		}
		else
		{
			code.skipOverAmong("UTC", "GMT");

			code.skipOver(" ");
			code.skipOverAmong("+", "±", `\u00B1`, "\u00B1");
			// try in order of probability
			immutable sign = code.skipOverAmong(`-`,
												 "\u2212", "\u2011", "\u2013", // quoting
												 `\u2212`, `\u2011`, `\u2013`,  // UTF-8
												 `&minus;`, `&dash;`, `&ndash;`) ? -1 : +1; // HTML
			code.skipOver(" ");

			if (code.length == 4 &&
				(code[1] == ':' ||
				 code[1] == '.')) // H:MM
			{
				immutable hour = sign*(code[0 .. 1].to!byte);
				this(cast(byte)hour, code[2 .. $].to!ubyte);
			}
			else if (code.length == 5 &&
					 (code[2] == ':' ||
					  code[2] == '.')) // HH:MM
			{
				immutable hour = sign*(code[0 .. 2].to!byte);
				this(cast(byte)hour, code[3 .. $].to!ubyte);
			}
			else
			{
				try
				{
					immutable hour = sign*code.to!byte;
					this(cast(byte)hour, 0);
				}
				catch (Exception E)
					this.isDefined = false;
			}
		}

	}

	nothrow:

	this(byte hour, ubyte minute) {
		if (hour >= hourMin &&
			hour <= hourMax &&
			minute >= minuteMin &&
			minute <= minuteMax) {
			this.hour = hour;
			this.isDefined = true;
			switch (minute) {
			case 0: this.quarter = 0; break;
			case 15: this.quarter = 1; break;
			case 30: this.quarter = 2; break;
			case 45: this.quarter = 3; break;
			default: this.isDefined = false; break;
			}
		}
		else
		{
			this.hour = 0;
			this.quarter = 0;
			this.isDefined = false;
		}
	}

	/// Cast to `bool`, meaning 'true' if defined, `false` otherwise.
	bool opCast(U : bool)() const => isDefined;

	int opCmp(in typeof(this) that) const @trusted
	{
		immutable a = *cast(ubyte*)&this;
		immutable b = *cast(ubyte*)&that;
		return a < b ? -1 : a > b ? 1 : 0;
	}

	@property byte hour0()	 const { return ((_data >> 0) & 0b_11111); }
	@property byte hour()	  const { return ((_data >> 0) & 0b_11111) - 12; }
	@property ubyte quarter()  const { return ((_data >> 5) & 0b_11); }
	@property ubyte minute()   const { return ((_data >> 5) & 0b_11) * 15; }
	@property bool isDefined() const { return ((_data >> 7) & 0b_1) != 0; }

	private @property hour(byte x) in(-12 <= x) in(x <= 14)
		=> _data |= ((x + 12) & 0b_11111);

	private @property quarter(ubyte x) in(0 <= x) in(x <= 3)
		=> _data |= ((x & 0b_11) << 5);

	private @property isDefined(bool x) {
		if (x)
			_data |= (1 << 7);
		else
			_data &= ~(1 << 7);
	}

	private ubyte _data; /+ TODO: use builtin bitfields when they become available in dmd +/
}

@safe pure // nothrow
unittest {
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
	assert(UTCOffset(UTCOffset.hourMin - 1, 0).toString == "<Uninitialized UTCOffset>");
	assert(UTCOffset(UTCOffset.hourMax + 1, 0).toString == "<Uninitialized UTCOffset>");
	assert(UTCOffset(UTCOffset.hourMin, 1).toString == "<Uninitialized UTCOffset>");
	assert(UTCOffset(UTCOffset.hourMin, 46).toString == "<Uninitialized UTCOffset>");

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
	import std.conv : to;
	import std.datetime : Month;

	private enum monthBits = 4;
	private enum monthMask = (1 << monthBits) - 1;
	private enum yearBits = (8*_data.sizeof - monthBits);
	private enum yearMin = 0;
	private enum yearMax = 2^^yearBits - 1;

	pragma(inline) this(int year, Month month) pure nothrow @nogc
	{
		assert(yearMin <= year && year <= yearMax); // assert within range
		this.year = cast(ushort)year;
		this.month = month;
	}

	/// No explicit destruction needed.
	~this() pure nothrow @nogc {} // needed for @nogc use

	pure:

	this(scope const(char)[] s) {
		import nxt.algorithm.searching : findSplit;
		scope const parts = s.findSplit(' ');
		if (parts &&
			parts.pre.length >= 3) // at least three letters in month
		{
			// decode month
			import core.internal.traits : Unqual;
			Unqual!(typeof(s[0])[3]) tmp = parts.pre[0 .. 3]; /+ TODO: functionize to parts[0].staticSubArray!(0, 3) +/
			import std.ascii : toLower;
			tmp[0] = tmp[0].toLower;
			month = tmp.to!Month;

			// decode year
			year = parts.post.to!(typeof(year));

			return;
		}

		import std.conv;
		throw new std.conv.ConvException("Couldn't decode year and month from string");
	}

	@property string toString() const
		=> year.to!(typeof(return)) ~ `-` ~ (cast(ubyte)month).to!(typeof(return)); /+ TODO: avoid GC allocation +/

	alias ThisUnsigned = short;
	static assert(this.sizeof == ThisUnsigned.sizeof);

	hash_t toHash() const @trusted nothrow @nogc => *((cast(ThisUnsigned*)&this));

	private @property month(Month x) nothrow @nogc => _data |= x & monthMask;
	private @property year(ushort x) nothrow @nogc => _data |= (x << monthBits);

	@property Month month() const nothrow @nogc => cast(typeof(return))(_data & monthMask);
	@property ushort year() const nothrow @nogc => _data >> monthBits;

	private ushort _data; /+ TODO: use builtin bitfields when they become available in dmd +/

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

@safe pure /*TODO: @nogc*/ unittest {
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
