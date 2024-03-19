module nxt.static_iota;

/** Static Iota.
 *
 * TODO: Move to Phobos.
 */
template iota(size_t from, size_t to)
if (from <= to)
{
	alias iota = siotaImpl!(to-1, from);
}
private template siotaImpl(size_t to, size_t now)
{
	import std.meta: AliasSeq;
	static if (now >= to) { alias siotaImpl = AliasSeq!(now); }
	else				  { alias siotaImpl = AliasSeq!(now, siotaImpl!(to, now+1)); }
}
