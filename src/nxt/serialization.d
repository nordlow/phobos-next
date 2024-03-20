/** Serialization.
 *
 * Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -d -I.. -i -debug -g -checkaction=context -allinst -unittest -main -run serialization.d
 * Test: ldmd2 -d -fsanitize=address -I.. -i -debug -g -checkaction=context -allinst -unittest -main -run serialization.d
 * Debug: ldmd2 -d -fsanitize=address -I.. -i -debug -g -checkaction=context -allinst -unittest -main serialization.d && lldb serialization
 *
 * TODO: Detect and pack consecutive bitfields using new `__traits(isBitfield, T)`
 *
 * TODO: Give compile-time error message when trying to serialize `void*` but not `void[]`
 *
 * TODO: Allocator supoprt
 *
 * TODO: Disable (de)serialization of nested types via `!__traits(isNested, T)`
 *
 * TODO: Support serialization of cycles and remove `Code.failureCycle` and `sc`.
 *
 * TODO: Use direct field setting for T only when __traits(isPOD, T) is true
         otherwise use __traits(getOverloads, T, "__ctor").
		 Try to use this to generalize (de)serialization of `std.json.JSONValue`
		 to a type-agnostic logic inside inside generic main generic `serializeRaw`
		 and `deserializeRaw`.
 *
 * TODO: Support bit-blitting of unions of only non-pointer fields.
 *
 * TODO: Only disable union's that contain any pointers.
 *       Detect using __traits, std.traits or gc_traits.d.
 *
 * TODO: Avoid call to `new` when deserializing arrays of immutable elements
 *       (and perhaps classes) when `Sink` element type `E` is immutable.
 *
 * TODO: Exercise `JSONValue` (de)serialization with `nxt.sampling`.
 *
 * TODO: Optimize (de)serialization when `__traits(hasIndirections)` is avaiable and
         `__traits(hasIndirections, T)` is false and `enablesSlicing` is set.
 */
module nxt.serialization;

import nxt.visiting : Addresses;
import nxt.dip_traits : hasPreviewBitfields;

version = serialization_json_test;

/++ Serialization format.
 +/
@safe struct Format {
	/++ Flag that integral types are packed via variable length encoding (VLE).
     +/
	bool packIntegrals = false;

	/++ Flag that scalar types are serialized in native (platform-dependent) byte-order.
		Reason for settings this is usually to gain speed.
     +/
	bool useNativeByteOrder = false;

	/++ Returns: `true` iff `this` enables array slices of a scalar type
		to be read/written without a loop, resulting in higher performance.
		+/
	@property bool enablesSlicing() const pure nothrow @nogc
		=> (!packIntegrals && useNativeByteOrder);
}

/++ Status.
	Converts to `bool true` for failures to simplify control flow in
    (de)serialization functions.
 +/
struct Status {
	/++ Status code. +/
	enum Code {
		successful = 0,
		failure = 1,
		failureCycle = 2,
	}
	Code code;
	alias code this;
	bool opCast(T : bool)() const nothrow @nogc => code != Code.successful;
}

/++ Code (unit) type.
 +/
alias CodeUnitType = ubyte;

/++ Raw (binary) serialize `arg` to `sink` in format `fmt`.
	TODO: Predict `initialAddrsCapacity` in callers.
 +/
Status serializeRaw(T, Sink)(scope ref Sink sink, in T arg, in Format fmt = Format.init, in size_t initialAddrsCapacity = 0) {
	scope Addresses addrs;
	() @trusted {
		addrs.reserve(initialAddrsCapacity); // .reserve should be @trusted here
	}();
	return serializeRaw_!(T, Sink)(sink, arg, addrs, fmt);
}

private Status serializeRaw_(T, Sink)(scope ref Sink sink, in T arg, scope ref Addresses addrs, in Format fmt = Format.init) {
	alias E = typeof(Sink.init[][0]); // code unit (element) type
	static assert(__traits(isUnsigned, E),
				   "Non-unsigned sink code unit (element) type " ~ E.stringof);
	static assert(!is(T == union),
				   "Cannot serialize union type `" ~ T.stringof ~ "`");
	static if (is(T == struct) || is(T == union) || is(T == class)) {
		Status serializeFields() {
			import std.traits : FieldNameTuple;
			foreach (fieldName; FieldNameTuple!T)
				if (const st = serializeRaw_(sink, __traits(getMember, arg, fieldName), addrs, fmt))
					return st;
			return Status(Status.Code.successful);
		}
	}
	static if (is(T : __vector(U[N]), U, size_t N)) { // must come before isArithmetic
		foreach (const ref elt; arg)
			if (const st = serializeRaw_(sink, elt, addrs, fmt)) { return st; }
    } else static if (__traits(isArithmetic, T)) {
		static if (__traits(isIntegral, T)) {
			static if (__traits(isUnsigned, T)) {
				if (fmt.packIntegrals) {
					if (arg < unsignedPrefixSentinel) {
						const tmp = cast(E)arg;
						assert(tmp != unsignedPrefixSentinel);
						sink ~= tmp; // pack in single code unit
						return Status(Status.Code.successful);
					}
					else
						sink ~= unsignedPrefixSentinel;
				}
			} else { // isSigned
				if (fmt.packIntegrals) {
					if (arg >= byte.min+1 && arg <= byte.max) {
						const tmp = cast(byte)arg; // pack in single code unit
						assert(tmp != signedPrefixSentinel);
						() @trusted { sink ~= ((cast(E*)&tmp)[0 .. 1]); }();
						return Status(Status.Code.successful);
					}
					else
						sink ~= signedPrefixSentinel; // signed prefix
				}
			}
		} else static if (__traits(isFloating, T) && is(T : real)) {
			/+ TODO: pack small values +/
		}
		static if (T.sizeof <= 8 && canSwapEndianness!(T)) {
			import std.bitmanip : nativeToBigEndian;
			if (!fmt.useNativeByteOrder) {
				sink ~= arg.nativeToBigEndian[];
				return Status(Status.Code.successful);
			}
		}
		// `T` for `T.sizeof == 1` or `T` being `real`:
		() @trusted { sink ~= ((cast(E*)&arg)[0 .. T.sizeof]); }();
    } else static if (is(T == struct) || is(T == union)) {
		static if (is(typeof(T.init[]) == U[], U)) { // hasSlicing
			if (const st = serializeRaw_(sink, arg[], addrs, fmt)) { return st; }
		} else {
			if (const st = serializeFields()) { return st; }
		}
    } else static if (is(T == class) || is(T == U*, U)) { // isAddress
        const bool isNull = arg is null;
        if (const st = serializeRaw_(sink, isNull, addrs, fmt)) { return st; }
        if (isNull)
			return Status(Status.Code.successful);
		import nxt.algorithm.searching : canFind;
		void* addr;
		() @trusted { addr = cast(void*)arg; }();
		if (addrs.canFind(addr)) {
			// dbg("Cycle detected at `" ~ T.stringof ~ "`");
			return Status(Status.Code.failureCycle);
		}
		() @trusted { addrs ~= addr; }(); // `addrs`.lifetime <= `arg`.lifetime
        static if (is(T == class)) {
			if (const st = serializeFields()) { return st; }
        } else {
			if (const st = serializeRaw_(sink, *arg, addrs, fmt)) { return st; }
        }
    } else static if (is(T U : U[])) { // isArray
		static if (!__traits(isStaticArray, T)) {
			if (const st = serializeRaw_(sink, arg.length, addrs, fmt)) { return st; }
		}
		static if (__traits(isScalar, U)) {
			if (fmt.enablesSlicing) {
				() @trusted { sink ~= ((cast(E*)arg.ptr)[0 .. arg.length*U.sizeof]); }();
				return Status(Status.Code.successful);
			}
		}
		static if (is(immutable U == immutable void)) {
			ubyte[] raw;
			() @trusted { raw = cast(typeof(raw))arg; }();
			if (const st = serializeRaw_(sink, raw, addrs, fmt)) { return st; }
		} else {
			foreach (const ref elt; arg)
				if (const st = serializeRaw_(sink, elt, addrs, fmt)) { return st; }
		}
    } else static if (__traits(isAssociativeArray, T)) {
		if (const st = serializeRaw_(sink, arg.length, addrs, fmt)) { return st; }
		foreach (const ref elt; arg.byKeyValue) {
			if (const st = serializeRaw_(sink, elt.key, addrs, fmt)) { return st; }
			if (const st = serializeRaw_(sink, elt.value, addrs, fmt)) { return st; }
		}
    } else
        static assert(0, "Cannot serialize `arg` of type `" ~ T.stringof ~ "`");
	return Status(Status.Code.successful);
}

/++ Raw (binary) deserialize `arg` from `sink` in format `fmt`.
 +/
Status deserializeRaw(T, Sink)(scope ref Sink sink, ref T arg, in Format fmt = Format.init) {
	alias E = typeof(Sink.init[][0]); // code unit (element) type
	static assert(__traits(isUnsigned, E),
				   "Non-unsigned sink code unit (element) type " ~ E.stringof);
	static assert(!is(T == union),
				   "Cannot deserialize union type `" ~ T.stringof ~ "`");
	static if (__traits(hasMember, Sink, "data") &&
			   is(immutable typeof(sink.data) == immutable E[])) {
		auto data = sink.data; // l-value to pass by ref
		const st_ = deserializeRaw!(T)(data, arg, fmt); // Appender arg => arg.data
		sink = Sink(data); /+ TODO: avoid this because it allocates +/
		return st_;
	}
	import std.traits : Unqual;
	Unqual!T* argP;
	() @trusted { argP = cast(Unqual!T*)&arg; }();
	static if (is(T == struct) || is(T == union) || is(T == class)) {
		import std.traits : FieldNameTuple;
		Status deserializeFields() {
			foreach (fieldName; FieldNameTuple!T) {
				/+ TODO: maybe use *argP here instead: +/
				if (const st = deserializeRaw(sink, __traits(getMember, arg, fieldName), fmt)) { return st; }
			}
			return Status(Status.Code.successful);
		}
	}
	static if (is(T : __vector(U[N]), U, size_t N)) { // must come before isArithmetic
		foreach (const ref elt; arg)
			if (const st = deserializeRaw(sink, elt, fmt)) { return st; }
    } else static if (__traits(isArithmetic, T)) {
		static if (__traits(isIntegral, T)) {
			if (fmt.packIntegrals) {
				auto tmp = sink.frontPop!(E)();
				static if (__traits(isUnsigned, T)) {
					if (tmp != unsignedPrefixSentinel) {
						*argP = cast(T)tmp;
						return Status(Status.Code.successful);
					}
				} else {
					if (tmp != signedPrefixSentinel) {
						() @trusted {*argP = cast(T)*cast(byte*)&tmp;}(); // reinterpret
						return Status(Status.Code.successful);
					}
				}
			}
		} else static if (__traits(isFloating, T) && is(T : real)) {
			/+ TODO: unpack small values +/
		}
		static if (T.sizeof <= 8 && canSwapEndianness!(T)) {
			if (!fmt.useNativeByteOrder) {
				*argP = sink.frontPopSwapEndian!(T)();
				return Status(Status.Code.successful);
			}
		}
		// `T` for `T.sizeof == 1` or `T` being `real`:
		*argP = sink.frontPop!(T)();
    } else static if (is(T == struct) || is(T == union)) {
		static if (is(typeof(T.init[]) == U[], U)) { // hasSlicing
			U[] tmp; // T was serialized via `T.opSlice`
			if (const st = deserializeRaw(sink, tmp, fmt)) { return st; }
			arg = T(tmp);
		} else {
			if (const st = deserializeFields()) { return st; }
		}
    } else static if (is(T == class) || is(T == U*, U)) { // isAddress
        bool isNull;
        if (const st = deserializeRaw(sink, isNull, fmt)) { return st; }
        if (isNull) {
			arg = null;
			return Status(Status.Code.successful);
		}
        static if (is(T == class)) {
			if (arg is null) {
				alias ctors = typeof(__traits(getOverloads, TestClass, "__ctor"));
				static assert(ctors.length <= 1, "Cannot deserialize `arg` of type `" ~ T.stringof ~ "` as it has multiple constructors");
				static if (ctors.length == 1) {
					import std.traits : ParameterTypeTuple;
					alias CtorParams = ParameterTypeTuple!(ctors[0]);
					CtorParams params;
					// pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", CtorParams);
					/+ TODO: Somehow deserialize `CtorParams` and pass them to constructor probably when compiler has native support for passing tuples to functions. +/
					static if (is(typeof(() @safe pure { return new T(params); }))) {
						arg = new T();
					} else {
						static assert(0, "Cannot deserialize `arg` of type `" ~ T.stringof ~ "` as it has no default constructor");
					}
    			} else {
					static if (is(typeof(() @safe pure { return new T(); }))) {
						arg = new T();
					} else {
						static assert(0, "Cannot deserialize `arg` of type `" ~ T.stringof ~ "` as it has no default constructor");
					}
				}
			}
			if (const st = deserializeFields()) { return st; }
        } else {
			if (arg is null)
				arg = new typeof(*T.init);
            if (const st = deserializeRaw(sink, *arg, fmt)) { return st; }
        }
    } else static if (is(T U : U[])) { // isArray
		static if (!__traits(isStaticArray, T)) {
			typeof(T.init.length) length;
			if (const st = deserializeRaw(sink, length, fmt)) { return st; }
			/+ TODO: avoid allocation if `E` is `immutable` and `U` is `immutable` and both have .sizeof 1: +/
			arg.length = length; // allocates. TODO: use allocator
		}
		static if (__traits(isScalar, U)) {
			if (fmt.enablesSlicing) {
				() @trusted { arg = (cast(U*)sink[].ptr)[0 .. arg.length]; }();
				sink = cast(Sink)(sink[][arg.length * U.sizeof .. $]);
				return Status(Status.Code.successful);
			}
		}
        foreach (ref elt; arg)
            if (const st = deserializeRaw(sink, elt, fmt)) { return st; }
    } else static if (__traits(isAssociativeArray, T)) {
		typeof(T.init.length) length;
		if (const st = deserializeRaw(sink, length, fmt)) { return st; }
		/+ TODO: isMap: arg.capacity = length; or arg.reserve(length); +/
		foreach (_; 0 .. length) {
			/* WARNING: `key` and `value` must not be put in outer scope as
               that will lead to keys being overwritten. */
			typeof(T.init.keys[0]) key;
			typeof(T.init.values[0]) value;
			if (const st = deserializeRaw(sink, key, fmt)) { return st; }
			if (const st = deserializeRaw(sink, value, fmt)) { return st; }
			arg[key] = value;
		}
    } else
        static assert(0, "Cannot deserialize `arg` of type `" ~ T.stringof ~ "`");
	return Status(Status.Code.successful);
}

private static immutable CodeUnitType unsignedPrefixSentinel = 0b_1111_1111;
private static immutable CodeUnitType   signedPrefixSentinel = 0b_1000_0000;

private T frontPop(T, Sink)(ref Sink sink) in(T.sizeof <= sink[].length) {
	T* ptr;
	() @trusted { ptr = (cast(T*)sink[][0 .. T.sizeof]); }();
	typeof(return) result = *ptr; /+ TODO: unaligned access +/
	sink = cast(Sink)(sink[][T.sizeof .. $]);
	return result;
}

private T frontPopSwapEndian(T, Sink)(ref Sink sink) if (T.sizeof >= 2) {
	enum sz = T.sizeof;
	import std.bitmanip : bigEndianToNative;
	typeof(return) result = sink[][0 .. sz].bigEndianToNative!(T, sz); /+ TODO: unaligned access +/
	sink = cast(Sink)(sink[][sz .. $]);
	return result;
}

/++ Is true iff `T` has swappable endianness (byte-order). +/
private enum canSwapEndianness(T) = (T.sizeof >= 2 && T.sizeof <= 8 && __traits(isArithmetic, T));

/// enum both sink type to trigger instantiation
version (none)
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			static foreach (Sink; AliasSeq!(ArraySink, AppenderSink)) {{ // trigger instantiation
				Sink sink;
				alias T = void[];
				T t = [1,2,3,4];
				assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
				// assert(sink[].length == (packIntegrals ? 1 : T.sizeof));
				// T u;
				// assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
				// assert(sink[].length == 0);
				// assert(t == u);
			}}
		}
	}
}

/// enum both sink type to trigger instantiation
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			static foreach (Sink; AliasSeq!(ArraySink, AppenderSink)) {{ // trigger instantiation
				Sink sink;
				alias T = TestEnum;
				T t;
				assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
				assert(sink[].length == (packIntegrals ? 1 : T.sizeof));
				T u;
				assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
				assert(sink[].length == 0);
				assert(t == u);
			}}
		}
	}
}

/// empty {struct|union}
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			struct S {}
			struct U {}
			static foreach (T; AliasSeq!(S, U)) {{
				T t;
				assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
				assert(sink[].length == 0);
				T u;
				assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
				assert(sink[].length == 0);
				static if (!is(T == class)) {
					assert(t == u);
				}
			}}
		}
	}
}

/// class type
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			alias T = TestClass;
			T t = new T(11,22);
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			assert(sink[].length != 0);
			if (fmt.packIntegrals)
				assert(sink[] == [0, 11, 22]);
			T u;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			assert(t.tupleof == u.tupleof);
		}
	}
}

/// cycle-struct type
version (none) /+ TODO: activate +/
@trusted unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			alias T = CycleStruct;
			T t = new T();
			t.x = 42;
			() @trusted {
				t.parent = &t;
			}();
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			assert(sink[].length != 0);
			if (fmt.packIntegrals)
				assert(sink == [0, 11, 22]);
			T u;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			assert(t.tupleof == u.tupleof);
		}
	}
}

/// cycle-class type
@trusted unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			alias T = CycleClass;
			T t = new T(42);
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.failureCycle));
			assert(sink[].length != 0);
			/+ TODO: activate when cycles are supported: +/
			// T u;
			// assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			// assert(sink[].length == 0);
			// assert(t.tupleof == u.tupleof);
		}
	}
}

/// struct with static field
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			struct T { static int _; }
			T t;
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			T u;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			assert(t == u);
		}
	}
}

/// struct with immutable field
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			struct T { immutable int _; }
			T t;
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			assert(sink[].length == (packIntegrals ? 1 : T.sizeof));
			T u;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			assert(t == u);
		}
	}
}

/// struct with bitfields
@safe pure nothrow unittest {
	static if (hasPreviewBitfields) {
		foreach (const packIntegrals; [false, true]) {
			foreach (const useNativeByteOrder; [false, true]) {
				const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
				AppenderSink sink;
				alias W = ubyte;
				struct T { W b_0_2 : 2; W b_2_6 : 6; }
				static assert(T.sizeof == W.sizeof);
				T t;
				assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
				assert(sink[].length == (packIntegrals ? 2 * W.sizeof : 2*T.sizeof));
				T u;
				assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
				assert(sink[].length == 0);
				assert(t == u);
			}
		}
	}
}

/// {char|wchar|dchar}
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			static foreach (T; CharTypes) {{
				foreach (const T t; 0 .. 127+1) {
					assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
					assert(sink[].length == (packIntegrals ? 1 : T.sizeof));
					T u;
					assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
					assert(sink[].length == 0);
					assert(t == u);
				}
			}}
		}
	}
}

/// {char|wchar|dchar}[]
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			import std.meta : AliasSeq;
			static foreach (E; CharTypes) {{
				alias T = E[];
				T t;
				assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
				assert(sink[].length != 0);
				T u;
				assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
				assert(sink[].length == 0);
				assert(t == u);
			}}
		}
	}
}

/// signed integral
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			import std.meta : AliasSeq;
			static foreach (T; AliasSeq!(byte, short, int, long)) {{
				foreach (const T t; byte.min+1 .. byte.max+1) {
					assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
					assert(sink[].length == (packIntegrals ? 1 : T.sizeof));
					T u;
					assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
					assert(sink[].length == 0);
					assert(t == u);
				}
			}}
		}
	}
}

/// core.simd vector types
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			import std.meta : AliasSeq;
			import core.simd;
			/+ TODO: support more core.simd types +/
			static foreach (T; AliasSeq!(byte16, float4, double2)) {{
				T t = 0;
				assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
				assert(sink[].length == T.sizeof);
				T u;
				assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
				assert(sink[].length == 0);
				assert(t[] == u[]);
			}}
		}
	}
}

/// unsigned integral
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			import std.meta : AliasSeq;
			static foreach (T; AliasSeq!(ubyte, ushort, uint, ulong)) {{
				foreach (const T t; 0 .. ubyte.max) {
					assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
					assert(sink[].length == (packIntegrals ? 1 : T.sizeof));
					T u;
					assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
					assert(sink[].length == 0);
					assert(t == u);
				}
			}}
		}
	}
}

/// floating point
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			import std.meta : AliasSeq;
			static foreach (T; AliasSeq!(float, double, real)) {{
				foreach (const T t; 0 .. ubyte.max) {
					assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
					assert(sink[].length == (packIntegrals ? T.sizeof : T.sizeof));
					T u;
					assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
					assert(sink[].length == 0);
					assert(t == u);
				}
			}}
		}
	}
}

/// integral pointer
@trusted pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			import std.meta : AliasSeq;
			static foreach (E; AliasSeq!(uint, ulong)) {{
				E val = 42;
				struct T { E* p1, p2; }
				T t = T(null,&val);
				assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
				assert(sink[].length != 0);
				T u;
				assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
				assert(sink[].length == 0);
				assert(t.p1 is u.p1);
				assert(*t.p2 == *u.p2);
			}}
		}
	}
}

/// static array
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			enum n = 3;
			alias T = int[n];
			T t = [11,22,33];
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			assert(sink[].length != 0);
			T u;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			assert(t == u);
		}
	}
}

/// dynamic array
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			alias T = int[];
			T t = [11,22,33];
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			assert(sink[].length == (fmt.packIntegrals ? (1 + t.length) : 20));
			T u;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);

			assert(t == u);
		}
	}
}

/// associative array
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			alias T = int[int];
			T t = [1: 1, 2: 2];
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			assert(sink[].length != 0);
			T u;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			assert(t == u);
		}
	}
}

/// associative array
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			alias T = int[string];
			T t = ["1": 3, "2": 4];
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			assert(sink[].length != 0);
			T u = T.init;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			assert(t == u);
		}
	}
}

/// empty `std.array.Appender` via slicing
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			import std.array : Appender;
			AppenderSink sink;
			alias A = int[];
			alias T = Appender!(A);
			T t = [];
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			assert(sink[].length == (fmt.packIntegrals ? 1 : 8) + t.data.length);
			T u;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			assert(t[] == u[]);
		}
	}
}

/// populated `std.array.Appender` via slicing
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			import std.array : Appender;
			AppenderSink sink;
			alias A = int[];
			alias T = Appender!(A);
			A a = [11,22,33];
			T t = a;
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			assert(sink[].length == (fmt.packIntegrals ? 4 : 20));
			AppenderSink asink;
			assert(!asink.serializeRaw(a, fmt));
			assert(asink[].length == (fmt.packIntegrals ? 4 : 20));
			assert(sink[] == asink[]);
			T u;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			assert(t[] == u[]);
		}
	}
}

/// aggregate type
@safe pure nothrow unittest {
	foreach (const packIntegrals; [false, true]) {
		foreach (const useNativeByteOrder; [false, true]) {
			const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
			AppenderSink sink;
			struct P { int x, y; int* p1, p2; char[3] ch3; char ch; wchar wc; dchar dc; int[int] aa; }
			struct T { int x, y; long l; float f; double d; real r; bool b1, b2; P p; }
			T t = T(0x01234567,0x76543210, 0x01234567_01234567, 3.14,3.14,3.14, false,true,
					P(2,3, null,null, "abc", 'a', 'b', 'c', [11:-11,-22:22,-33:-33]));
			assert(sink.serializeRaw(t, fmt) == Status(Status.Code.successful));
			T u;
			assert(sink.deserializeRaw(u, fmt) == Status(Status.Code.successful));
			assert(sink[].length == 0);
			assert(t == u);
		}
	}
}

version (serialization_json_test)
private import std.json : JSONValue, JSONType, parseJSON;

/++ Raw (binary) serialize `JSONValue arg` to `sink` in format `fmt`. +/
version (serialization_json_test)
private Status serializeRaw_(T : JSONValue, AppenderSink)(scope ref AppenderSink sink, in T arg, scope ref Addresses addrs, in Format fmt = Format.init) {
	if (const st = serializeRaw_(sink, arg.type, addrs, fmt)) { return st; }
	final switch (arg.type) {
    case JSONType.integer:
		return serializeRaw_(sink, arg.integer, addrs, fmt);
    case JSONType.uinteger:
		return serializeRaw_(sink, arg.uinteger, addrs, fmt);
    case JSONType.float_:
		return serializeRaw_(sink, arg.floating, addrs, fmt);
    case JSONType.string:
		return serializeRaw_(sink, arg.str, addrs, fmt);
    case JSONType.object:
		return serializeRaw_(sink, arg.object, addrs, fmt);
    case JSONType.array:
		return serializeRaw_(sink, arg.array, addrs, fmt);
    case JSONType.true_:
    case JSONType.false_:
    case JSONType.null_:
		return Status(Status.Code.successful);
    }
}

/++ Raw (binary) deserialize `JSONValue arg` from `sink` in format `fmt`. +/
version (serialization_json_test)
Status deserializeRaw(T : JSONValue, AppenderSink)(scope ref AppenderSink sink, ref T arg, in Format fmt = Format.init) {
	JSONType type;
	if (const st = deserializeRaw(sink, type, fmt)) { return st; }
	typeof(return) st;
	final switch (type) {
    case JSONType.integer:
		typeof(arg.integer) value;
		st = deserializeRaw(sink, value, fmt);
		if (st == Status(Status.Code.successful)) arg = JSONValue(value);
		break;
    case JSONType.uinteger:
		typeof(arg.uinteger) value;
		st = deserializeRaw(sink, value, fmt);
		if (st == Status(Status.Code.successful)) arg = JSONValue(value);
		break;
    case JSONType.float_:
		typeof(arg.floating) value;
		st = deserializeRaw(sink, value, fmt);
		if (st == Status(Status.Code.successful)) arg = JSONValue(value);
		break;
    case JSONType.string:
		typeof(arg.str) value;
		st = deserializeRaw(sink, value, fmt);
		if (st == Status(Status.Code.successful)) arg = JSONValue(value);
		break;
    case JSONType.object:
		typeof(arg.object) value;
		st = deserializeRaw(sink, value, fmt);
		if (st == Status(Status.Code.successful)) arg = JSONValue(value);
		break;
    case JSONType.array:
		typeof(arg.array) value;
		st = deserializeRaw(sink, value, fmt);
		if (st == Status(Status.Code.successful)) arg = JSONValue(value);
		break;
    case JSONType.true_:
		arg = true;
		st = Status(Status.Code.successful);
		break;
    case JSONType.false_:
		arg = false;
		st = Status(Status.Code.successful);
		break;
    case JSONType.null_:
		arg = null;
		st = Status(Status.Code.successful);
		break;
    }
	return st;
}

// { "optional": true }
version (serialization_json_test)
@trusted unittest {
	foreach (const s; [`false`,
					   `true`,
					   `null`,
					   `{}`,
					   `12`,
					   `"x"`,
					   `[1,2]`,
					   `[1,2,[3,4,5,"x","y"],"a",null]`,
					   `[1,3.14,"x",null]`,
					   `{ "optional":false }`,
					   `{ "optional":true }`,
					   `{ "optional":null }`,
					   `{ "a":"a", }`,
					   `{ "a":"a", "a":"a", }`,
					   `{ "a":1, "a":2, }`,
					   `{  "":1,  "":2, }`,
					   `{  "":1, "b":2, }`,
					   `{ "a":1,  "":2, }`,
					   `{ "a":1, "b":2, }`,
					   /+ TODO: this fails: readLargeFile, +/
	]) {
		foreach (const packIntegrals; [false, true]) {
			foreach (const useNativeByteOrder; [false, true]) {
				const fmt = Format(packIntegrals: packIntegrals, useNativeByteOrder: useNativeByteOrder);
				AppenderSink sink;
				alias T = JSONValue;
				const T t = s.parseJSON();
				assert(sink.serializeRaw!(JSONValue)(t, fmt) == Status(Status.Code.successful));
				assert(sink[].length != 0);
				T u;
				assert(sink.deserializeRaw!(JSONValue)(u, fmt) == Status(Status.Code.successful));
				assert(sink[].length == 0);
				assert(t == u);
			}
		}
	}
}

version (none)
version (serialization_json_test)
private @system string readLargeFile() {
	import std.path : expandTilde;
	import std.file : readText;
	return "~/Downloads/large-file.json".expandTilde.readText;
}

version (unittest) {
	import std.array : Appender;
	import std.meta : AliasSeq;
	private alias ArraySink = CodeUnitType[];
	private alias AppenderSink = Appender!(ArraySink);
	private alias CharTypes = AliasSeq!(char, wchar, dchar);
	private enum TestEnum { first, second, third }
	private class TestClass {
		int a, b;
		this(int a = 0, int b = 0) @safe pure nothrow @nogc {
			this.a = a;
			this.b = b;
		}
	}
	private class CycleClass {
		this(int x = 0) @safe pure nothrow @nogc {
			this.x = x;
			this.parent = this; // self-reference
		}
		int x;
		CycleClass parent;
	}
	private class CycleStruct {
		int x;
		CycleStruct* parent;
	}
	import std.traits : ParameterTypeTuple;
	alias ConstructorParams = ParameterTypeTuple!(typeof(__traits(getOverloads, TestClass, "__ctor")[0]));
	static assert(is(ConstructorParams == AliasSeq!(int, int)));
	debug import nxt.debugio;
}
