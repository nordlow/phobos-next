/** Colors.
 *
 * See_Also: https://github.com/TurkeyMan/color
 */
module nxt.color;

pure nothrow @safe @nogc:

/** RGB 24-bit color, where each color component has 8-bit precision.
 *
 * See_Also: Implements the $(LINK2 https://en.wikipedia.org/wiki/RGB_color_space, RGB) _color type.
 */
struct ColorRGB8 {
	this(ubyte redC, ubyte greenC, ubyte blueC) {
		this.redC = redC;
		this.greenC = greenC;
		this.blueC = blueC;
	}

	ubyte redC; ///< Red component.
	ubyte greenC; ///< Green component.
	ubyte blueC; ///< Blue component.

	static immutable black = typeof(this)(0x00, 0x00, 0x00); ///< Black.
	static immutable white = typeof(this)(0xff, 0xff, 0xff); ///< White.
	static immutable red = typeof(this)(0xff, 0x00, 0x00); ///< Red.
	static immutable green = typeof(this)(0x00, 0xff, 0x00); ///< Green.
	static immutable blue = typeof(this)(0x00, 0x00, 0xff); ///< Blue.
	static immutable cyan = typeof(this)(0x00, 0xff, 0xff); ///< Cyan.
	static immutable magenta = typeof(this)(0xff, 0x00, 0xff); ///< Magenta.
	static immutable yellow = typeof(this)(0xff, 0xff, 0x00); ///< Yellow.
}

/** Default color format.
 */
alias Color = ColorRGB8;

/** BGR 24-bit color, where each color component has 8-bit precision.
 */
struct ColorBGR8 {
	this(ubyte redC, ubyte greenC, ubyte blueC) {
		this.redC = redC;
		this.greenC = greenC;
		this.blueC = blueC;
	}

	ubyte blueC; ///< Blue component.
	ubyte greenC; ///< Green component.
	ubyte redC; ///< Red component.
}
