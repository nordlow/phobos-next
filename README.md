# phobos-next

Additional useful containers, algorithms, wrapper types, traits etc. Several are
generic enough to have a place in Phobos.

Documentation used to be generated
[here](https://phobos-next.dpldocs.info/index.html) but it’s currently out of
date and I don’t know how to update it.

Announcement [here](http://forum.dlang.org/post/tppptevxiygafzpicmgz@forum.dlang.org).

Includes

## Extra Attributes
- `tlm`: "template-lazy member" meaning that this member function template is
  has an extra set of template parameters to delay its instantiation when it's
  parenting aggregate is instantiated.
- `!tlm`: this member cannot template-lazy

## Traits
- When possible builtin `__traits()` are used over templated traits to minimize
  template bloat.
- The `__traits(isPOD, T)` is used to detect when a instance of `T` can be
  passed by value opposite to passed by move (typically using either `move` or
  `moveEmplace`). There are plans for the compiler to perform this optimization
  automatically. When that is added these calls can replaced with a single
  assignment. For details see
  https://forum.dlang.org/post/rkoqrnwybgjmxuvaidlw@forum.dlang.org

## Containers
- `trie.d`: Trie with sortedness and prefix completion(s).
- `dynamic_array.d`: Basic uncopyable array with value semantics and explicit
  copying via `.dup`.
- `fixed_dynamic_array.d`: Dynamically allocated (heap) array with fixed length.
- `minimal_static_array.d`: Minimalistic statically-sized (stack) array of length smaller
than 255 fitting in an `ubyte` for compact packing.
- `hybrid_hashmap.d`: Combined hashset and hashmap with open addressing
  and support for deletion via hole handling. Pointers and classes are stored as
  is with support for vacancy and hole handling. Vacancy support for
  `std.typecons.Nullable`.
- `cyclic_array.d`: Cyclic array.
- `filterarray.d`: Filter array.
- `static_array.d`: Fixed-sized statically allocated (heap) array similar to C++ `std::array`.
- `bitarray.d`: A dynamically sized (heap) bit array.
- `static_bitarray.d`: A statically sized (stack) bit array.
- ...

For reference semantics wrap uncopyable containers in `std.typecons.RefCounter`.

## Wrapper types
- `bound.d`: A wrapper for bounded types.
- `notnull.d`: Enhanced `NotNull`.
- `digest_ex.d`: A structured wrapper for message digests.
- `sorted.d`: A structured wrapper for sorted random access containers (arrays).
- ...

## Algorithms

- `integer_sorting.d`: Integer sorting algorithms, including radix sort.
- `horspool.d`: Boyer-Moore-Hoorspool search.
- ...

## Utilities

- `debugio.d`: Debug printing.
- `csunits.d`: Computer Science units.
- ...

## Extensions
- Various extension to Phobos (often ending with _ex.d)
- ...

## License

BSL-1.0.
