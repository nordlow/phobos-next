/// High-level wrappers for C-conversion functions.
module nxt.cconv;

/// Returns: `value` as a `string`.
void toStringInSink(const double value,
					scope void delegate(scope const(char)[]) @safe sink,
					in uint digitCount = 5)
	@trusted
{
	static immutable digitCountMax = 61;
	assert(digitCount < digitCountMax);
	char[3 + digitCountMax] buffer; // (sign + dot + null) and digits
	gcvt(value, digitCount, buffer.ptr);
	import core.stdc.string : cstrlen = strlen;
	sink(buffer[0 .. cstrlen(buffer.ptr)]); /+ TODO: avoid +/
}

/// Returns: `value` as a `string`.
string toString(const double value,
				in uint digitCount = 30)
	@trusted pure nothrow
{
	immutable length = 3 + digitCount; // (sign + dot + null) and digits
	auto buffer = new char[length];
	gcvt(value, digitCount, buffer.ptr);
	import core.stdc.string : cstrlen = strlen;
	return buffer[0 .. cstrlen(buffer.ptr)]; /+ TODO: avoid +/
}

///
pure nothrow @safe unittest {
	assert(0.0.toString(1) == `0`);
	assert(0.1.toString(2) == `0.1`);

	assert((-1.0).toString(1) == `-1`);
	assert((-1.0).toString(2) == `-1`);
	assert((-1.0).toString(3) == `-1`);

	assert(3.14.toString(3) == `3.14`);
	assert(3.141.toString(1) == `3`);
	assert(3.141.toString(2) == `3.1`);
	assert(3.141.toString(3) == `3.14`);
	assert(3.141.toString(4) == `3.141`);
	assert(3.141.toString(5) == `3.141`);

	assert(1234567.123456789123456789.toString(7) == `1234567`);
	assert(1234567.123456789123456789.toString(8) == `1234567.1`);
	assert(1234567.123456789123456789.toString(9) == `1234567.12`);
	assert(1234567.123456789123456789.toString(20) == `1234567.1234567892`);
}

private extern(C) pragma(inline, false) {
	pure nothrow @nogc:
	char *gcvt(double number, int ndigit, char *buf);
}
