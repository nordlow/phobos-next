module nxt.fast_appender;

/++ Faster alternative to `std.array.Appender`.
 +/
struct FastAppender(T) if (is(T == U[], U)) {
	this(this) @disable;
	T data;
	const(T) opSlice() const => data[];
}

@safe pure unittest {
	alias T = FastAppender!(void*[]);
	auto a = T();
}
