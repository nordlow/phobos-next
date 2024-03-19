module nxt.region;

/++ File|Data Region.
 +/
struct Region {
	import nxt.offset : Offset;
	Offset start;
	Offset end;
}
