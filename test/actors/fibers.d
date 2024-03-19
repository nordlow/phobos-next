/** Fiber abstractions.
 *
 * See_Also: http://ddili.org/ders/d.en/fibers.html
 * See_Also: https://dlang.org/migrate-to-shared.html#shared
 */
module nxt.fibers;

template isFiberParameter(T)
{
	import std.traits : hasAliasing;
	enum isFiberParameter = !hasAliasing!T;
}

unittest {
	static assert(isFiberParameter!int);
	static assert(!isFiberParameter!(int*));
	static assert(isFiberParameter!string);
}

import core.internal.traits : allSatisfy;
import core.thread : Fiber;
import std.stdio;

static immutable maxFiberCount = 100;
static immutable chunkFiberCount = 10;

size_t fiberCounter = 0;		// thread global (in TLS)

/** Function-like fiber.
 *
 * Arguments must all fulfill `isFiberParameter`.
 */
class TestFiber : Fiber
{
	this(size_t counter)
	{
		writeln("this:", counter);
		_counter = counter;
		super(&run);
	}
private:
	void run()
	{
		while (fiberCounter + chunkFiberCount < maxFiberCount)
		{
			foreach (immutable i; 0 .. chunkFiberCount)
			{
				writeln("loop:", _counter);
				auto subFiber = new TestFiber(fiberCounter);
				subFiber.call();
				fiberCounter += 1;
			}
		}
	}
	size_t _counter;
}

///
unittest {
	auto rootFiber = new TestFiber(0);
	rootFiber.call();

	// foreach (immutable i; 0 .. maxFiberCount)
	// {
	//	 // create instances of each type
	//	 auto derived = new TestFiber(i);
	//	 // Fiber composed = new Fiber(&fiberFunc, i);

	//	 // call both fibers once
	//	 derived.call();
	//	 // composed.call();
	//	 // printf("Execution returned to calling context.\n");
	//	 // composed.call();

	//	 // since each fiber has run to completion, each should have state TERM
	//	 assert(derived.state == Fiber.State.TERM);
	//	 // assert(composed.state == Fiber.State.TERM);
	// }
}

/** Function-like fiber.
 *
 * Arguments must all fulfill `isFiberParameter`.
 */
class FunFiber(Args...) : Fiber
if (allSatisfy!(isFiberParameter, Args))
{
	this(Args args)			 /+ TODO: make args const? +/
	{
		_args = args;
		super(&run);
	}
private:
	void run()
	{
		writeln(_args);
	}
	Args _args;
}
