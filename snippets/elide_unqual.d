struct U(size_t n) { int x;}
struct C { U!2 s; alias s this;}

enum isU(T) = is(immutable T == immutable U!size, size_t size);

static assert(isU!(U!2));
static assert(isU!(const U!2));
static assert(isU!(immutable U!2));
static assert(isU!(shared U!2));

static assert(!isU!C);
static assert(!isU!(const(C)));
static assert(!isU!(immutable(C)));
static assert(!isU!(shared(C)));

// enum isU1(T) = is(T : const U!size, size_t size);
// static assert(isU1!C);

// enum isU2(T) = is(Unqual!T == U!size, size_t size);
// static assert(!isU2!C);
// static assert(!isU2!(const(C)));

// enum isU3(T) = is(T == cast()(U!size), size_t size);
// static assert(!isU3!(const(C)));
// alias I = cast()(const(int));

// enum isU4(T) = is(T == typeof(cast()((U!size).init)), size_t size);
// static assert(isU4!C);

// enum isU5(T) = is(T == const U!size, size_t size);
// static assert(!isU5!(const(C)));
// static assert(!isU5!C);
