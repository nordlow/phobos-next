module nxt.geodetic;

import std.traits : isFloatingPoint, isSomeString;

/** WGS84 coordinate.
	See_Also: https://en.wikipedia.org/wiki/World_Geodetic_System
   */
struct WGS84Coordinate(T = double)
if (isFloatingPoint!T)
{
	@safe: /+ TODO: nothrow @nogc +/

	/// Construct from `latitude` and `longitude`.
	this(T latitude,
		 T longitude)
		pure nothrow @nogc
	{
		this.latitude = latitude;
		this.longitude = longitude;
	}

	/// Construct from string `s` and separator `separator`.
	this(scope const(char)[] s,
		 scope string separator = ` `)
	{
		import nxt.algorithm.searching : findSplit;
		if (auto parts = s.findSplit(separator))
		{
			import std.conv : to;
			this(parts.pre.to!T,
				 parts.post.to!T);
		}
		else
		{
			this(T.nan, T.nan);
		}
	}

	/// Convert to `string`.
	auto toString(scope void delegate(scope const(char)[]) @safe sink) const @safe
	{
		import std.format : formattedWrite;
		sink.formattedWrite!(`%f° N %f° W`)(latitude, longitude);
	}

	T latitude;
	T longitude;
}

auto wgs84Coordinate(T)(T latitude,
						T longitude)
if (isFloatingPoint!T)
	=> WGS84Coordinate!T(latitude, longitude);

auto wgs84Coordinate(T = double, S, Separator)(S s, Separator separator = ` `)
if (isSomeString!S &&
		isSomeString!Separator)
	=> WGS84Coordinate!T(s, separator);

@safe unittest {
	alias T = float;

	T latitude = 1.5;
	T longitude = 2.5;

	import std.conv : to;
	assert(wgs84Coordinate(latitude, longitude) ==
		   wgs84Coordinate!T(`1.5 2.5`));

	auto x = wgs84Coordinate(`36.7,3.216666666666667`, `,`);
	assert(x.to!string == `36.700000° N 3.216667° W`);
}
