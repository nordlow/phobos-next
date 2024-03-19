module nxt.aggregate_layout;

// version = show;

@safe:

void printLayout(T)() if (is(T == struct) || is(T == class) || is(T == union)) {
	import std.stdio : writefln;
	import std.string;

	writefln("=== Memory layout of '%s'" ~
			 " (.sizeof: %s, .alignof: %s) ===",
			 T.stringof, T.sizeof, T.alignof);

	/* Prints a single line of layout information. */
	void printLine(size_t offset, string info) {
		writefln("%4s: %s", offset, info);
	}

	/* Prints padding information if padding is actually
	 * observed. */
	void maybePrintPaddingInfo(size_t expectedOffset,
							   size_t actualOffset) {
		if (expectedOffset < actualOffset) {
			/* There is some padding because the actual offset
			 * is beyond the expected one. */

			const paddingSize = actualOffset - expectedOffset;

			printLine(expectedOffset,
					  format("... %s-byte PADDING",
							 paddingSize));
		}
	}

	/* This is the expected offset of the next member if there
	 * were no padding bytes before that member. */
	size_t noPaddingOffset = 0;

	/* Note: __traits(allMembers) is a 'string' collection of
	 * names of the members of a type. */
	foreach (memberName; __traits(allMembers, T)) {
		mixin (format("alias member = %s.%s;",
					  T.stringof, memberName));

		const offset = member.offsetof;
		maybePrintPaddingInfo(noPaddingOffset, offset);

		const typeName = typeof(member).stringof;
		printLine(offset,
				  format("%s %s", typeName, memberName));

		noPaddingOffset = offset + member.sizeof;
	}

	maybePrintPaddingInfo(noPaddingOffset, T.sizeof);
}

//
version (show) @safe unittest {
	struct S {
		int i;				  // 4 bytes
		short s;				// 2 byte
		bool b;				 // 1 byte
	}
	static assert(S.sizeof == 8);
	static assert(S.alignof == 4);
	align(4) struct T {
		align(4) S s;
		align(1) char c;
	}
	static assert(T.alignof == 4);
	/+ TODO: static assert(T.sizeof == 8); +/
	printLayout!(T)();
}

// https://forum.dlang.org/post/jzrztbyzgxlkplslcoaj@forum.dlang.org
pure @safe unittest {
	struct S {
		int i;				  // 4 bytes
		short s;				// 2 byte
		bool b;				 // 1 byte
	}
	static assert(S.sizeof == 8);
	static assert(S.alignof == 4);

	struct T {
		union {
			S s;
			struct {
				align(1):
				ubyte[7] _ignore_me;
				char c;
			}
		}
	}

	static assert(T.alignof == 4);
	static assert(T.sizeof == 8);
	static assert(T.c.offsetof == 7);
}
