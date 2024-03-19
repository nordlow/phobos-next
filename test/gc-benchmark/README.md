# Sweep-Free and Segregated GC for the D programming language (Dlang)

This project contains a specification and implementation of a new garbage
collector for the D programming language.

## Specification

### Densely stored mark bits and sweep-free

Inspired by Go's [Proposal: Dense mark bits and sweep-free
allocation](https://github.com/golang/proposal/blob/master/design/12800-sweep-free-alloc.md)
also referenced [here](https://github.com/golang/go/issues/12800). This spec
makes use of two continuous bitmaps `slotUsages` and `slotMarks`. The
`slotUsages` is used during allocation phase. During the mark-phase, the bitmap
`slotMarks` is zero-initialized and filled in as pointers to slots are
discovered to be referenced. When mark-phase is complete this new bitmap
`slotMarks` is swapped with `slotUsages`. This may or may not work for pools of
objects that have finalizers (TODO find out).

When the allocator has grown too large it will be neccessary to do sweeps and
run-finalizers to free pages. Such sweeps can be triggered by a low memory limit
(ratio) and doesn't have to do a complete sweep if low latency is
needed.

The running of a finalizer can be delayed to the time when its slots is needed
by an allocation.

### Segregated via Design by Introspection

Opposite to D's current GC, different size classes are allocated in separate
pools, called *segregated* allocation. This will lead to worse cache locality
during consecutive allocation of different size classes. The implementation is
however significantly simpler to express in code especially when D's design by
introspection via `static foreach` plus `mixin` is used to instantiate different
pool types. This will likely leading to a faster mark phase typically for types
without indirections, but this remains to be proven.

The lack of sweep phase will lead to a significantly lower worst case for the
collection time.

Segregation happens on all combinations of

- *size class* (typically 8, 16, 24, 32, 40, 48, etc),
- *scanningness* (whether they *may* contain pointers or not), and
- *finalization* (whether type is an aggregate type `struct` or
  `class` having a finalizer)

resulting in `2*2*number_of_size_classes` different pool kinds. This matches
Dmitry Olshansky recommendations for a new GC in his blog post titled "Inside
D's GC" which is currently missing from the web. A copy is hosted [locally
here](./inside-d-gc-by-dmitry-olshansky.md).

Note that because segregation happens not only on size class the term *size
class* might need to be changed to a term that also expresses the segregation on
*scanningness* and *finalization* in its naming.

### Uses compile-time introspection

Uses `static foreach` plus `mixin` to realize pool types for different size
classes with minimal code duplication.

### Choice of Size Classes

Use jemalloc `size classes`: For size classes in between powers of two we can
allocate pages in 3*n chunks. This is has been added to D's default GC aswell.

Calculate size class at compile-time using next power of 2 of `T.sizeof` for
calls to `new T()` and feed into `N` size-dependent overloads of `mallocN()`,
`callocN()`, `reallocN()` etc.

Each pool of a given size class (`SmallPool(uint sizeClass)`) contains a set of
unordered page tables of a given size class (`SmallPageTable(uint
sizeClass)`). Each page table contains a page and set of usage and mark bits.

The smallest byte size memory granularity is `wordSize` being 64 on a 64-bit
system.

All pages are built up of an array of slots (`SmallSlots`). The minimum common
word length of all pages is defined by `minimumSmallPageWordCount` which is
currently is fixed to `PAGESIZE`. It may be motivated to later compute this at
compile-time from the minimum word count of all the instances of `SmallPage`.

A single hash-table maps all base pointer(s) of pages inside all page tables
Block instance pointer instead of a binary search to speed up page-search
([Olshansky again](./inside-d-gc-by-dmitry-olshansky.md)). Hash-table use open
addressing and Fibonacci hashing, for instance, phobos-next's
[`hybrid_hashmap.c`](https://github.com/nordlow/phobos-next/blob/master/src/hybrid_hashmap.d).

Add run-time information for implicit (by compiler) and explicit (by developer
in library) casting from mutable to `immutable` and, in turn, `shared` for
isolated references.  Typically named: `__cast_immutable`, `__cast_shared`. To
make this convenient the compiler might ahead-of-time calculate figure out if
non-`shared` allocation later must be treated as `shared` and allocated in the
first place on the global GC heap.

### Mark-phase

- For each potential pointer `p` in stack
  - Check if `p` lies within address bounds of all pools. This phase might be
    better expressed via the hash-table lookup of the block base part of the
    pointer.
  - If so, find page storing that pointer (using a hashmap from base pointers to pages)
  - If that slot lies in a pool and and that slot belongs to a pool whols
    element types may contain pointers that slot hasn't yet been marked scan that
    slot.
- Finally mark slot
- Find first free slot (0) in pageSlotOccupancies bitarray of length using
  `core.bitop`. Use my own bitarray implementation.

### Address bit-mask

The x86-64 architecture (as of 2016) allows 48 bits for virtual memory and, for
any given processor, up to 52 bits for physical memory. This means that the 16
most significant bits can be used for meta-data such as discriminator
tags. Also, the 3 least significant bits are unused and can be also be used.

These two regions of free-space could be exposed a bitmask, for instance
`~0x_ffff_0000_0000_0007`, in the `core.memory.GC` data structure to indicate
which parts of an address that are actually used by the OS. This idea will be
especially effective if the modified GC is precise.

For details see https://en.wikipedia.org/wiki/64-bit_computing#Limits_of_processors.

## Key-Questions

- Should slot occupancy status

1. be explicitly stored in a bitarray and allocated in conjunction with
pages somehow (more performant for dense representations) This requires this
bitarray to be dynamically expanded and deleted in-place when pages are
removed
2. automatically deduced during sweep into a hashset of pointers (more
performant for sparse data) and keep some extra

### Conservative for now, Precise later

GC is conservative for now but will be prepared for a merge with Rainer's
precise add-ons.

## Note

Please note that block attribute data must be tracked, or at a minimum, the
FINALIZE bit must be tracked for any allocated memory block because calling
rt_finalize on a non-object block can result in an access violation.  In the
allocator below, this tracking is done via a leading uint bitmask.  A real
allocator may do better to store this data separately, similar to the basic GC.

## References

1. [Inside D's GC](https://olshansky.me/gc/runtime/dlang/2017/06/14/inside-d-gc.html)

1. [Inside D's GC on Hacker News](https://news.ycombinator.com/item?id=14592457)

2. [DIP 46: Region Based Memory Allocation](https://wiki.dlang.org/DIP46)

3. [Thread-local GC](https://forum.dlang.org/thread/xiaxgllobsiiuttavivb@forum.dlang.org)

4. [Thread GC non "stop-the-world"](https://forum.dlang.org/post/dnxgbumzenupviqymhrg@forum.dlang.org)

5. [Conservative GC: Is It Really That Bad?](https://www.excelsiorjet.com/blog/articles/conservative-gc-is-it-really-that-bad/)
   and [here](https://forum.dlang.org/thread/qperkcrrngfsbpbumydc@forum.dlang.org)

6. [GC page and block metadata storage](https://forum.dlang.org/thread/fvmiudfposhggpjgtluf@forum.dlang.org)

7. [Scalable memory allocation using jemalloc](https://www.facebook.com/notes/facebook-engineering/scalable-memory-allocation-using-jemalloc/480222803919/)

8. [How does jemalloc work? What are the benefits?](https://stackoverflow.com/questions/1624726/how-does-jemalloc-work-what-are-the-benefits)

9. [What are the advantages and disadvantages of having mark bits together and separate for Garbage Collection](https://stackoverflow.com/questions/23057531/what-are-the-advantages-and-disadvantages-of-having-mark-bits-together-and-separ)

10. [Adding your own GC to the GC Registry](https://dlang.org/spec/garbage.html#gc_registry)

11. [Understanding GC memory ranges and roots](https://forum.dlang.org/post/uiuedvfnftsnbpmkchyq@forum.dlang.org)

12. [Tasks, actors and garbage collection](https://forum.dlang.org/post/yqdwgbzkmutjzfdhotst@forum.dlang.org)
