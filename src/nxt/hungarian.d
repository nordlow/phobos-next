module nxt.hungarian;

version (none):					/+ TODO: activate +/

/// Origin: http://fantascienza.net/leonardo/so/hungarian.d.

/* Copyright (c) 2012 Kevin L. Stern
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * An implementation of the Hungarian algorithm for solving the assignment
 * problem. An instance of the assignment problem consists of a number of
 * workers along with a number of jobs and a cost matrix which gives the cost of
 * assigning the i'th worker to the j'th job at position (i, j). The goal is to
 * find an assignment of workers to jobs so that no job is assigned more than
 * one worker and so that no worker is assigned to more than one job in such a
 * manner so as to minimize the total cost of completing the jobs.
 * <p>
 *
 * An assignment for a cost matrix that has more workers than jobs will
 * necessarily include unassigned workers, indicated by an assignment value of
 * -1; in no other circumstance will there be unassigned workers. Similarly, an
 * assignment for a cost matrix that has more jobs than workers will necessarily
 * include unassigned jobs; in no other circumstance will there be unassigned
 * jobs. For completeness, an assignment for a square cost matrix will give
 * exactly one unique worker to each job.
 *
 * This version of the Hungarian algorithm runs in time O(n^3), where n is the
 * maximum among the number of workers and the number of jobs.
 *
 * @author Kevin L. Stern
 *
 * Ported to D language, Oct 8 2012 V.1.2, by leonardo maffi.
 */
struct HungarianAlgorithm(T) {
	import std.algorithm: max;
	import std.traits: isFloatingPoint;

	static if (isFloatingPoint!T)
		enum T infinity = T.infinity;
	else
		enum T infinity = T.max; // Doesn't work with Bigint.

	private T[][] costMatrix;
	private int rows, cols, dim;
	private T[] labelByWorker, labelByJob, minSlackValueByJob;
	private int[] minSlackWorkerByJob, matchJobByWorker,
				  matchWorkerByJob, parentWorkerByCommittedJob;
	private bool[] committedWorkers;

	/**
	 * Construct an instance of the algorithm and Execute the algorithm.
	 *
	 * @param costMatrix
	 *			the cost matrix, where matrix[i][j] holds the cost of
	 *			assigning worker i to job j, for all i, j. The cost matrix
	 *			must not be irregular in the sense that all rows must be the
	 *			same length.
	 *
	 * @return the minimum cost matching of workers to jobs based upon the
	 *		 provided cost matrix. A matching value of -1 indicates that the
	 *		 corresponding worker is unassigned.
	 */
	public static int[] opCall(in T[][] costMatrix_)
	pure /*nothrow*/
	in(costMatrix_.length > 0)
	in
	{
		foreach (row; costMatrix_) // is rectangular
			assert(row.length == costMatrix_[0].length);
	}
	do
	{
		HungarianAlgorithm self;
		self.dim = max(costMatrix_.length, costMatrix_[0].length);
		self.rows = costMatrix_.length;
		self.cols = costMatrix_[0].length;
		self.costMatrix = new T[][](self.dim, self.dim);

		foreach (w; 0 .. self.dim)
			if (w < costMatrix_.length)
				self.costMatrix[w] = copyOf(costMatrix_[w], self.dim);
			else
				self.costMatrix[w][] = 0; // For Java semantics.

		self.labelByWorker.length = self.dim;
		self.labelByWorker[] = 0; // Necessary to follow Java semantics.
		self.labelByJob.length = self.dim;
		self.minSlackWorkerByJob.length = self.dim;
		self.minSlackValueByJob.length = self.dim;
		self.committedWorkers.length = self.dim;
		self.parentWorkerByCommittedJob.length = self.dim;
		self.matchJobByWorker.length = self.dim;
		self.matchJobByWorker[] = -1;
		self.matchWorkerByJob.length = self.dim;
		self.matchWorkerByJob[] = -1;

		/*
		 * Heuristics to improve performance: Reduce rows and columns by their
		 * smallest element, compute an initial non-zero dual feasible solution
		 * and create a greedy matching from workers to jobs of the cost matrix.
		 */
		self.reduce();
		self.computeInitialFeasibleSolution();
		self.greedyMatch();

		auto w = self.fetchUnmatchedWorker();
		while (w < self.dim) {
			self.initializePhase(w);
			self.executePhase();
			w = self.fetchUnmatchedWorker();
		}
		auto result = copyOf(self.matchJobByWorker, self.rows);
		foreach (ref r; result)
			if (r >= self.cols)
				r = -1;
		return result;
	}

	static T[] copyOf(T)(in T[] input, in size_t size) pure /*nothrow*/ {
		if (size <= input.length)
			return input[0 .. size].dup;
		else {
			auto result = new T[size];
			result[0 .. input.length] = input[];
			result[input.length .. $] = 0; // Necessary to follow Java semantics.
			return result;
		}
	}

	/**
	 * Compute an initial feasible solution by assigning zero labels to the
	 * workers and by assigning to each job a label equal to the minimum cost
	 * among its incident edges.
	 */
	void computeInitialFeasibleSolution() pure nothrow {
		labelByJob[] = infinity;
		foreach (w, row; costMatrix)
			foreach (j, rj; row)
				if (rj < labelByJob[j])
					labelByJob[j] = rj;
	}

	/**
	 * Execute a single phase of the algorithm. A phase of the Hungarian
	 * algorithm consists of building a set of committed workers and a set of
	 * committed jobs from a root unmatched worker by following alternating
	 * unmatched/matched zero-slack edges. If an unmatched job is encountered,
	 * then an augmenting path has been found and the matching is grown. If the
	 * connected zero-slack edges have been exhausted, the labels of committed
	 * workers are increased by the minimum slack among committed workers and
	 * non-committed jobs to create more zero-slack edges (the labels of
	 * committed jobs are simultaneously decreased by the same amount in order
	 * to maintain a feasible labeling).
	 *
	 * The runtime of a single phase of the algorithm is O(n^2), where n is the
	 * dimension of the internal square cost matrix, since each edge is visited
	 * at most once and since increasing the labeling is accomplished in time
	 * O(n) by maintaining the minimum slack values among non-committed jobs.
	 * When a phase completes, the matching will have increased in size.
	 */
	void executePhase() pure nothrow {
		while (true) {
			int minSlackWorker = -1, minSlackJob = -1;
			auto minSlackValue = infinity;
			foreach (j, pj; parentWorkerByCommittedJob)
				if (pj == -1)
					if (minSlackValueByJob[j] < minSlackValue) {
						minSlackValue = minSlackValueByJob[j];
						minSlackWorker = minSlackWorkerByJob[j];
						minSlackJob = j;
					}

			if (minSlackValue > 0)
				updateLabeling(minSlackValue);
			parentWorkerByCommittedJob[minSlackJob] = minSlackWorker;
			if (matchWorkerByJob[minSlackJob] == -1) {
				// An augmenting path has been found.
				int committedJob = minSlackJob;
				int parentWorker = parentWorkerByCommittedJob[committedJob];
				while (true) {
					immutable temp = matchJobByWorker[parentWorker];
					match(parentWorker, committedJob);
					committedJob = temp;
					if (committedJob == -1)
						break;
					parentWorker = parentWorkerByCommittedJob[committedJob];
				}
				return;
			} else {
				// Update slack values since we increased the size of the
				// committed workers set.
				immutable int worker = matchWorkerByJob[minSlackJob];
				committedWorkers[worker] = true;
				for (int j = 0; j < dim; j++) { // Performance-critical.
					if (parentWorkerByCommittedJob[j] == -1) {
						immutable slack = cast(T)(costMatrix[worker][j] -
												  labelByWorker[worker] -
												  labelByJob[j]);
						if (minSlackValueByJob[j] > slack) {
							minSlackValueByJob[j] = slack;
							minSlackWorkerByJob[j] = worker;
						}
					}
				}
			}
		}
	}

	/**
	 *
	 * @return the first unmatched worker or {@link #dim} if none.
	 */
	int fetchUnmatchedWorker() const pure nothrow {
		foreach (w, mw; matchJobByWorker)
			if (mw == -1)
				return w;
		return dim;
	}

	/**
	 * Find a valid matching by greedily selecting among zero-cost matchings.
	 * This is a heuristic to jump-start the augmentation algorithm.
	 */
	void greedyMatch() pure nothrow {
		foreach (w, row; costMatrix)
			foreach (j, rj; row)
				if (matchJobByWorker[w] == -1
						&& matchWorkerByJob[j] == -1
						&& rj - labelByWorker[w] - labelByJob[j] == 0)
					match(w, j);
	}

	/**
	 * Initialize the next phase of the algorithm by clearing the committed
	 * workers and jobs sets and by initializing the slack arrays to the values
	 * corresponding to the specified root worker.
	 *
	 * @param w
	 *			the worker at which to root the next phase.
	 */
	void initializePhase(in int w) pure nothrow {
		committedWorkers[] = false;
		parentWorkerByCommittedJob[] = -1;
		committedWorkers[w] = true;
		foreach (j, ref mj; minSlackValueByJob) {
			mj = cast(T)(costMatrix[w][j] - labelByWorker[w] - labelByJob[j]);
			minSlackWorkerByJob[j] = w;
		}
	}

	/**
	 * Helper method to record a matching between worker w and job j.
	 */
	void match(in int w, in int j) pure nothrow {
		matchJobByWorker[w] = j;
		matchWorkerByJob[j] = w;
	}

	/**
	 * Reduce the cost matrix by subtracting the smallest element of each row
	 * from all elements of the row as well as the smallest element of each
	 * column from all elements of the column. Note that an optimal assignment
	 * for a reduced cost matrix is optimal for the original cost matrix.
	 */
	void reduce() pure /*nothrow*/ {
		foreach (ref row; costMatrix) {
			auto min = infinity;
			foreach (r; row)
				if (r < min)
					min = r;
			row[] -= min;
		}
		auto min = new T[dim];
		min[] = infinity;
		foreach (row; costMatrix)
			foreach (j, rj; row)
				if (rj < min[j])
					min[j] = rj;
		foreach (row; costMatrix)
			row[] -= min[];
	}

	/**
	 * Update labels with the specified slack by adding the slack value for
	 * committed workers and by subtracting the slack value for committed jobs.
	 * In addition, update the minimum slack values appropriately.
	 */
	void updateLabeling(in T slack) pure nothrow {
		foreach (w, cw; committedWorkers)
			if (cw)
				labelByWorker[w] += slack;
		foreach (j, pj; parentWorkerByCommittedJob)
			if (pj != -1)
				labelByJob[j] -= slack;
			else
				minSlackValueByJob[j] -= slack;
	}
}


//void main() {
unittest {
	import std.stdio, std.random, std.datetime, std.exception, core.exception,
		   std.typecons, std.range, std.algorithm, std.typetuple;

//	{
//		version (assert) {
//			const double[][] mat0 = [];
//			assertThrown!(AssertError)(HungarianAlgorithm!double(mat0));
//		}
//	}

	{
		const double[][] mat0 = [[], []];
		const r0 = HungarianAlgorithm!double(mat0);
		assert(r0 == [-1, -1]);
	}

	{
		const double[][] mat0 = [[1]];
		const r0 = HungarianAlgorithm!double(mat0);
		assert(r0 == [0]);
	}

	{
		const double[][] mat0 = [[1], [1]];
		const r0 = HungarianAlgorithm!double(mat0);
		assert(r0 == [0, -1]);
	}

	{
		const double[][] mat0 = [[1, 1]];
		const r0 = HungarianAlgorithm!double(mat0);
		assert(r0 == [0]);
	}

	{
		const double[][] mat0 = [[1, 1], [1, 1]];
		const r0 = HungarianAlgorithm!double(mat0);
		assert(r0 == [0, 1]);
	}

	{
		const double[][] mat0 = [[1, 1], [1, 1], [1, 1]];
		const r0 = HungarianAlgorithm!double(mat0);
		assert(r0 == [0, 1, -1]);
	}


	{
		const double[][] mat0 = [[1, 2, 3], [6, 5, 4]];
		const r0 = HungarianAlgorithm!double(mat0);
		assert(r0 == [0, 2]);
	}

	{
		const double[][] mat0 = [[1, 2, 3], [6, 5, 4], [1, 1, 1]];
		const r0 = HungarianAlgorithm!double(mat0);
		assert(r0 == [0, 2, 1]);
	}


	{
		const int[][] mat0 = [[], []];
		const r0 = HungarianAlgorithm!int(mat0);
		assert(r0 == [-1, -1]);
	}

	{
		const int[][] mat0 = [[1]];
		const r0 = HungarianAlgorithm!int(mat0);
		assert(r0 == [0]);
	}

	{
		const int[][] mat0 = [[1], [1]];
		const r0 = HungarianAlgorithm!int(mat0);
		assert(r0 == [0, -1]);
	}

	{
		const int[][] mat0 = [[1, 1]];
		const r0 = HungarianAlgorithm!int(mat0);
		assert(r0 == [0]);
	}

	{
		const int[][] mat0 = [[1, 1], [1, 1]];
		const r0 = HungarianAlgorithm!int(mat0);
		assert(r0 == [0, 1]);
	}

	{
		const int[][] mat0 = [[1, 1], [1, 1], [1, 1]];
		const r0 = HungarianAlgorithm!int(mat0);
		assert(r0 == [0, 1, -1]);
	}


	{
		const int[][] mat0 = [[1, 2, 3], [6, 5, 4]];
		const r0 = HungarianAlgorithm!int(mat0);
		assert(r0 == [0, 2]);
	}

	{
		const int[][] mat0 = [[1, 2, 3], [6, 5, 4], [1, 1, 1]];
		const r0 = HungarianAlgorithm!int(mat0);
		assert(r0 == [0, 2, 1]);
	}

	{
		int[][] mat1 = [[  7,  53, 183, 439, 863],
						[497, 383, 563,  79, 973],
						[287,  63, 343, 169, 583],
						[627, 343, 773, 959, 943],
						[767, 473, 103, 699, 303]];
		foreach (row; mat1)
			row[] *= -1;
		const r1 = HungarianAlgorithm!int(mat1);
		// Currently doesn't work with -inline:
		//r1.length.iota().map!(r => -mat1[r][r1[r]])().reduce!q{a + b}().writeln();
		int tot1 = 0;
		foreach (i, r1i; r1)
			tot1 -= mat1[i][r1i];
		assert(tot1 == 3315);
	}

	{
		// Euler Problem 345:
		// http://projecteuler.net/index.php?section=problems&id=345
		int [][] mat2 = [
		[  7,  53, 183, 439, 863, 497, 383, 563,  79, 973, 287,  63, 343, 169, 583],
		[627, 343, 773, 959, 943, 767, 473, 103, 699, 303, 957, 703, 583, 639, 913],
		[447, 283, 463,  29,  23, 487, 463, 993, 119, 883, 327, 493, 423, 159, 743],
		[217, 623,   3, 399, 853, 407, 103, 983,  89, 463, 290, 516, 212, 462, 350],
		[960, 376, 682, 962, 300, 780, 486, 502, 912, 800, 250, 346, 172, 812, 350],
		[870, 456, 192, 162, 593, 473, 915,  45, 989, 873, 823, 965, 425, 329, 803],
		[973, 965, 905, 919, 133, 673, 665, 235, 509, 613, 673, 815, 165, 992, 326],
		[322, 148, 972, 962, 286, 255, 941, 541, 265, 323, 925, 281, 601,  95, 973],
		[445, 721,  11, 525, 473,  65, 511, 164, 138, 672,  18, 428, 154, 448, 848],
		[414, 456, 310, 312, 798, 104, 566, 520, 302, 248, 694, 976, 430, 392, 198],
		[184, 829, 373, 181, 631, 101, 969, 613, 840, 740, 778, 458, 284, 760, 390],
		[821, 461, 843, 513,  17, 901, 711, 993, 293, 157, 274,  94, 192, 156, 574],
		[ 34, 124,   4, 878, 450, 476, 712, 914, 838, 669, 875, 299, 823, 329, 699],
		[815, 559, 813, 459, 522, 788, 168, 586, 966, 232, 308, 833, 251, 631, 107],
		[813, 883, 451, 509, 615,  77, 281, 613, 459, 205, 380, 274, 302,  35, 805]];
		foreach (row; mat2)
			row[] *= -1;
		const r2 = HungarianAlgorithm!int(mat2);
		int tot2 = 0;
		foreach (i, r2i; r2)
			tot2 -= mat2[i][r2i];
		assert(tot2 == 13938); // Euler Problem 345 solution.
	}

	static T[][] genMat(T)(in int N, in int M, in int seed) {
		rndGen.seed(seed);
		auto mat = new T[][](N, M);
		foreach (row; mat)
			foreach (ref x; row)
				static if (is(T == short))
					x = uniform(cast(T)10, cast(T)500);
				else
					x = uniform(cast(T)10, cast(T)5_000);
		return mat;
	}

	// Steinhaus-Johnson-Trotter permutations algorithm
	static struct Spermutations {
		const int n;
		alias Tuple!(int[], int) TResult;

		int opApply(int delegate(ref TResult) dg) {
			int result;
			TResult aux;

			int sign = 1;
			alias Tuple!(int, int) Pair;
			//auto p = iota(n).map!(i => Pair(i, i ? -1 : 0))().array();
			auto p = array(map!(i => Pair(i, i ? -1 : 0))(iota(n)));

			aux = tuple(array(map!(pp => pp[0])(p)), sign);
			result = dg(aux); if (result) goto END;

			while (canFind!(pp => pp[1])(p)) {
				// Failed using std.algorithm here, too much complex
				auto largest = Pair(-100, -100);
				int i1 = -1;
				foreach (i, pp; p)
					if (pp[1]) {
						if (pp[0] > largest[0]) {
							i1 = i;
							largest = pp;
						}
					}
				int n1 = largest[0], d1 = largest[1];

				sign *= -1;
				int i2;
				if (d1 == -1) {
					i2 = i1 - 1;
					swap(p[i1], p[i2]);
					if (i2 == 0 || p[i2 - 1][0] > n1)
						p[i2][1] = 0;
				} else if (d1 == 1) {
					i2 = i1 + 1;
					swap(p[i1], p[i2]);
					if (i2 == n - 1 || p[i2 + 1][0] > n1)
						p[i2][1] = 0;
				}
				aux = tuple(array(map!(pp => pp[0])(p)), sign);
				result = dg(aux); if (result) goto END;

				foreach (i3, ref pp; p) {
					auto n3 = pp[0], d3 = pp[1];
					if (n3 > n1)
						pp[1] = (i3 < i2) ? 1 : -1;
				}
			}

			END: return result;
		}
	}

	static T bruteForceSolver(T)(in T[][] mat) /*pure nothrow*/
	in(mat.length > 0)
	in
	{
		// Currently works only with square matrices.
		foreach (row; mat) // Is square.
			assert(row.length == mat.length);
	}
	do
	{
		auto maxTotal = -T.max;
		foreach (p; Spermutations(mat.length)) {
			T total = 0;
			foreach (i, pi; p[0])
				total += mat[i][pi];
			maxTotal = max(maxTotal, total);
		}
		return maxTotal;
	}

	foreach (T; TypeTuple!(double, int, float, short, long)) {
		// Fuzzy test.
		foreach (test; 0 .. 10) {
			auto mat3 = genMat!T(2 + test % 8, 2 + test % 8, test);
			foreach (row; mat3)
				row[] *= -1;
			const r3 = HungarianAlgorithm!T(mat3);
			T tot3 = 0;
			foreach (i, r3i; r3)
				tot3 -= mat3[i][r3i];
			foreach (row; mat3)
				row[] *= -1;
			assert(tot3 == bruteForceSolver(mat3));
		}
	}

	version (hungarian_benchmark) {
		foreach (T; TypeTuple!(double, int, float, short, long)) {
			auto mat4 = genMat!T(2_000, 2_000, 0);
			StopWatch sw;
			sw.start();
			const r4 = HungarianAlgorithm!T(mat4);
			sw.stop();
			writefln("Type %s, milliseconds: %d",
					 T.stringof, sw.peek().msecs);
		}
		/*
		Type double, milliseconds: 1032
		Type int, milliseconds: 834
		Type float, milliseconds: 859
		Type short, milliseconds: 9221
		Type long, milliseconds: 1306
		*/
	}
}

//void main() {}
