/** Backwards-compatible extensions of `std.stdio.{f}write{ln}` to `p{f}write{ln}`.
 *
 * Test: dmd -version=show -preview=dip1000 -preview=in -vcolumns -d -I.. -i -debug -g -checkaction=context -allinst -unittest -main -run stdio.d
 *
 * See_Also: `core.internal.dassert`
 *
 * NOTE: Replacing calls to overloaded `fpwrite1` with non-overloaded versions
 * such as `fpwrite1_char`, `fpwrite1_string` reduces compilation memory usage.
 *
 * TODO: Support bitfields via new `__traits(isBitfield, T)`
 *
 * TODO: Add option to show `@safe pure nothrow` @attributes
 *
 * TODO: Cast to `arg const` for `T` being `struct` and `class` with `const toString` to avoid template-bloat
 *
 * TODO: Use setlocale to enable correct printing {w|d}char([])
 * #include <wchar.h>
 * #include <locale.h>
 * #include <stdio.h>
 *
 * int main() {
 *     // Set the locale to the user default, which should include Unicode support
 *     setlocale(LC_ALL, "");
 *
 *     wchar_t letter1 = L'å';
 *     wchar_t letter2 = L'ä';
 *     wchar_t letter3 = L'ö';
 *
 *     wprintf(L"%lc %lc %lc\n", letter1, letter2, letter3);
 *
 *     return 0;
 * }
 *
 * In D you use:
 *
 * import core.stdc.locale : setlocale, LC_ALL;
 * () @trusted { setlocale(LC_ALL, ""); }();
 *
 * TODO: Perhaps make public (top) functions throw static exceptions keeping them `@nogc`.
 */
module nxt.stdio;

// version = show;

import core.stdc.stdio : stdout, fputc, fprintf, FILE, EOF, c_fwrite = fwrite;
import core.stdc.wchar_ : fputwc, fwprintf;
import nxt.visiting : Addrs = Addresses;
import nxt.effects : writes_to_console; // TODO: uncomment references below when `dub test` passes without linker failure

// TODO: why does this work when others fail?
private void foo(Args...)(in Args args) @writes_to_console {
}
@safe pure unittest {
	foo();
}

@safe:

/++ Writing/Printing format. +/
@safe struct Format {
@safe pure nothrow @nogc:
	static typeof(this) plain() {
		typeof(return) result;
		result.showClassValues = true;
		result._dereferencePointerValuesUnsafe = false;
		result.showEnumeratorEnumType = true;
		result.showEnumatorValues = true;
		result.useFonts = true;
		return result;
	}
	static typeof(this) pretty() {
		typeof(return) result = typeof(this).plain;
		result.showFieldNames = true;
		result.useFonts = true;
		return result;
	}
	static typeof(this) fancy() {
		typeof(return) result = typeof(this).pretty;
		result.showFieldTypes = true;
		result.showClassInfoNames = true;
		return result;
	}
	static typeof(this) debugging() {
		typeof(return) result = typeof(this).fancy;
		result.showVoidArrayValues = true;
		result.abbreviateInitValues = true;
		result.dynamicArrayLengthMax = 8;
		result.multiLine = true;
		return result;
	}
	static typeof(this) everything() {
		typeof(return) result = typeof(this).fancy;
		result.multiLine = true;
		return result;
	}

	size_t level = 0; ///< Level of (aggregate) nesting starting at 0.
	string indentation = "\t"; ///< Indentation.
	char arrayPrefix = '['; ///< (Associative) Array prefix.
	char arraySuffix = ']'; ///< (Associative) Array suffix.
	char aggregatePrefix = '('; ///< Array fields prefix.
	char aggregateSuffix = ')'; ///< Array fields suffix.
	char fieldTypeSeparator = ' '; ///< Field type separator.
	static immutable fieldNameSeparator = ": "; ///< Field name separator.
	static immutable arrayElementSeparator = ", "; ///< Array element separator.
	static immutable aggregateFieldSeparator = ", "; ///< Aggregate field separator.
	char backReferencePrefix = '#'; ///< Backward reference prefix.
	bool quoteChars; ///< Wrap characters {char|wchar|dchar} in ASCII single-quote character '\''.
	bool quoteStrings; ///< Wrap strings {string|wstring|dstring} in ASCII single-quote character '"'.
	bool showAddresses = true; ///< Show address of classes and pointers.
	bool showClassValues; ///< Show fields of non-null classes (instead of just pointer).
	bool showClassInfoNames; ///< Use `.classinfo.name` to display the name of a class instance.
	private bool _dereferencePointerValuesUnsafe; ///< Show values of non-null pointers (instead of just pointer). WARNING: Unsafe
	bool showEnumeratorEnumType; ///< Show enumerators as `EnumType.enumeratorValue` instead of `enumeratorValue`.
	bool showEnumatorValues; ///< Show values of enumerators instead of their names.
	bool showFieldNames = false; ///< Show names of fields.
	bool showFieldTypes = false; ///< Show types of values.
	bool showVoidArrayValues = false; ///< Show values of void arrays as ubytes instead of `[?]`.
	bool abbreviateInitValues = false; ///< Abbreviate default values to `.init` when it reduces the size of the output.
	bool multiLine = false; ///< Span multiple lines using `indent`.
	bool useFonts; ///< Use different fonts for different types. TODO: Use nxt.ansi_escape
	size_t dynamicArrayLengthMax = size_t.max; ///< Limit length of dynamic arrays to this value when printing.
}

///
@safe pure nothrow @nogc unittest {
	assert(Format.plain != Format.pretty);
	assert(Format.pretty != Format.fancy);
	assert(Format.fancy != Format.debugging);
	assert(Format.fancy != Format.everything);
}

/** Pretty-formatted `fwrite(sm, ...)`. */
void fpwrite(Args...)(scope FILE* sm, in Format fmt, in Args args) /+@writes_to_console+/ {
	// pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", Args);
	scope Addrs addrs;
	foreach (ref arg; args) {
		static if (is(typeof(arg) == enum))
			sm.fpwrite1_enum(arg, fmt, addrs);
		else
			sm.fpwrite1(arg, fmt, addrs);
	}
}

/** Pretty-formatted `fwrite(stderr, ...)`. */
void epwrite(Args...)(in Format fmt, in Args args) /+@writes_to_console+/
	=> fpwrite(stderr, fmt, args);

/** Alternative to `std.stdio.fwrite`. */
void fwrite(Args...)(scope FILE* sm, in Args args) /+@writes_to_console+/
	=> sm.fpwrite!(Args)(Format.init, args);

/** Alternative to `std.stdio.write(stdout)`. */
void write(Args...)(in Args args) /+@writes_to_console+/
	=> stdout.fwrite(args);

/** Alternative to `std.stdio.write(stderr)`. */
void ewrite(Args...)(in Args args) /+@writes_to_console+/
	=> stderr.fwrite(args);

/** Pretty-formatted `fwriteln`. */
void fpwriteln(Args...)(scope FILE* sm, in Format fmt, in Args args) /+@writes_to_console+/ {
	sm.fpwrite!(Args)(fmt, args);
	const st = sm.fpwrite1_char('\n');
	// sm.fflush();
}

/** Pretty-formatted `writeln`. */
void pwriteln(Args...)(in Format fmt, in Args args) /+@writes_to_console+/
	=> stdout.fpwriteln(fmt, args);
/** Pretty-formatted `stderr.writeln`. */
void epwriteln(Args...)(in Format fmt, in Args args) /+@writes_to_console+/
	=> stderr.fpwriteln(fmt, args);

/** Alternative to `std.stdio.fwriteln`. */
void fwriteln(Args...)(scope FILE* sm, in Args args) /+@writes_to_console+/ {
	sm.fwrite(args);
	const st = sm.fpwrite1_char('\n');
	// sm.fflush();
}

/** Alternative to `std.stdio.writeln`. */
void writeln(Args...)(in Args args) /+@writes_to_console+/
	=> stdout.fwriteln(args);

@safe pure unittest {
	import core.time : Duration;
	// TODO: writeln(Duration.init);
}

private:

/** Pretty-formatted write single argument `arg` to `sm`. */
void fpwrite1(T)(scope FILE* sm, in T arg, in Format fmt, scope ref Addrs addrs) /+@writes_to_console+/ {
	// pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: ", T);
	static if (is(T : _U1[_N1], _U1, size_t _N1) /+|| is(T : __vector(_U2[_N2]), _U2, size_t _N2)+/) {
		// TODO: generalize and use `nxt.vector_traits.isInit`
		if (fmt.abbreviateInitValues && arg == arg.init) {
			const st1 = sm.fpwrite1_string(T.stringof);
			const st2 = sm.fpwrite1_string(".init");
			return;
		}
	}
	static if (is(T == enum)) {
		sm.fpwrite1_enum(arg, fmt, addrs);
	} else static if (__traits(hasMember, T, "toString") && is(typeof(arg.toString) : string)) {
		string str;
		() @trusted {
			/+ avoid scope compilation errors such as:
			   scope variable `arg` calling non-scope member function `JSONValue.toString()`
			 +/
			str = arg.toString;
		}();
		const int st = sm.fpwrite1_string(str, fmt.quoteStrings);
		return; // TODO: forward `st`
	} else static if (is(T == enum)) {
		static assert(0, "TODO: Branch on `fmt.showEnumatorValues`");
	} else static if (is(T : __vector(U[N]), U, size_t N)) /+ must come before `__traits(isArithmetic, T)` below because `is(__traits(isArithmetic, float4)` holds: +/ {
		const st = sm.fpwrite1ArrayValueExceptString(arg, fmt, addrs, false);
	} else static if (is(immutable T == immutable bool)) {
		const st = sm.fpwrite1_string(arg ? "true" : "false");
	} else static if (__traits(isArithmetic, T)) {
		static if (is(immutable T == immutable char)) {
			if (fmt.quoteChars) { const st1 = fputc('\'', sm); }
			const st = fputc(arg, sm);
			if (fmt.quoteChars) { const st2 = fputc('\'', sm); }
		} else static if (is(immutable T == immutable wchar) || is(immutable T == immutable dchar)) {
			if (fmt.quoteChars) { const st1 = fputc('\'', sm); }
			const st = fputwc(arg, sm);
			if (fmt.quoteChars) { const st2 = fputc('\'', sm); }
		} else {
			// See: `getPrintfFormat` in "core/internal/dassert.d"
			static      if (is(immutable T == immutable byte))
				immutable pff = "%hhd";
			else static if (is(immutable T == immutable ubyte))
				immutable pff = "%hhu";
			else static if (is(immutable T == immutable short))
				immutable pff = "%hd";
			else static if (is(immutable T == immutable ushort))
				immutable pff = "%hu";
			else static if (is(immutable T == immutable int))
				immutable pff = "%d";
			else static if (is(immutable T == immutable uint))
				immutable pff = "%u";
			else static if (is(immutable T == immutable long))
				immutable pff = "%lld";
			else static if (is(immutable T == immutable ulong))
				immutable pff = "%llu";
			else static if (is(immutable T == immutable float))
				immutable pff = "%g"; // or %e %g
			else static if (is(immutable T == immutable double))
				immutable pff = "%lg"; // or %le %lg
			else static if (is(immutable T == immutable real))
				immutable pff = "%Lg"; // or %Le %Lg
			else
				static assert(0, "TODO: Handle argument of type " ~ T.stringof);
			() @trusted { const st = sm.fprintf(pff.ptr, arg);} ();
		}
	} else static if (is(T : U[N], U, size_t N)) { // isStaticArray
		static if (is(U == char) || is(U == wchar) || is(U == dchar)) { // `isSomeChar`
			if (fmt.quoteStrings) { const st1 = sm.fpwrite1_char('"'); }
			const stm = sm.fpwrite1(arg, fmt);
			if (fmt.quoteStrings) { const st2 = sm.fpwrite1_char('"'); }
		} else {
			const st = sm.fpwrite1ArrayValueExceptString(arg[]/+ `arg[]` avoids template bloat +/, fmt, addrs, false);
		}
	} else static if (is(T : const(U)[], U)) { // isDynamicArray
		static if (is(U == char) || is(U == wchar) || is(U == dchar)) { // `isSomeChar`
			if (fmt.quoteStrings) { const st1 = sm.fpwrite1_char('"'); }
			const stm = sm.fpwrite1(arg, fmt);
			if (fmt.quoteStrings) { const st2 = sm.fpwrite1_char('"'); }
		} else {
			import std.algorithm.comparison : min;
			const truncated = arg.length > fmt.dynamicArrayLengthMax;
			const st = sm.fpwrite1ArrayValueExceptString(arg[0 .. min(arg.length, fmt.dynamicArrayLengthMax)], fmt, addrs, truncated);
		}
	} else static if (is(typeof(T.init.byKeyValue))) { // isAssociativeArray || isMap
		const st1 = sm.fpwrite1_char(fmt.arrayPrefix);
		size_t i;
		Format keyFmt = fmt; // key format
		Format valFmt = fmt; // value format
		alias Key = typeof(T.init.keys[0]);
		alias Val = typeof(T.init.values[0]);
		static if (!is(Key == struct) && !is(Key == class))
			keyFmt.indentation = null;
		static if (!is(Val == struct) && !is(Val == class))
			valFmt.indentation = null;
		foreach (ref kv; arg.byKeyValue) {
			if (i)
				const st1_ = sm.fpwrite1_string(fmt.arrayElementSeparator);
			sm.fpwrite1(kv.key, keyFmt, addrs);
			const st = sm.fpwrite1_string(": ");
			sm.fpwrite1(kv.value, valFmt, addrs);
			i += 1;
		}
		const st2 = sm.fpwrite1_char(fmt.arraySuffix);
	} else static if (is(T == struct)) {
		sm.fpwriteAggregate(arg, fmt, addrs);
    } else static if (is(T == class) || is(T == const(U)*, U)) { // isAddress
        const bool isNull = arg is null;
		if (isNull) {
			const st = sm.fpwrite1_string("null");
			return;
		}

		const void* addr = () @trusted { return cast(void*)arg; }();
		if (fmt.showAddresses)
			() @trusted { const st = sm.fprintf("%lX", cast(size_t)addr, arg);} ();

		import nxt.algorithm.searching : indexOf;
		const ix = addrs[].indexOf(addr);
		if (ix != -1) { // `addr` already printed
			const st1 = sm.fpwrite1_char(fmt.backReferencePrefix);
			sm.fpwrite1(ix, fmt, addrs);
			return;
		}
		() @trusted { addrs ~= addr; }(); // `addrs`.lifetime <= `arg`.lifetime
        static if (is(T == class)) {
			if (fmt.showClassValues) {
				const st = sm.fpwrite1_string(" . ");
				sm.fpwriteAggregate(arg, fmt, addrs);
			}
        } else {
			if (fmt._dereferencePointerValuesUnsafe) {
				const st = sm.fpwrite1_string(" -> ");
				static if (is(typeof(*arg))) {
					static if (__traits(compiles, { auto _ = cast()*arg; }/+isCopyable+/)) {
						() @trusted {
							sm.fpwrite1(cast()*arg, fmt, addrs);
						}();
					} else { // non-copyable or opaque forward-declared types
						const st_ = sm.fpwrite1_char('?');
					}
				} else { // `arg is void*`
					const st_ = sm.fpwrite1_char('?');
				}
			}
        }
	} else {
		static assert(0, "TODO: Handle argument of type " ~ T.stringof);
	}
}

int fpwrite1ArrayValueExceptString(T)(scope FILE* sm, in T arg, in Format fmt, scope ref Addrs addrs, bool truncated) /+@writes_to_console+/ {
	const st1 = sm.fpwrite1_char(fmt.arrayPrefix);
	static if (is(immutable T == immutable void[])) {
		if (fmt.showVoidArrayValues) {
			ubyte[] bytes;
			() @trusted {
				bytes = cast(ubyte[])arg/+to mutable to avoid template-bloat+/;
			}();
			sm.fpwriteArrayValues(bytes, fmt, addrs, truncated); // TODO: perhaps show as hex instead
		}
		else if (arg.length != 0) // if any unprintable elements
			const st = sm.fpwrite1_string("?"); // indicate that
	} else {
		sm.fpwriteArrayValues(arg[], fmt, addrs, truncated);
	}
	const st2 = sm.fpwrite1_char(fmt.arraySuffix);
	return 0;
}

int fpwriteArrayValues(E)(scope FILE* sm, in E[] arg, in Format fmt, scope ref Addrs addrs, bool truncated) /+@writes_to_console+/ {
	Format efmt = fmt; // element format
	efmt.quoteChars = true; // mimics `std.stdio`
	efmt.quoteStrings = true; // mimics `std.stdio`
	static if (!(is(E == struct) || is(E == union) || is(E == class)))
		efmt.indentation = null;
	foreach (const i, ref elt; arg) {
		if (i)
			const st1_ = sm.fpwrite1_string(fmt.arrayElementSeparator);
		sm.fpwrite1(elt, efmt, addrs);
	}
	if (truncated && arg.length != 0)
		sm.fpwrite1_string(", …");
	return 0;
}

void fpwriteAggregate(T)(scope FILE* sm, in T arg, in Format fmt, scope ref Addrs addrs) /+@writes_to_console+/
if (is(T == struct) || is(T == class)) {
	bool nameWritten = false;
	static if (is(T == class)) {
		static if (is(typeof(arg.classinfo.name) == string)) {
			if (fmt.showClassInfoNames) {
				const stN = sm.fpwrite1_string(arg.classinfo.name);
				nameWritten = true;
			}
		}
	}
	if (!nameWritten)
		const stN = sm.fpwrite1_type(T.stringof, T.mangleof);
	const stP = sm.fpwrite1_char(fmt.aggregatePrefix);
	sm.fpwriteFieldsOf(arg, fmt, addrs);
	const stS = sm.fpwrite1_char(fmt.aggregateSuffix);
}

void fpwriteFieldsOf(T)(scope FILE* sm, in T arg, in Format fmt, scope ref Addrs addrs) /+@writes_to_console+/
if (is(T == struct) || is(T == union) || is(T == class)) {
	Format ffmt = fmt; // field format
	ffmt.quoteChars = true; // mimics `std.stdio`
	ffmt.quoteStrings = true; // mimics `std.stdio`
	ffmt.level += 1;
	enum isNested = !is(T == class) && __traits(isNested, T);
	uint fieldOffset;
	static foreach (fieldSymbol; T.tupleof[0 .. $ - isNested]) {{
		enum fieldName = fieldSymbol.stringof;
		if (fieldOffset != 0)
			const sta = sm.fpwrite1_string(fmt.aggregateFieldSeparator);
		if (fmt.multiLine)
			const st1 = sm.fpwrite1_char('\n');
		sm.indent(ffmt);
		if (fmt.showFieldTypes) {
			alias FieldType = typeof(fieldSymbol);
			const stt = sm.fpwrite1_type(FieldType.stringof, FieldType.mangleof);
			const sts = sm.fpwrite1_char(fmt.fieldTypeSeparator);
		}
		if (fmt.showFieldNames) {
			const st1 = sm.fpwrite1_string(fieldName);
			const st2 = sm.fpwrite1_string(fmt.fieldNameSeparator);
		}
		() @trusted {
			static if (is(typeof(fieldSymbol) == enum))
				sm.fpwrite1_enum(__traits(getMember, arg, fieldName), ffmt, addrs);
			else {
				try {
					sm.fpwrite1(__traits(getMember, arg, fieldName), ffmt, addrs);
				} catch (Exception _) {
					const st = sm.fpwrite1_string("TODO: Avoid this Exception that is maybe triggered by casting away shared above");
				}
			}
		}();
		fieldOffset += 1;
	}}
}

int fpwrite1(scope FILE* sm, in   char arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fpwrite1_char(arg, fmt.quoteChars);
}
int fpwrite1(scope FILE* sm, in  wchar arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fpwrite1_wchar(arg, fmt.quoteChars);
}
int fpwrite1(scope FILE* sm, in  dchar arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fpwrite1_dchar(arg, fmt.quoteChars);
}

int fpwrite1(scope FILE* sm, in char[] arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fpwrite1_string(arg, fmt.quoteStrings);
}
int fpwrite1(scope FILE* sm, in wchar[] arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fpwrite1_wstring(arg, fmt.quoteStrings);
}
int fpwrite1(scope FILE* sm, in dchar[] arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fpwrite1_dstring(arg, fmt.quoteStrings);
}

int fpwrite1(scope FILE* sm, in   bool arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fpwrite1_string(arg ? "true" : "false");
}
int fpwrite1(scope FILE* sm, in   byte arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%hhd".ptr, arg);
}
int fpwrite1(scope FILE* sm, in  ubyte arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%hhu".ptr, arg);
}

int fpwrite1(scope FILE* sm, in  short arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%hd".ptr, arg);
}
int fpwrite1(scope FILE* sm, in ushort arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%hu".ptr, arg);
}

int fpwrite1(scope FILE* sm, in    int arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%d".ptr, arg);
}
int fpwrite1(scope FILE* sm, in   uint arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%u".ptr, arg);
}

int fpwrite1(scope FILE* sm, in   long arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%lld".ptr, arg);
}
int fpwrite1(scope FILE* sm, in  ulong arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%llu".ptr, arg);
}

int fpwrite1(scope FILE* sm, in  float arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%g".ptr, arg);
}
int fpwrite1(scope FILE* sm, in double arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%lg".ptr, arg);
}
int fpwrite1(scope FILE* sm, in real arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc /+@writes_to_console+/ {
	return sm.fprintf("%Lg".ptr, arg);
}

int fpwrite1_enum(T)(scope FILE* sm, in T arg, in Format fmt, scope ref Addrs addrs) @trusted nothrow @nogc if (is(T == enum)) {
	if (fmt.showEnumeratorEnumType) {
		sm.fpwrite1_string(T.stringof, false);
		sm.fpwrite1_char('.', false);
	}
	return sm.fpwrite1_string(arg.enumToString!T(fmt, "__unknown__"), false);
}

int fpwrite1_char(scope FILE* sm, in char arg, in bool quote = false) @trusted nothrow @nogc /+@writes_to_console+/ {
	if (quote) { const st1 = fputc('\'', sm); }
	const st = fputc(arg, sm);
	if (st == EOF) {} /+ TODO: throw or return error status +/
	if (quote) { const st1 = fputc('\'', sm); }
	return 0;
}

int fpwrite1_wchar(scope FILE* sm, in wchar arg, in bool quote = false) @trusted nothrow @nogc /+@writes_to_console+/ {
	if (quote) { const st1 = fputc('\'', sm); }
	const st = fputwc(arg, sm);
	if (st == EOF) {} /+ TODO: throw or return error status +/
	if (quote) { const st1 = fputc('\'', sm); }
	return 0;
}

int fpwrite1_dchar(scope FILE* sm, in dchar arg, in bool quote = false) @trusted nothrow @nogc /+@writes_to_console+/ {
	if (quote) { const st1 = fputc('\'', sm); }
	const st = fputwc(arg, sm);
	if (st == EOF) {} /+ TODO: throw or return error status +/
	if (quote) { const st1 = fputc('\'', sm); }
	return 0;
}

int fpwrite1_string(scope FILE* sm, in char[] arg, in bool quote = false) @trusted nothrow @nogc /+@writes_to_console+/ {
	if (quote) { const st1 = fputc('"', sm); }
	typeof(return) st;
	if (arg.length)
		st = cast(typeof(return))c_fwrite(&arg[0], 1, arg.length, sm);
	if (quote) { const st2 = fputc('"', sm); }
	return st;
}

int fpwrite1_wstring(scope FILE* sm, in wchar[] arg, in bool quote = false) @trusted nothrow @nogc /+@writes_to_console+/ {
	if (quote) { const st1 = fputc('"', sm); }
	typeof(return) st;
	if (arg.length)
		st = cast(typeof(return))c_fwrite(&arg[0], 1, arg.length, sm);
	if (quote) { const st2 = fputc('"', sm); }
	return st;
}

int fpwrite1_dstring(scope FILE* sm, in dchar[] arg, in bool quote = false) @trusted nothrow @nogc /+@writes_to_console+/ {
	if (quote) { const st1 = fputc('"', sm); }
	typeof(return) st;
	if (arg.length)
		st = cast(typeof(return))c_fwrite(&arg[0], 1, arg.length, sm);
	if (quote) { const st2 = fputc('"', sm); }
	return st;
}

int fpwrite1_type(scope FILE* sm, in char[] stringOf, in char[] mangleOf) @trusted nothrow @nogc /+@writes_to_console+/ {
	import nxt.algorithm.searching : startsWith;
	if (mangleOf.startsWith("S3__C")) {
		const stp = sm.fpwrite1_string("C:"); // C type prefix
	}
	const stN = sm.fpwrite1_string(stringOf);
	return stN;
}

string enumToString(T)(in T arg, in Format fmt, string defaultValue) if (is(T == enum)) {
	switch (arg) { // instead of slower `std.conv.to`:
		static foreach (member; __traits(allMembers, T)) { // instead of slower `EnumMembers`
		case __traits(getMember, T, member):
			return member;
		}
	default:
		return defaultValue;
	}
}

void indent(scope FILE* sm, in Format fmt) nothrow @nogc /+@writes_to_console+/ {
	if (fmt.multiLine)
		foreach (_; 0 .. fmt.level)
			const int st = sm.fpwrite1_string(fmt.indentation, false);
}

///
version (none)
@safe nothrow unittest {
	import core.simd;
	static struct Uncopyable { this(this) @disable; int _x; }
	scope const int* x = new int(42);
	enum NormalEnum {
		first = 0,
		second = 1,
	}
	writeln(NormalEnum.first);
	writeln(NormalEnum.second);
	enum StringEnum {
		OPENED = "opened",
		MERGED = "merged",
	}
	class Base {
		int baseField1;
		int baseField2;
	}
	class Derived : Base {
		this(int derivedField1, int derivedField2) {
			this.derivedField1 = derivedField1;
			this.derivedField2 = derivedField2;
		}
		int derivedField1;
		int derivedField2;
	}
	struct T {
		int x = 111, y = 222;
	}
	struct U {
		const bool b_f = false;
		const bool b_t = true;
	}
	struct V {
		const char ch_a = 'a';
		const wchar wch = 'ä';
		const dchar dch = 'ö';
		const c_ch = 'b';
		const i_ch = 'c';
	}
	struct W {
		const str = "åäö";
		const wstring wstr = "åäö";
		const dstring dstr = "åäö";
		const ubyte[] ua = [1,2,3];
		const void[] va = cast(void[])[1,2,3];
	}
	struct X {
		const  byte[3] ba = [byte.min, 0, byte.max];
		const short[3] sa = [short.min, 0, short.max];
		const   int[3] ia = [int.min, 0, int.max];
		const  long[3] la = [long.min, 0, long.max];
	}
	struct Y {
		const  float[3] fa = [-float.infinity, 3.14, +float.infinity];
		const double[3] da = [-double.infinity, 3.333333333, +double.infinity];
		const   real[3] ra = [-real.infinity, 0, +real.infinity];
	}
	struct OpaqueStruct;
	extern(C) struct OpaqueCStruct;
	struct S {
		T t;
		U u;
		V v;
		W w;
		X x;
		Y y;
		int ix = 32;
		const int iy = 42;
		immutable int iz = 52;
		const(int)* null_p;
		const(int)* xp;
		NormalEnum normalEnum;
		StringEnum stringEnum; // TODO: use
		const aa = [1:1, 2:2];
		float4 f4;
		void* voidPtr;
		Derived derived;
		Base baseBeingDerived;
		const(OpaqueStruct)* opaqueStruct;
		const(OpaqueCStruct)* opaqueCStruct;
		// TODO: Support these using `__traits(isBitField, T)`, errors as: Error: cannot take address of bit-field `ub4_0`
		// ubyte ub4_0 : 4;
		// ubyte ub4_1 : 4;
	}

	S s;
	s.xp = x;
	s.voidPtr = new int(42);
	s.derived = new Derived(33, 44);
	s.baseBeingDerived = new Derived(55, 66);

	writeln(Uncopyable.init);

	Format fmt;

	fmt = Format.init;
	pwriteln(fmt, s);

	fmt = Format.init;
	fmt.showFieldNames = true;
	pwriteln(fmt, s);

	fmt = Format.init;
	fmt.showFieldTypes = true;
	pwriteln(fmt, s);

	fmt = Format.init;
	fmt._dereferencePointerValuesUnsafe = true;
	pwriteln(fmt, s);

	fmt = Format.init;
	fmt.showEnumeratorEnumType = true;
	pwriteln(fmt, s);

	fmt = Format.fancy;
	pwriteln(fmt, s);

	// import std.stdio : writeln;
	// debug writeln(s);
}
