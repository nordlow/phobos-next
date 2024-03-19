/** Array where conseuctive elements are grouped into buckets.
 *
 * Bucket size is typically a power of two.
 *
 * Presence of elements in a bucket are specified by an occupancy mask.
 *
 * Each element in that bucket is allocated separately using an allocator. Each
 * bucket remains allocated until all elements have been removed (the occupancy
 * mask has been zeroed).
 *
 * See_Also: UnrolledList at
 * https://github.com/dlang-community/containers/blob/master/src/containers/unrolledlist.d.
 *
 * See_Also: https://www.youtube.com/watch?v=QX46eLqq1ps
*/
module nxt.container.bucket_array;
