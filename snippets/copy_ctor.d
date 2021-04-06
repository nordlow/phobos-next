#!/usr/bin/env rdmd-unittest-module

import std.traits, std.meta, std.range, std.algorithm, std.stdio;

// https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1018.md

struct A
{
    this(int x)                 // ctor
    {
        this.x = x;
    }
    this(ref return scope inout A rhs) inout // copy ctor
    {
        writeln("Copying ", rhs.x,
                " from rhs of type ", A.stringof,
                " to ", typeof(this).stringof, " ...");
        this.x = rhs.x;
    }
    int x;
}

void main()
{
    auto a = A(42);
    A b = a;            // calls copy constructor implicitly - prints "x"
    A c = A(b);         // calls constructor explicitly
    immutable A d = a;  // calls copy constructor implicittly - prints 7
}
