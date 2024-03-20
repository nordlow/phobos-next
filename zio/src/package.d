/** File I/O of Compressed Files.
 *
 * See_Also: https://forum.dlang.org/post/jykarqycnrecajveqpos@forum.dlang.org
 */
module nxt.zio;

import nxt.path : Path, FilePath;

version = benchmark_zio;

@safe:

struct GzipFileInputRange
{
	import std.stdio : File;
	import std.traits : ReturnType;

	static immutable chunkSize = 0x4000;	/+ TODO: find optimal value via benchmark +/
	static immutable defaultExtension = `.gz`;

	this(in FilePath path) @trusted
	{
		_f = File(path.str, `r`);
		_chunkRange = _f.byChunk(chunkSize);
		_uncompress = new UnCompress;
		loadNextChunk();
	}

	void loadNextChunk() @trusted
	{
		if (!_chunkRange.empty)
		{
			_uncompressedBuf = cast(ubyte[])_uncompress.uncompress(_chunkRange.front);
			_chunkRange.popFront();
		}
		else
		{
			if (!_exhausted)
			{
				_uncompressedBuf = cast(ubyte[])_uncompress.flush();
				_exhausted = true;
			}
			else
			{
				_uncompressedBuf.length = 0;
			}
		}
		_bufIx = 0;
	}

	void popFront()
	{
		_bufIx += 1;
		if (_bufIx >= _uncompressedBuf.length)
		{
			loadNextChunk();
		}
	}

pragma(inline, true):
pure nothrow @safe @nogc:

	@property ubyte front() const
	{
		return _uncompressedBuf[_bufIx];
	}

	bool empty() const @property
	{
		return _uncompressedBuf.length == 0;
	}

private:
	import std.zlib : UnCompress;
	UnCompress _uncompress;
	File _f;
	ReturnType!(_f.byChunk) _chunkRange;
	bool _exhausted;			///< True if exhausted.
	ubyte[] _uncompressedBuf;   ///< Uncompressed buffer.
	size_t _bufIx;			  ///< Current byte index into `_uncompressedBuf`.
}

/** Is `true` iff `R` is a block input range.
	TODO: Move to std.range
 */
private template isBlockInputRange(R)
{
	import std.range.primitives : isInputRange;
	enum isBlockInputRange = (isInputRange!R &&
							  __traits(hasMember, R, `bufferFrontChunk`) && /+ TODO: ask dlang for better naming +/
							  __traits(hasMember, R, `loadNextChunk`));	 /+ TODO: ask dlang for better naming +/
}

/** Decompress `BlockInputRange` linewise.
 */
class DecompressByLine(BlockInputRange)
{
	private alias E = char;

	/** If `range` is of type `isBlockInputRange` decoding compressed files will
	 * be much faster.
	 */
	this(in FilePath path,
		 E separator = '\n',
		 in size_t initialCapacity = 80)
	{
		this._range = typeof(_range)(path);
		this._separator = separator;
		static if (__traits(hasMember, typeof(_lbuf), `withCapacity`))
			this._lbuf = typeof(_lbuf).withCapacity(initialCapacity);
		popFront();
	}

	void popFront() @trusted
	{
		_lbuf.shrinkTo(0);

		static if (isBlockInputRange!(typeof(_range)))
		{
			/+ TODO: functionize +/
			while (!_range.empty)
			{
				ubyte[] currentFronts = _range.bufferFrontChunk;
				// `_range` is mutable so sentinel-based search can kick

				static immutable useCountUntil = false;
				static if (useCountUntil)
				{
					import std.algorithm.searching : countUntil;
					// TODO
				}
				else
				{
					import std.algorithm.searching : find;
					const hit = currentFronts.find(_separator); // or use `indexOf`
				}

				if (hit.length)
				{
					const lineLength = hit.ptr - currentFronts.ptr;
					_lbuf.put(currentFronts[0 .. lineLength]); // add everything up to separator
					_range._bufIx += lineLength + _separator.sizeof; // advancement + separator
					if (_range.empty)
						_range.loadNextChunk();
					break;	  // done
				}
				else			// no separator yet
				{
					_lbuf.put(currentFronts); // so just add everything
					_range.loadNextChunk();
				}
			}
		}
		else
		{
			/+ TODO: sentinel-based search for `_separator` in `_range` +/
			while (!_range.empty &&
				   _range.front != _separator)
			{
				_lbuf.put(_range.front);
				_range.popFront();
			}

			if (!_range.empty &&
				_range.front == _separator)
			{
				_range.popFront();  // pop separator
			}
		}
	}

	pragma(inline):
	pure nothrow @safe @nogc:

	bool empty() const @property
	{
		return _lbuf.data.length == 0;
	}

	const(E)[] front() const return scope
	{
		return _lbuf.data;
	}

private:
	BlockInputRange _range;

	import std.array : Appender;
	Appender!(E[]) _lbuf;	   // line buffer

	// NOTE this is slower for ldc:
	// import nxt.container.dynamic_array : Array;
	// Array!E _lbuf;

	E _separator;
}

class GzipOut
{
	import std.zlib: Compress, HeaderFormat;
	import std.stdio: File;

	this(File file) @trusted
	{
		_f = file;
		_compress = new Compress(HeaderFormat.gzip);
	}

	void compress(const string s) @trusted
	{
		auto compressed = _compress.compress(s);
		_f.rawWrite(compressed);
	}

	void finish() @trusted
	{
		auto compressed = _compress.flush;
		_f.rawWrite(compressed);
		_f.close;
	}

private:
	Compress _compress;
	File _f;
}

struct ZlibFileInputRange
{
	import std.file : FileException;

	/* Zlib docs:
	   CHUNK is simply the buffer size for feeding data to and pulling data from
	   the zlib routines. Larger buffer sizes would be more efficient,
	   especially for inflate(). If the memory is available, buffers sizes on
	   the order of 128K or 256K bytes should be used.
	*/
	static immutable chunkSize = 128 * 1024; // 128K

	static immutable defaultExtension = `.gz`;

	@safe:

	this(in FilePath path) @trusted
	{
		import std.string : toStringz; /+ TODO: avoid GC allocation by looking at how gmp-d z.d solves it +/
		_f = gzopen(path.str.toStringz, `rb`);
		if (!_f)
			throw new FileException(`Couldn't open file ` ~ path.str.idup);
		_buf = new ubyte[chunkSize];
		loadNextChunk();
	}

	~this() nothrow @trusted @nogc
	{
		const int ret = gzclose(_f);
		if (ret < 0)
			assert(0, `Couldn't close file`); /+ TODO: replace with non-GC-allocated exception +/
	}

	this(this) @disable;

	void loadNextChunk() @trusted
	{
		int count = gzread(_f, _buf.ptr, chunkSize);
		if (count == -1)
			throw new Exception(`Error decoding file`);
		_bufIx = 0;
		_bufReadLength = count;
	}

	void popFront() in(!empty)
	{
		_bufIx += 1;
		if (_bufIx >= _bufReadLength)
		{
			loadNextChunk();
			_bufIx = 0;		 // restart counter
		}
	}

pragma(inline, true):
pure nothrow @nogc:

	@property ubyte front() const @trusted in(!empty) => _buf.ptr[_bufIx];
	bool empty() const @property => _bufIx == _bufReadLength;

	/** Get current bufferFrontChunk.
		TODO: need better name for this
	 */
	inout(ubyte)[] bufferFrontChunk() inout @trusted in(!empty) => _buf.ptr[_bufIx .. _bufReadLength];

private:
	import etc.c.zlib : gzFile, gzopen, gzclose, gzread;

	gzFile _f;

	ubyte[] _buf;			   // block read buffer

	// number of bytes in `_buf` recently read by `gzread`, normally equal to `_buf.length` except after last read where is it's normally less than `_buf.length`
	size_t _bufReadLength;

	size_t _bufIx;			  // current stream read index in `_buf`

	/+ TODO: make this work: +/
	// extern (C) nothrow @nogc:
	// pragma(mangle, `gzopen`) gzFile gzopen(const(char)* path, const(char)* mode);
	// pragma(mangle, `gzclose`) int gzclose(gzFile file);
	// pragma(mangle, `gzread`) int gzread(gzFile file, void* buf, uint len);
}

struct Bz2libFileInputRange
{
	import std.file : FileException;

	static immutable chunkSize = 128 * 1024; // 128K. TODO: find optimal value via benchmark
	static immutable defaultExtension = `.bz2`;
	static immutable useGC = false;		 /+ TODO: generalize to allocator parameter +/

@safe:

	this(in FilePath path) @trusted
	{
		import std.string : toStringz; /+ TODO: avoid GC allocation by looking at how gmp-d z.d solves it +/
		_f = BZ2_bzopen(path.str.toStringz, `rb`);
		if (!_f)
			throw new FileException(`Couldn't open file ` ~ path.str.idup);

		static if (useGC)
			_buf = new ubyte[chunkSize];
		else
		{
			import core.memory : pureMalloc;
			_buf = (cast(ubyte*)pureMalloc(chunkSize))[0 .. chunkSize];
		}

		loadNextChunk();
	}

	~this() nothrow @trusted @nogc
	{
		BZ2_bzclose(_f);	   /+ TODO: error handling? +/

		static if (!useGC)
		{
			import core.memory : pureFree;
			pureFree(_buf.ptr);
		}
	}

	this(this) @disable;

	void loadNextChunk() @trusted
	{
		int count = BZ2_bzread(_f, _buf.ptr, chunkSize);
		if (count == -1)
			throw new Exception(`Error decoding file`);
		_bufIx = 0;
		_bufReadLength = count;
	}

	void popFront() in(!empty)
	{
		_bufIx += 1;
		if (_bufIx >= _bufReadLength)
		{
			loadNextChunk();
			_bufIx = 0;		 // restart counter
		}
	}

	pragma(inline, true):
	pure nothrow @nogc:

	@property ubyte front() const @trusted in(!empty)
		=> _buf.ptr[_bufIx];
	bool empty() const @property
		=> _bufIx == _bufReadLength;

	/** Get current bufferFrontChunk.
		TODO: need better name for this
	 */
	inout(ubyte)[] bufferFrontChunk() inout @trusted in(!empty)
		=> _buf.ptr[_bufIx .. _bufReadLength];

private:
	/* import bzlib : BZFILE, BZ2_bzopen, BZ2_bzread, BZ2_bzwrite, BZ2_bzclose; */
	pragma(lib, `bz2`);			 // Ubuntu: sudo apt-get install libbz2-dev

	BZFILE* _f;

	ubyte[] _buf;			   // block read buffer

	// number of bytes in `_buf` recently read by `gzread`, normally equal to `_buf.length` except after last read where is it's normally less than `_buf.length`
	size_t _bufReadLength;

	size_t _bufIx;			  // current stream read index in `_buf`
}

private void testInputRange(FileInputRange)() @safe
if (isInputRange!FileInputRange)
{
	import std.stdio : File;

	const path = FilePath(`test` ~ FileInputRange.defaultExtension);

	const data = "abc\ndef\nghi"; // contents of source

	foreach (const n; data.length .. data.length) /+ TODO: from 0 +/
	{
		const source = data[0 .. n]; // slice from the beginning

		scope of = new GzipOut(File(path.str, `w`));
		of.compress(source);
		of.finish();

		size_t ix = 0;
		foreach (e; FileInputRange(path))
		{
			assert(cast(char)e == source[ix]);
			++ix;
		}

		import std.algorithm.searching : count;
		import std.algorithm.iteration : splitter;
		alias R = DecompressByLine!ZlibFileInputRange;

		assert(new R(path).count == source.splitter('\n').count);
	}
}

///
@safe unittest {
	testInputRange!(GzipFileInputRange);
	testInputRange!(ZlibFileInputRange);
	testInputRange!(Bz2libFileInputRange);
}

/** Read Age of Aqcuisitions.
 */
static private void testReadAgeofAqcuisitions(in Path rootDirPath = Path(`~/Work/knet/knowledge/en/age-of-aqcuisition`)) @safe
{
	import std.path: expandTilde;
	import nxt.zio : DecompressByLine, GzipFileInputRange;
	import std.path : buildNormalizedPath;

	{
		const path = FilePath(buildNormalizedPath(rootDirPath.str.expandTilde, `AoA_51715_words.csv.gz`));
		size_t count = 0;
		foreach (line; new DecompressByLine!GzipFileInputRange(path))
			count += 1;
		assert(count == 51716);
	}

	{
		const path = FilePath(buildNormalizedPath(rootDirPath.str.expandTilde, `AoA_51715_words.csv.gz`));
		size_t count = 0;
		foreach (line; new DecompressByLine!ZlibFileInputRange(path))
			count += 1;
		assert(count == 51716);
	}

	{
		const path = FilePath(buildNormalizedPath(rootDirPath.str.expandTilde, `AoA_51715_words_copy.csv.bz2`));
		size_t count = 0;
		foreach (line; new DecompressByLine!Bz2libFileInputRange(path))
			count += 1;
		assert(count == 51716);
	}
}

/** Read Concept 5 assertions.
 */
static private void testReadConcept5Assertions(in FilePath path = FilePath(`/home/per/Knowledge/ConceptNet5/latest/conceptnet-assertions-5.6.0.csv.gz`)) @safe
{
	alias R = ZlibFileInputRange;

	import std.stdio: writeln;
	import std.range: take;
	import std.algorithm.searching: count;

	const lineBlockCount = 100_000;
	size_t lineNr = 0;
	foreach (const line; new DecompressByLine!R(path))
	{
		if (lineNr % lineBlockCount == 0)
			writeln(`Line `, lineNr, ` read containing:`, line);
		lineNr += 1;
	}

	const lineCount = 5;
	foreach (const line; new DecompressByLine!R(path).take(lineCount))
		writeln(line);
}

/// benchmark DBpedia parsing
version (benchmark_zio)
static private void benchmarkDbpediaParsing(in Path rootPath = Path(`/home/per/Knowledge/DBpedia/latest`)) @system
{
	alias R = Bz2libFileInputRange;

	import nxt.algorithm.searching : startsWith, endsWith;
	import std.algorithm : filter;
	import std.file : dirEntries, SpanMode;
	import std.path : baseName;
	import std.stdio : write, writeln, stdout;
	import std.datetime : MonoTime;

	foreach (const pathStr; dirEntries(rootPath.str, SpanMode.depth).filter!(file => (file.name.baseName.startsWith(`instance_types`) &&
																			   file.name.endsWith(`.ttl.bz2`))))
	{
		write(`Checking `, pathStr, ` ... `); stdout.flush();

		immutable before = MonoTime.currTime();

		size_t lineCounter = 0;
		foreach (const line; new DecompressByLine!R(FilePath(pathStr)))
			lineCounter += 1;

		immutable after = MonoTime.currTime();

		showStat(pathStr, before, after, lineCounter);
	}
}

/// Show statistics.
static private void showStat(T)(in const(char[]) tag,
								in T before,
								in T after,
								in size_t lineCount)
{
	import std.stdio : writefln;
	writefln(`%s: %3.1f msecs (%3.1f usecs/line)`,
			 tag,
			 cast(double)(after - before).total!`msecs`,
			 cast(double)(after - before).total!`usecs` / lineCount);
}

version (unittest)
{
	import std.range.primitives : isInputRange;
}

pragma(lib, "bz2");			 // Ubuntu: sudo apt-get install libbz2-dev

extern(C) nothrow @nogc:

enum BZ_RUN			   = 0;
enum BZ_FLUSH			 = 1;
enum BZ_FINISH			= 2;

enum BZ_OK				= 0;
enum BZ_RUN_OK			= 1;
enum BZ_FLUSH_OK		  = 2;
enum BZ_FINISH_OK		 = 3;
enum BZ_STREAM_END		= 4;
enum BZ_SEQUENCE_ERROR	= -1;
enum BZ_PARAM_ERROR	   = -2;
enum BZ_MEM_ERROR		 = -3;
enum BZ_DATA_ERROR		= -4;
enum BZ_DATA_ERROR_MAGIC  = -5;
enum BZ_IO_ERROR		  = -6;
enum BZ_UNEXPECTED_EOF	= -7;
enum BZ_OUTBUFF_FULL	  = -8;
enum BZ_CONFIG_ERROR	  = -9;

struct bz_stream
{
	ubyte* next_in;
	uint   avail_in;
	uint   total_in_lo32;
	uint   total_in_hi32;

	ubyte* next_out;
	uint   avail_out;
	uint   total_out_lo32;
	uint   total_out_hi32;

	void*  state;

	void* function(void*, int, int) nothrow bzalloc;
	void  function(void*, void*) nothrow	bzfree;
	void* opaque;
}

/*-- Core (low-level) library functions --*/

int BZ2_bzCompressInit(bz_stream* strm,
					   int		blockSize100k,
					   int		verbosity,
					   int		workFactor);

int BZ2_bzCompress(bz_stream* strm,
				   int action);

int BZ2_bzCompressEnd(bz_stream* strm);

int BZ2_bzDecompressInit(bz_stream* strm,
						 int		verbosity,
						 int		small);

int BZ2_bzDecompress(bz_stream* strm);

int BZ2_bzDecompressEnd(bz_stream *strm);

/*-- High(er) level library functions --*/

version (BZ_NO_STDIO) {}
else
{
	import core.stdc.stdio;

	enum BZ_MAX_UNUSED = 5000;

	struct BZFILE;

	BZFILE* BZ2_bzReadOpen(int*  bzerror,
						   FILE* f,
						   int   verbosity,
						   int   small,
						   void* unused,
						   int   nUnused);

	void BZ2_bzReadClose(int*	bzerror,
						 BZFILE* b);

	void BZ2_bzReadGetUnused(int*	bzerror,
							 BZFILE* b,
							 void**  unused,
							 int*	nUnused);

	int BZ2_bzRead(int*	bzerror,
				   BZFILE* b,
				   void*   buf,
				   int	 len);

	BZFILE* BZ2_bzWriteOpen(int*  bzerror,
							FILE* f,
							int   blockSize100k,
							int   verbosity,
							int   workFactor
		);

	void BZ2_bzWrite(int*	bzerror,
					 BZFILE* b,
					 void*   buf,
					 int	 len);

	void BZ2_bzWriteClose(int*		  bzerror,
						  BZFILE*	   b,
						  int		   abandon,
						  uint*		 nbytes_in,
						  uint*		 nbytes_out);

	void BZ2_bzWriteClose64(int*		  bzerror,
							BZFILE*	   b,
							int		   abandon,
							uint*		 nbytes_in_lo32,
							uint*		 nbytes_in_hi32,
							uint*		 nbytes_out_lo32,
							uint*		 nbytes_out_hi32);
}

/*-- Utility functions --*/

int BZ2_bzBuffToBuffCompress(ubyte*		dest,
							 uint*		 destLen,
							 ubyte*		source,
							 uint		  sourceLen,
							 int		   blockSize100k,
							 int		   verbosity,
							 int		   workFactor);

int BZ2_bzBuffToBuffDecompress(ubyte*		dest,
							   uint*		 destLen,
							   ubyte*		source,
							   uint		  sourceLen,
							   int		   small,
							   int		   verbosity);


/*--
  Code contributed by Yoshioka Tsuneo (tsuneo@rr.iij4u.or.jp)
  to support better zlib compatibility.
  This code is not _officially_ part of libbzip2 (yet);
  I haven't tested it, documented it, or considered the
  threading-safeness of it.
  If this code breaks, please contact both Yoshioka and me.
  --*/

const(char)* BZ2_bzlibVersion();

BZFILE* BZ2_bzopen(const scope const(char)* path,
				   const scope const(char)* mode);

BZFILE * BZ2_bzdopen(int		  fd,
					 const scope const(char)* mode);

int BZ2_bzread(scope BZFILE* b,
			   scope void*   buf,
			   int	 len);

int BZ2_bzwrite(scope BZFILE* b,
				scope void*   buf,
				int	 len);

int BZ2_bzflush(scope BZFILE* b);

void BZ2_bzclose(scope BZFILE* b);

const(char)* BZ2_bzerror(scope BZFILE *b,
						 int	*errnum);
