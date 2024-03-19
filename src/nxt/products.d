module nxt.products;

import std.range.primitives : isInputRange, ElementType;

auto cartesianProductDynamic(R)(R x)
	if (isInputRange!R &&
		isInputRange!(ElementType!R))
{
	import std.algorithm : map;
	import std.algorithm.setops : cartesianProduct;
	import std.array : array;
	import std.algorithm : count;
	import nxt.traits_ex : asDynamicArray;

	alias E = ElementType!(ElementType!R);
	alias C = E[]; // combination
	const n = x.count;

	final switch (n)
	{
	case 0: return R.init;
	case 1: return [x[0]];
	case 2: return cartesianProduct(x[0], x[1]).map!(a => a.asDynamicArray).array;
	case 3: return cartesianProduct(x[0], x[1], x[2]).map!(a => a.asDynamicArray).array;
	case 4: return cartesianProduct(x[0], x[1], x[2], x[3]).map!(a => a.asDynamicArray).array;
	case 5: return cartesianProduct(x[0], x[1], x[2], x[3], x[4]).map!(a => a.asDynamicArray).array;
	case 6: return cartesianProduct(x[0], x[1], x[2], x[3], x[4], x[5]).map!(a => a.asDynamicArray).array;
	case 7: return cartesianProduct(x[0], x[1], x[2], x[3], x[4], x[5], x[6]).map!(a => a.asDynamicArray).array;
	case 8: return cartesianProduct(x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7]).map!(a => a.asDynamicArray).array;
	case 9: return cartesianProduct(x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8]).map!(a => a.asDynamicArray).array;
	// default:
	//	 foreach (const i; 0 .. n)
	//	 {
	//		 foreach (const j; x[i])
	//		 {
	//			 y[i] ~= j;
	//		 }
	//	 }
	//	 auto y = new C[n];
	//	 return y;
	}

}

unittest {
	import std.algorithm.comparison : equal;
	auto x = cartesianProductDynamic([["2", "3"],
									  ["green", "red"],
									  ["apples", "pears"]]);
	assert(equal(x,
				 [["2", "green", "apples"],
				 ["2", "green", "pears"],
				  ["2", "red", "apples"],
				  ["2", "red", "pears"],
				  ["3", "green", "apples"],
				  ["3", "green", "pears"],
				  ["3", "red", "apples"],
				  ["3", "red", "pears"]]));
}
