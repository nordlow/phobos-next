struct P(T, alias fn) { T x; T y; }
struct Q(T) { T x; T y; }

@safe pure unittest
{
    P!(int, _ => _) p;
    Q!(int) q1;
    Q!(int) q2;
}
