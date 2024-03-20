/++ User-Defined Effects.

	Mathematical total function (Koka's `total`) is already present in D via the
	`pure` qualifier.

	See_Also: http://dpldocs.info/this-week-in-d/Blog.Posted_2022_08_15.html
	See_Also: https://koka-lang.github.io/koka/doc/book.html#sec-semantics-of-effects
	See_Also: https://koka-lang.github.io/koka/doc/book.html#why-effects
 +/
module nxt.effects;

@safe:

/++ UDA of (member) function whose returned value is (internally) cached in
	RAM.

	Cache is stored by default in `this`.

	TODO: Can we realize caching and `in bool reload` automatically using a
    mixin generating the wrapper function automatically?
 +/
enum caches_return_value;

/++ UDA of (member) function whose returned value is (externally) cached
	(to disk).
 +/
enum caches_return_value_to_disk;

/++ UDA of function that writes to `stdout` or `stderr`.
	In Koka this is `console`.
 +/
enum writes_to_console;

/++ UDA of function that (dynamically) allocates memory either with
	GC or `malloc()`. +/
enum allocates_on_heap;

/++ UDA of function that allocates memory with the built-in GC. +/
enum allocates_on_gc_heap;

/++ UDA of function that has non-deterministic behaviour.
	Typically reads an extern resource such as the system clock.
	In Koka this is `ndet`.
	+/
enum non_deterministic;
private alias ndet = non_deterministic;	// Koka-compliant alias.

/++ UDA of function that may throw an `Exception|Error`.
	In Koka this is `exn`.
	+/
enum throws;
private alias exn = throws;	// Koka-compliant alias.

/++ UDA of function that never terminates.
	In Koka this is `div`.
	+/
enum never_terminates;
private alias non_terminating = never_terminates;
private alias divergent = never_terminates;
private alias div = non_terminating; // Koka-compliant alias.
