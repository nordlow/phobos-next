/** Colors. */
module nxt.color;

@safe:

/** RGB 24-bit color, where each color component has 8-bit precision. */
struct ColorRGB8 {
pure nothrow @safe @nogc:
	this(ubyte redC, ubyte greenC, ubyte blueC) {
		this.redC = redC;
		this.greenC = greenC;
		this.blueC = blueC;
	}
	static immutable black = typeof(this)(0x00, 0x00, 0x00); ///< Black.
	static immutable white = typeof(this)(0xff, 0xff, 0xff); ///< White.
	static immutable red = typeof(this)(0xff, 0x00, 0x00); ///< Red.
	static immutable green = typeof(this)(0x00, 0xff, 0x00); ///< Green.
	static immutable blue = typeof(this)(0x00, 0x00, 0xff); ///< Blue.
	static immutable cyan = typeof(this)(0x00, 0xff, 0xff); ///< Cyan.
	static immutable magenta = typeof(this)(0xff, 0x00, 0xff); ///< Magenta.
	static immutable yellow = typeof(this)(0xff, 0xff, 0x00); ///< Yellow.
	ubyte redC; ///< Red component.
	ubyte greenC; ///< Green component.
	ubyte blueC; ///< Blue component.
}

/** Default color format. */
alias Color = ColorRGB8;

@safe pure nothrow @nogc unittest {
	auto a = ColorRGB8(0,0,0);
	auto b = ColorRGB8(0,0,0);
	assert(a == b);
}

/** BGR 24-bit color, where each color component has 8-bit precision. */
struct ColorBGR8 {
pure nothrow @safe @nogc:
	this(ubyte redC, ubyte greenC, ubyte blueC) {
		this.redC = redC;
		this.greenC = greenC;
		this.blueC = blueC;
	}
	ubyte blueC; ///< Blue component.
	ubyte greenC; ///< Green component.
	ubyte redC; ///< Red component.
}

@safe pure nothrow @nogc unittest {
	auto a = ColorBGR8(0,0,0);
	auto b = ColorBGR8(0,0,0);
	assert(a == b);
}
