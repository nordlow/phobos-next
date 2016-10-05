/// Qualified (`@safe pure nothrow @nogc`) C memory management.
module qmem;

extern(C)
{
    // qualified C memory allocations
    @safe pure nothrow @nogc:
    void* malloc(size_t size);
    void* calloc(size_t nmemb, size_t size);
    void* realloc(void* ptr, size_t size);
    void free(void* ptr);

    void gc_addRange( in void* p, size_t sz, const TypeInfo ti = null );
    void gc_removeRange( in void* p );
}
