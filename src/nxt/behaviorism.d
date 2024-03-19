/** Introspection of interface and in turn behaviour.

	Enables

	- Automatic Behaviour Visualization
	- Automatic Test Stub Construction
 */
module nxt.behaviorism;

/** TODO: Use std.typecons.Flag
 */
enum Behaviour
{
	mutating,
	reordering,
	sorting,
	shuffling,
	subset,
}

alias Dimensionality = uint;
