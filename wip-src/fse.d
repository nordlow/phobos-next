/**
   File Scanning Engine.

   Make rich use of Sparse Distributed Representations (SDR) using Hash Digests
   for relating Data and its Relations/Properties/Meta-Data.

   See_Also: http://stackoverflow.com/questions/12629749/how-does-grep-run-so-fast
   See_Also: http:www.regular-expressions.info/powergrep.html
   See_Also: http://ridiculousfish.com/blog/posts/old-age-and-treachery.html
   See_Also: http://www.olark.com/spw/2011/08/you-can-list-a-directory-with-8-million-files-but-not-with-ls/

   TODO: Make use parallelism_ex: pmap

   TODO: Call filterUnderAnyOfPaths using std.algorithm.filter directly on AAs. Use byPair or use AA.get(key, defaultValue)
		 See_Also: http://forum.dlang.org/thread/mailman.75.1392335793.6445.digitalmars-d-learn@puremagic.com
		 See_Also: https://github.com/D-Programming-Language/druntime/pull/574

   TODO: Count logical lines.
   TODO: Lexers should be loosely coupled to FKinds instead of Files
   TODO: Generic Token[] and specific CToken[], CxxToken[]

   TODO: Don't scan for duplicates inside vc-dirs by default

   TODO: Assert that files along duplicates path don't include symlinks

   TODO: Implement FOp.deduplicate
   TODO: Prevent rescans of duplicates

   TODO: Defined generalized_specialized_two_way_relationship(kindD, kindDi)

   TODO: Visualize hits using existingFileHitContext.asH!1 followed by a table:
		 ROW_NR | hit string in <code lang=LANG></code>

   TODO: Parse and Sort GCC/Clang Compiler Messages on WARN_TYPE FILE:LINE:COL:MSG[WARN_TYPE] and use Collapsable HTML Widgets:
		 http://api.jquerymobile.com/collapsible/
		 when presenting them

   TODO: Maybe make use of https://github.com/Abscissa/scriptlike

   TODO: Calculate Tree grams and bist

   TODO: Get stats of the link itself not the target in SymLink constructors

   TODO: RegFile with FileContent.text should be decodable to Unicode using
   either iso-latin1, utf-8, etc. Check std.uni for how to try and decode stuff.

   TODO: Search for subwords.
   For example gtk_widget should also match widget_gtk and GtkWidget etc.

   TODO: Support multi-line keys

   TODO: Use hash-lookup in txtFKinds.byExt for faster guessing of source file
   kind. Merge it with binary kind lookup. And check FileContent member of
   kind to instead determine if it should be scanned or not.
   Sub-Task: Case-Insensitive Matching of extensions if
   nothing else passes.

   TODO: Detect symlinks with duplicate targets and only follow one of them and
   group them together in visualization

   TODO: Add addTag, removeTag, etc and interface to fs.d for setting tags:
   --add-tag=comedy, remove-tag=comedy

   TODO: If files ends with ~ or .backup assume its a backup file, strip it from
   end match it again and set backupFlag in FileKind

   TODO: Acronym match can make use of normal histogram counts. Check denseness
   of binary histogram (bist) to determine if we should use a sparse or dense
   histogram.

   TODO: Activate and test support for ELF and Cxx11 subkinds

   TODO: Call either File.checkObseleted upon inotify. checkObseleted should remove stuff from hash tables
   TODO: Integrate logic in clearCStat to RegFile.makeObselete
   TODO: Upon Dir inotify call invalidate _depth, etc.

   TODO: Following command: fs.d --color -d ~/ware/emacs -s lispy  -k
   shows "Skipped PNG file (png) at first extension try".
   Assure that this logic reuses cache and instead prints something like "Skipped PNG file using cached FKind".

   TODO: Cache each Dir separately to a file named after SHA1 of its path

   TODO: Add ASCII kind: Requires optional stream analyzer member of FKind in
   replacement for magicData. ASCIIFile

   TODO: Defined NotAnyKind(binaryKinds) and cache it

   TODO: Create PkZipFile() in Dir.load() when FKind "pkZip Archive" is found.
   Use std.zip.ZipArchive(void[] from mmfile)

   TODO: Scan Subversion Dirs with http://pastebin.com/6ZzPvpBj

   TODO: Change order (binHit || allBHist8Miss) and benchmark

   TODO: Display modification/access times as:
   See: http://forum.dlang.org/thread/k7afq6$2832$1@digitalmars.com

   TODO: Use User Defined Attributes (UDA): http://forum.dlang.org/thread/k7afq6$2832$1@digitalmars.com
   TODO: Use msgPack @nonPacked when needed

   TODO: Limit lines to terminal width

   TODO: Create array of (OFFSET, LENGTH) and this in FKind Pattern factory
   function.  Then for source file extra slice at (OFFSET, LENGTH) and use as
   input into hash-table from magic (if its a Lit-pattern to)

   TODO: Verify that "f.tar.z" gets tuple extensions tuple("tar", "z")
   TODO: Verify that "libc.so.1.2.3" gets tuple extensions tuple("so", "1", "2", "3") and "so" extensions should the be tried
   TODO: Cache Symbols larger than three characters in a global hash from symbol to path

   TODO: Benchmark horspool.d and perhaps use instead of std.find

   TODO: Splitting into keys should not split arguments such as "a b"

   TODO: Perhaps use http://www.chartjs.org/ to visualize stuff

   TODO: Make use of @nonPacked in version (msgpack).
*/
module nxt.fse;

version = msgpack; // Use msgpack serialization
/* version = cerealed; // Use cerealed serialization */

import std.stdio: ioFile = File, stdout;
import std.typecons: Tuple, tuple;
import std.algorithm: find, map, filter, reduce, max, min, uniq, all, joiner;
import std.string: representation, chompPrefix;
import std.stdio: write, writeln, writefln;
import std.path: baseName, dirName, isAbsolute, dirSeparator, extension, buildNormalizedPath, expandTilde, absolutePath;
import std.datetime;
import std.file: FileException;
import std.digest.sha: sha1Of, toHexString;
import std.range: repeat, array, empty, cycle, chain;
import std.stdint: uint64_t;
import std.traits: Unqual, isIterable;
import std.experimental.allocator;
import std.functional: memoize;
import std.complex: Complex;

import nxt.predicates: isUntouched;

import core.memory: GC;
import core.exception;

import nxt.algorithm_ex;
import nxt.attributes;
import nxt.codec;
import nxt.container.static_bitarray;
import nxt.csunits;
import nxt.debugio;
import nxt.digest_ex;
import nxt.elfdoc;
import nxt.find_ex;
import nxt.geometry;
import nxt.getopt_ex;
import nxt.lingua;
import nxt.mangling;
import nxt.mathml;
import nxt.notnull;
import nxt.random_ex;
import nxt.rational: Rational;
import nxt.tempfs;
import nxt.traits_ex;
import nxt.typedoc;

// import arsd.terminal : Color;
// import lock_free.rwqueue;

alias Bytes64 = Bytes!ulong;

import symbolic;
import ngram;
import pretty;

/* NGram Aliases */
/** Not very likely that we are interested in histograms 64-bit precision
 * Bucket/Bin Counts so pick 32-bit for now. */
alias RequestedBinType = uint;
enum NGramOrder = 3;
alias Bist  = NGram!(ubyte, 1, ngram.Kind.binary, ngram.Storage.denseStatic, ngram.Symmetry.ordered, void, immutable(ubyte)[]);
alias XGram = NGram!(ubyte, NGramOrder, ngram.Kind.saturated, ngram.Storage.sparse, ngram.Symmetry.ordered, RequestedBinType, immutable(ubyte)[]);

/* Need for signal handling */
import core.stdc.stdlib;
version (linux) import core.sys.posix.sys.stat;
version (linux) import core.sys.posix.signal;
//version (linux) import std.c.linux.linux;

/* TODO: Set global state.
   http://forum.dlang.org/thread/cu9fgg$28mr$1@digitaldaemon.com
*/
/** Exception Describing Process Signal. */

shared uint ctrlC = 0; // Number of times Ctrl-C has been presed
class SignalCaughtException : Exception
{
	int signo = int.max;
	this(int signo, string file = __FILE__, size_t line = __LINE__ ) @safe {
		this.signo = signo;
		import std.conv: to;
		super(`Signal number ` ~ to!string(signo) ~ ` at ` ~ file ~ `:` ~ to!string(line));
	}
}

void signalHandler(int signo)
{
	import core.atomic: atomicOp;
	if (signo == 2)
	{
		core.atomic.atomicOp!`+=`(ctrlC, 1);
	}
	// throw new SignalCaughtException(signo);
}

alias signalHandler_t = void function(int);
extern (C) signalHandler_t signal(int signal, signalHandler_t handler);

version (msgpack)
{
	import msgpack;
}
version (cerealed)
{
	/* import cerealed.cerealiser; */
	/* import cerealed.decerealiser; */
	/* import cerealed.cereal; */
}

/** File Content Type Code. */
enum FileContent
{
	unknown,
	binaryUnknown,
	binary,
	text,
	textASCII,
	text8Bit,
	document,
	spreadsheet,
	database,
	tagsDatabase,
	image,
	imageIcon,
	audio,
	sound = audio,
	music = audio,

	modemData,
	imageModemFax1BPP, // One bit per pixel
	voiceModem,

	video,
	movie,
	media,
	sourceCode,
	scriptCode,
	buildSystemCode,
	byteCode,
	machineCode,
	versionControl,
	numericalData,
	archive,
	compressed,
	cache,
	binaryCache,
	firmware,
	spellCheckWordList,
	font,
	performanceBenchmark,
	fingerprint,
}

/** How File Kinds are detected. */
enum FileKindDetection
{
	equalsParentPathDirsAndName, // Parenting path file name must match
	equalsName, // Only name must match
	equalsNameAndContents, // Both name and contents must match
	equalsNameOrContents, // Either name or contents must match
	equalsContents, // Only contents must match
	equalsWhatsGiven, // All information defined must match
}

/** Key Scan (Search) Context. */
enum ScanContext
{
	/* code, */
	/* comment, */
	/* string, */

	/* word, */
	/* symbol, */

	dirName,	 // Name of directory being scanned
	dir = dirName,

	fileName,	// Name of file being scanned
	name = fileName,

	regularFilename,	// Name of file being scanned
	symlinkName, // Name of symbolic linke being scanned

	fileContent, // Contents of file being scanned
	content = fileContent,

	/* modTime, */
	/* accessTime, */
	/* xattr, */
	/* size, */

	all,
	standard = all,
}

enum DuplicatesContext
{
	internal, // All duplicates must lie inside topDirs
	external, // At least one duplicate lie inside
	// topDirs. Others may lie outside
}

/** File Operation Type Code. */
enum FOp
{
	none,

	checkSyntax,				// Check syntax
	lint = checkSyntax,		 // Check syntax alias

	build, // Project-Wide Build
	compile, // Compile
	byteCompile, // Byte compile
	run, // Run (Execute)
	execute = run,

	preprocess, // Preprocess C/C++/Objective-C (using cpp)
	cpp = preprocess,

	/* VCS Operations */
	vcStatus,
	vcs = vcStatus,

	deduplicate, // Deduplicate Files using hardlinks and Dirs using Symlink
}

/** Directory Operation Type Code. */
enum DirOp
{
	/* VCS Operations */
	vcStatus,
}

/** Shell Command.
 */
alias ShCmd = string; // Just simply a string for now.

/** Pair of Delimiters.
	Used to desribe for example comment and string delimiter syntax.
 */
struct Delim
{
	this(string intro)
	{
		this.intro = intro;
		this.finish = finish.init;
	}
	this(string intro, string finish)
	{
		this.intro = intro;
		this.finish = finish;
	}
	string intro;
	string finish; // Defaults to end of line if not defined.
}

/* Comment Delimiters */
enum defaultCommentDelims = [Delim(`#`)];
enum cCommentDelims = [Delim(`/*`, `*/`),
					   Delim(`//`)];
enum dCommentDelims = [Delim(`/+`, `+/`)] ~ cCommentDelims;

/* String Delimiters */
enum defaultStringDelims = [Delim(`"`),
							Delim(`'`),
							Delim("`")];
enum pythonStringDelims = [Delim(`"""`),
						   Delim(`"`),
						   Delim(`'`),
						   Delim("`")];

/** File Kind.
 */
class FKind
{
	this(T, MagicData, RefPattern)(string kindName_,
								   T baseNaming_,
								   const string[] exts_,
								   MagicData magicData, size_t magicOffset = 0,
								   RefPattern refPattern_ = RefPattern.init,
								   const string[] keywords_ = [],

								   Delim[] strings_ = [],

								   Delim[] comments_ = [],

								   FileContent content_ = FileContent.unknown,
								   FileKindDetection detection_ = FileKindDetection.equalsWhatsGiven,
								   Lang lang_ = Lang.unknown,

								   FKind superKind = null,
								   FKind[] subKinds = [],
								   string description = null,
								   string wikip = null) @trusted pure
	{
		this.kindName = kindName_;

		// Basename
		import std.traits: isArray;
		import std.range: ElementType;
		static if (is(T == string))
		{
			this.baseNaming = lit(baseNaming_);
		}
		else static if (isArrayOf!(T, string))
		{
			/+ TODO: Move to a factory function strs(x) +/
			auto alt_ = alt();
			foreach (ext; baseNaming_)  // add each string as an alternative
			{
				alt_ ~= lit(ext);
			}
			this.baseNaming = alt_;
		}
		else static if (is(T == Patt))
		{
			this.baseNaming = baseNaming_;
		}

		this.exts = exts_;

		import std.traits: isAssignable;
		static	  if (is(MagicData == ubyte[])) { this.magicData = lit(magicData) ; }
		else static if (is(MagicData == string)) { this.magicData = lit(magicData.representation.dup); }
		else static if (is(MagicData == void[])) { this.magicData = lit(cast(ubyte[])magicData); }
		else static if (isAssignable!(Patt, MagicData)) { this.magicData = magicData; }
		else static assert(0, `Cannot handle MagicData being type ` ~ MagicData.stringof);

		this.magicOffset = magicOffset;

		static	  if (is(RefPattern == ubyte[])) { this.refPattern = refPattern_; }
		else static if (is(RefPattern == string)) { this.refPattern = refPattern_.representation.dup; }
		else static if (is(RefPattern == void[])) { this.refPattern = (cast(ubyte[])refPattern_).dup; }
		else static assert(0, `Cannot handle RefPattern being type ` ~ RefPattern.stringof);

		this.keywords = keywords_;

		this.strings = strings_;
		this.comments = comments_;

		this.content = content_;

		if ((content_ == FileContent.sourceCode ||
			 content_ == FileContent.scriptCode) &&
			detection_ == FileKindDetection.equalsWhatsGiven)
		{
			// relax matching of sourcecode to only need name until we have complete parsers
			this.detection = FileKindDetection.equalsName;
		}
		else
		{
			this.detection = detection_;
		}
		this.lang = lang_;

		this.superKind = superKind;
		this.subKinds = subKinds;
		this.description = description;
		this.wikip = wikip.asURL;
	}

	override string toString() const @property @trusted pure nothrow { return kindName; }

	/** Returns: Id Unique to matching behaviour of `this` FKind. If match
		behaviour of `this` FKind changes returned id will change.
		value is memoized.
	*/
	auto ref const(SHA1Digest) behaviorId() @property @safe /* pure nothrow */
		out(result) { assert(!result.empty); }
	do
	{
		if (_behaviourDigest.empty) // if not yet defined
		{
			ubyte[] bytes;
			const magicLit = cast(Lit)magicData;
			if (magicLit)
			{
				bytes = msgpack.pack(exts, magicLit.bytes, magicOffset, refPattern, keywords, content, detection);
			}
			else
			{
				//dln(`warning: Handle magicData of type `, kindName);
			}
			_behaviourDigest = bytes.sha1Of;
		}
		return _behaviourDigest;
	}

	string kindName;	// Kind Nick Name.
	string description; // Kind Documenting Description.
	AsURL!string wikip; // Wikipedia URL

	FKind superKind;	// Inherited pattern. For example ELF => ELF core file
	FKind[] subKinds;   // Inherited pattern. For example ELF => ELF core file
	Patt baseNaming;	// Pattern that matches typical file basenames of this Kind. May be null.

	string[] parentPathDirs; // example [`lib`, `firmware`] for `/lib/firmware` or `../lib/firmware`

	const string[] exts;	  // Typical Extensions.
	Patt magicData;	 // Magic Data.
	size_t magicOffset; // Magit Offset.
	ubyte[] refPattern; // Reference pattern.
	const FileContent content;
	const FileKindDetection detection;
	Lang lang; // Language if any

	// Volatile Statistics:
	private SHA1Digest _behaviourDigest;
	RegFile[] hitFiles;	 // Files of this kind.

	const string[] keywords; // Keywords
	string[] builtins; // Builtin Functions
	Op[] opers; // Language Opers

	/* TODO: Move this to CompLang class */
	Delim[] strings; // String syntax.
	Delim[] comments; // Comment syntax.

	bool machineGenerated; // True if this is a machine generated file.

	Tuple!(FOp, ShCmd)[] operations; // Operation and Corresponding Shell Command
}

/** Set of File Kinds with Internal Hashing. */
class FKinds
{
	void opOpAssign(string op)(FKind kind) @safe /* pure */ if (op == `~`)
	{
		mixin(`this.byIndex ` ~ op ~ `= kind;`);
		this.register(kind);
	}
	void opOpAssign(string op)(FKinds kinds) @safe /* pure */ if (op == `~`)
	{
		mixin(`this.byIndex ` ~ op ~ `= kinds.byIndex;`);
		foreach (kind; kinds.byIndex)
			this.register(kind);
	}

	FKinds register(FKind kind) @safe /* pure */
	{
		this.byName[kind.kindName] = kind;
		foreach (const ext; kind.exts)
		{
			this.byExt[ext] ~= kind;
		}
		this.byId[kind.behaviorId] = kind;
		if (kind.magicOffset == 0 && // only if zero-offset for now
			kind.magicData)
		{
			if (const magicLit = cast(Lit)kind.magicData)
			{
				this.byMagic[magicLit.bytes][magicLit.bytes.length] ~= kind;
				_magicLengths ~= magicLit.bytes.length; // add it
			}
		}
		return this;
	}

	/** Rehash Internal AAs.
		TODO: Change to @safe when https://github.com/D-Programming-Language/druntime/pull/942 has been merged
		TODO: Change to nothrow when uniq becomes nothrow.
	*/
	FKinds rehash() @trusted pure /* nothrow */
	{
		import std.algorithm: sort;
		_magicLengths = _magicLengths.uniq.array; // remove duplicates
		_magicLengths.sort();
		this.byName.rehash;
		this.byExt.rehash;
		this.byMagic.rehash;
		this.byId.rehash;
		return this;
	}

	FKind[] byIndex;
private:
	/* TODO: These are "slaves" under byIndex and should not be modifiable outside
	 of this class but their FKind's can mutable.
	 */
	FKind[string] byName; // Index by unique name string
	FKind[][string] byExt; // Index by possibly non-unique extension string

	FKind[][size_t][immutable ubyte[]] byMagic; // length => zero-offset magic byte array to Binary FKind[]
	size_t[] _magicLengths; // List of magic lengths to try as index in byMagic

	FKind[SHA1Digest] byId;	// Index Kinds by their behaviour
}

/** Match `kind` with full filename `full`. */
bool matchFullName(in FKind kind,
				   const scope string full, size_t six = 0) @safe pure nothrow
{
	return (kind.baseNaming &&
			!kind.baseNaming.matchFirst(full, six).empty);
}

/** Match `kind` with file extension `ext`. */
bool matchExtension(in FKind kind,
					const scope string ext) @safe pure nothrow
{
	return !kind.exts.find(ext).empty;
}

bool matchName(in FKind kind,
			   const scope string full, size_t six = 0,
			   const scope string ext = null) @safe pure nothrow
{
	return (kind.matchFullName(full) ||
			kind.matchExtension(ext));
}

import std.range: hasSlicing;

/** Match (Magic) Contents of `kind` with `range`.
	Returns: `true` iff match. */
bool matchContents(Range)(in FKind kind,
						  in Range range,
						  in RegFile regFile) pure nothrow if (hasSlicing!Range)
{
	const hit = kind.magicData.match(range, kind.magicOffset);
	return (!hit.empty);
}

enum KindHit
{
	none = 0,	 // No hit.
	cached = 1,   // Cached hit.
	uncached = 2, // Uncached (fresh) hit.
}

Tuple!(KindHit, FKind, size_t) ofAnyKindIn(NotNull!RegFile regFile,
										   FKinds kinds,
										   bool collectTypeHits)
{
	// using kindId
	if (regFile._cstat.kindId.defined) // kindId is already defined and uptodate
	{
		if (regFile._cstat.kindId in kinds.byId)
		{
			return tuple(KindHit.cached,
						 kinds.byId[regFile._cstat.kindId],
						 0UL);
		}
	}

	// using extension
	immutable ext = regFile.realExtension; // extension sans dot
	if (!ext.empty &&
		ext in kinds.byExt)
	{
		foreach (kindIndex, kind; kinds.byExt[ext])
		{
			auto hit = regFile.ofKind(kind.enforceNotNull, collectTypeHits, kinds);
			if (hit)
			{
				return tuple(hit, kind, kindIndex);
			}
		}
	}

	// try all
	foreach (kindIndex, kind; kinds.byIndex) // Iterate each kind
	{
		auto hit = regFile.ofKind(kind.enforceNotNull, collectTypeHits, kinds);
		if (hit)
		{
			return tuple(hit, kind, kindIndex);
		}
	}

	// no hit
	return tuple(KindHit.none,
				 FKind.init,
				 0UL);
}

/** Returns: true if file with extension `ext` is of type `kind`. */
KindHit ofKind(NotNull!RegFile regFile,
			   NotNull!FKind kind,
			   bool collectTypeHits,
			   FKinds allFKinds) /* nothrow */ @trusted
{
	immutable hit = regFile.ofKind1(kind,
									collectTypeHits,
									allFKinds);
	return hit;
}

KindHit ofKind(NotNull!RegFile regFile,
			   string kindName,
			   bool collectTypeHits,
			   FKinds allFKinds) /* nothrow */ @trusted
{
	typeof(return) hit;
	if (kindName in allFKinds.byName)
	{
		auto kind = assumeNotNull(allFKinds.byName[kindName]);
		hit = regFile.ofKind(kind,
							 collectTypeHits,
							 allFKinds);
	}
	return hit;
}

/** Helper for ofKind. */
KindHit ofKind1(NotNull!RegFile regFile,
				NotNull!FKind kind,
				bool collectTypeHits,
				FKinds allFKinds) /* nothrow */ @trusted
{
	// Try cached first
	if (regFile._cstat.kindId.defined &&
		(regFile._cstat.kindId in allFKinds.byId) && // if kind is known
		allFKinds.byId[regFile._cstat.kindId] is kind)  // if cached kind equals
	{
		return KindHit.cached;
	}

	immutable ext = regFile.realExtension;

	if (kind.superKind)
	{
		immutable baseHit = regFile.ofKind(enforceNotNull(kind.superKind),
										   collectTypeHits,
										   allFKinds);
		if (!baseHit)
		{
			return baseHit;
		}
	}

	bool hit = false;
	final switch (kind.detection)
	{
	case FileKindDetection.equalsParentPathDirsAndName:
		hit = (!regFile.parents.map!(a => a.name).find(kind.parentPathDirs).empty && // I love D :)
			   kind.matchName(regFile.name, 0, ext));
		break;
	case FileKindDetection.equalsName:
		hit = kind.matchName(regFile.name, 0, ext);
		break;
	case FileKindDetection.equalsNameAndContents:
		hit = (kind.matchName(regFile.name, 0, ext) &&
			   kind.matchContents(regFile.readOnlyContents, regFile));
		break;
	case FileKindDetection.equalsNameOrContents:
		hit = (kind.matchName(regFile.name, 0, ext) ||
			   kind.matchContents(regFile.readOnlyContents, regFile));
		break;
	case FileKindDetection.equalsContents:
		hit = kind.matchContents(regFile.readOnlyContents, regFile);
		break;
	case FileKindDetection.equalsWhatsGiven:
		// something must be defined
		assert(is(kind.baseNaming) ||
			   !kind.exts.empty ||
			   !(kind.magicData is null));
		hit = ((kind.matchName(regFile.name, 0, ext) &&
				(kind.magicData is null ||
				 kind.matchContents(regFile.readOnlyContents, regFile))));
		break;
	}
	if (hit)
	{
		if (collectTypeHits)
		{
			kind.hitFiles ~= regFile;
		}
		regFile._cstat.kindId = kind.behaviorId;	   // store reference in File
	}

	return hit ? KindHit.uncached : KindHit.none;
}

/** Directory Kind.
 */
class DirKind
{
	this(string fn,
		 string kn)
	{
		this.fileName = fn;
		this.kindName = kn;
	}

	version (msgpack)
	{
		this(Unpacker)(ref Unpacker unpacker)
		{
			fromMsgpack(msgpack.Unpacker(unpacker));
		}
		void toMsgpack(Packer)(ref Packer packer) const
		{
			packer.beginArray(this.tupleof.length);
			packer.pack(this.tupleof);
		}
		void fromMsgpack(Unpacker)(auto ref Unpacker unpacker)
		{
			unpacker.beginArray;
			unpacker.unpack(this.tupleof);
		}
	}

	string fileName;
	string kindName;
}
version (msgpack) unittest {
	auto k = tuple(``, ``);
	auto data = pack(k);
	Tuple!(string, string) k_; data.unpack(k_);
	assert(k == k_);
}

import std.file: DirEntry, getLinkAttributes;
import std.datetime: SysTime, Interval;

/** File.
 */
class File
{
	this(Dir parent)
	{
		this.parent = parent;
		if (parent) { ++parent.gstats.noFiles; }
	}
	this(string name, Dir parent, Bytes64 size,
		 SysTime timeLastModified,
		 SysTime timeLastAccessed)
	{
		this.name = name;
		this.parent = parent;
		this.size = size;
		this.timeLastModified = timeLastModified;
		this.timeLastAccessed = timeLastAccessed;
		if (parent) { ++parent.gstats.noFiles; }
	}

	// The Real Extension without leading dot.
	string realExtension() @safe pure nothrow const { return name.extension.chompPrefix(`.`); }
	alias ext = realExtension; // shorthand

	string toTextual() const @property { return `Any File`; }

	Bytes64 treeSize() @property @trusted /* @safe pure nothrow */ { return size; }

	/** Content Digest of Tree under this Directory. */
	const(SHA1Digest) treeContentId() @property @trusted /* @safe pure nothrow */
	{
		return typeof(return).init; // default to undefined
	}

	Face!Color face() const @property @safe pure nothrow { return fileFace; }

	/** Check if `this` File has been invalidated by `dent`.
		Returns: `true` iff `this` was obseleted.
	*/
	bool checkObseleted(ref DirEntry dent) @trusted
	{
		// Git-Style Check for Changes (called Decider in SCons Build Tool)
		bool flag = false;
		if (dent.size != this.size || // size has changes
			(dent.timeLastModified != this.timeLastModified) // if current modtime has changed or
			)
		{
			makeObselete;
			this.timeLastModified = dent.timeLastModified; // use new time
			this.size = dent.size; // use new time
			flag = true;
		}
		this.timeLastAccessed = dent.timeLastAccessed; // use new time
		return flag;
	}

	void makeObselete() @trusted {}
	void makeUnObselete() @safe {}

	/** Returns: Depth of Depth from File System root to this File. */
	int depth() @property @safe pure nothrow
	{
		return parent ? parent.depth + 1 : 0; // NOTE: this is fast because parent is memoized
	}
	/** NOTE: Currently not used. */
	int depthIterative() @property @safe pure
		out (depth) { debug assert(depth == depth); }
	do
	{
		typeof(return) depth = 0;
		for (auto curr = dir; curr !is null && !curr.isRoot; depth++)
		{
			curr = curr.parent;
		}
		return depth;
	}

	/** Get Parenting Dirs starting from parent of `this` upto root.
		Make this even more lazily evaluted.
	*/
	Dir[] parentsUpwards()
	{
		typeof(return) parents; // collected parents
		for (auto curr = dir; (curr !is null &&
							   !curr.isRoot); curr = curr.parent)
		{
			parents ~= curr;
		}
		return parents;
	}
	alias dirsDownward = parentsUpwards;

	/** Get Parenting Dirs starting from file system root downto containing
		directory of `this`.
	*/
	auto parents()
	{
		return parentsUpwards.retro;
	}
	alias dirs = parents;	 // SCons style alias
	alias parentsDownward = parents;

	bool underAnyDir(alias pred = `a`)()
	{
		import std.algorithm: any;
		import std.functional: unaryFun;
		return parents.any!(unaryFun!pred);
	}

	/** Returns: Path to `this` File.
		TODO: Reuse parents.
	 */
	string path() @property @trusted pure out (result) {
		/* assert(result == pathRecursive); */
	}
	do
	{
		if (!parent) { return dirSeparator; }

		size_t pathLength = 1 + name.length; // returned path length
		Dir[] parents; // collected parents

		for (auto curr = parent; (curr !is null &&
								  !curr.isRoot); curr = curr.parent)
		{
			pathLength += 1 + curr.name.length;
			parents ~= curr;
		}

		// build path
		auto thePath = new char[pathLength];
		size_t i = 0; // index to thePath
		import std.range: retro;
		foreach (currParent_; parents.retro)
		{
			immutable parentName = currParent_.name;
			thePath[i++] = dirSeparator[0];
			thePath[i .. i + parentName.length] = parentName[];
			i += parentName.length;
		}
		thePath[i++] = dirSeparator[0];
		thePath[i .. i + name.length] = name[];

		return thePath;
	}

	/** Returns: Path to `this` File.
		Recursive Heap-active implementation, slower than $(D path()).
	*/
	string pathRecursive() @property @trusted pure
	{
		if (parent)
		{
			static if (true)
			{
				import std.path: dirSeparator;
				// NOTE: This is more efficient than buildPath(parent.path,
				// name) because we can guarantee things about parent.path and
				// name
				immutable parentPath = parent.isRoot ? `` : parent.pathRecursive;
				return parentPath ~ dirSeparator ~ name;
			}
			else
			{
				import std.path: buildPath;
				return buildPath(parent.pathRecursive, name);
			}
		}
		else
		{
			return `/`;  // assume root folder with beginning slash
		}
	}

	version (msgpack)
	{
		void toMsgpack(Packer)(ref Packer packer) const
		{
			writeln(`Entering File.toMsgpack `, name);
			packer.pack(name, size, timeLastModified.stdTime, timeLastAccessed.stdTime);
		}
		void fromMsgpack(Unpacker)(auto ref Unpacker unpacker)
		{
			long stdTime;
			unpacker.unpack(stdTime); timeLastModified = SysTime(stdTime); /+ TODO: Functionize +/
			unpacker.unpack(stdTime); timeLastAccessed = SysTime(stdTime); /+ TODO: Functionize +/
		}
	}

	Dir parent;			   // Reference to parenting directory (or null if this is a root directory)
	alias dir = parent;	   // SCons style alias

	string name;			  // Empty if root directory
	Bytes64 size;			 // Size of file in bytes
	SysTime timeLastModified; // Last modification time
	SysTime timeLastAccessed; // Last access time
}

/** Maps Files to their tags. */
class FileTags
{
	FileTags addTag(File file, const scope string tag) @safe pure /* nothrow */
	{
		if (file in _tags)
		{
			if (_tags[file].find(tag).empty)
			{
				_tags[file] ~= tag; // add it
			}
		}
		else
		{
			_tags[file] = [tag];
		}
		return this;
	}
	FileTags removeTag(File file, string tag) @safe pure
	{
		if (file in _tags)
		{
			import std.algorithm: remove;
			_tags[file] = _tags[file].remove!(a => a == tag);
		}
		return this;
	}
	auto ref getTags(File file) const @safe pure nothrow
	{
		return file in _tags ? _tags[file] : null;
	}
	private string[][File] _tags; // Tags for each registered file.
}

version (linux) unittest {
	auto ftags = new FileTags();

	GStats gstats = new GStats();

	auto root = assumeNotNull(new Dir(cast(Dir)null, gstats));
	auto etc = getDir(root, `/etc`);
	assert(etc.path == `/etc`);

	auto dent = DirEntry(`/etc/passwd`);
	auto passwd = getFile(root, `/etc/passwd`, dent.isDir);
	assert(passwd.path == `/etc/passwd`);
	assert(passwd.parent == etc);
	assert(etc.sub(`passwd`) == passwd);

	ftags.addTag(passwd, `Password`);
	ftags.addTag(passwd, `Password`);
	ftags.addTag(passwd, `Secret`);
	assert(ftags.getTags(passwd) == [`Password`, `Secret`]);
	ftags.removeTag(passwd, `Password`);
	assert(ftags._tags[passwd] == [`Secret`]);
}

/** Symlink Target Status.
 */
enum SymlinkTargetStatus
{
	unknown,
	present,
	broken,
}

/** Symlink.
 */
class Symlink : File
{
	this(NotNull!Dir parent)
	{
		super(parent);
		++parent.gstats.noSymlinks;
	}
	this(ref DirEntry dent, NotNull!Dir parent)
	{
		Bytes64 sizeBytes;
		SysTime modified, accessed;
		bool ok = true;
		try
		{
			sizeBytes = dent.size.Bytes64;
			modified = dent.timeLastModified;
			accessed = dent.timeLastAccessed;
		}
		catch (Exception)
		{
			ok = false;
		}
		// const attrs = getLinkAttributes(dent.name); // attributes of target file
		// super(dent.name.baseName, parent, 0.Bytes64, cast(SysTime)0, cast(SysTime)0);
		super(dent.name.baseName, parent, sizeBytes, modified, accessed);
		if (ok)
		{
			this.retarget(dent); // trigger lazy load
		}
		++parent.gstats.noSymlinks;
	}

	override Face!Color face() const @property @safe pure nothrow
	{
		if (_targetStatus == SymlinkTargetStatus.broken)
			return symlinkBrokenFace;
		else
			return symlinkFace;
	}

	override string toTextual() const @property { return `Symbolic Link`; }

	string retarget(ref DirEntry dent) @trusted
	{
		import std.file: readLink;
		return _target = readLink(dent);
	}

	/** Cached/Memoized/Lazy Lookup for target. */
	string target() @property @trusted
	{
		if (!_target)		 // if target not yet read
		{
			auto targetDent = DirEntry(path);
			return retarget(targetDent); // read it
		}
		return _target;
	}
	/** Cached/Memoized/Lazy Lookup for target as absolute normalized path. */
	string absoluteNormalizedTargetPath() @property @trusted
	{
		import std.path: absolutePath, buildNormalizedPath;
		return target.absolutePath(path.dirName).buildNormalizedPath;
	}

	version (msgpack)
	{
		/** Construct from msgpack `unpacker`.  */
		this(Unpacker)(ref Unpacker unpacker)
		{
			fromMsgpack(msgpack.Unpacker(unpacker));
		}
		void toMsgpack(Packer)(ref Packer packer) const
		{
			/* writeln(`Entering File.toMsgpack `, name); */
			packer.pack(name, size, timeLastModified.stdTime, timeLastAccessed.stdTime);
		}
		void fromMsgpack(Unpacker)(auto ref Unpacker unpacker)
		{
			unpacker.unpack(name, size);
			long stdTime;
			unpacker.unpack(stdTime); timeLastModified = SysTime(stdTime); /+ TODO: Functionize +/
			unpacker.unpack(stdTime); timeLastAccessed = SysTime(stdTime); /+ TODO: Functionize +/
		}
	}

	string _target;
	SymlinkTargetStatus _targetStatus = SymlinkTargetStatus.unknown;
}

/** Special File (Character or Block Device).
 */
class SpecFile : File
{
	this(NotNull!Dir parent)
	{
		super(parent);
		++parent.gstats.noSpecialFiles;
	}
	this(ref DirEntry dent, NotNull!Dir parent)
	{
		super(dent.name.baseName, parent, 0.Bytes64, cast(SysTime)0, cast(SysTime)0);
		++parent.gstats.noSpecialFiles;
	}

	override Face!Color face() const @property @safe pure nothrow { return specialFileFace; }

	override string toTextual() const @property { return `Special File`; }

	version (msgpack)
	{
		/** Construct from msgpack `unpacker`.  */
		this(Unpacker)(ref Unpacker unpacker)
		{
			fromMsgpack(msgpack.Unpacker(unpacker));
		}
		void toMsgpack(Packer)(ref Packer packer) const
		{
			/* writeln(`Entering File.toMsgpack `, name); */
			packer.pack(name, size, timeLastModified.stdTime, timeLastAccessed.stdTime);
		}
		void fromMsgpack(Unpacker)(auto ref Unpacker unpacker)
		{
			unpacker.unpack(name, size);
			long stdTime;
			unpacker.unpack(stdTime); timeLastModified = SysTime(stdTime); /+ TODO: Functionize +/
			unpacker.unpack(stdTime); timeLastAccessed = SysTime(stdTime); /+ TODO: Functionize +/
		}
	}
}

/** Bit (Content) Status. */
enum BitStatus
{
	unknown,
	bits7,
	bits8,
}

/** Regular File.
 */
class RegFile : File
{
	this(NotNull!Dir parent)
	{
		super(parent);
		++parent.gstats.noRegFiles;
	}
	this(ref DirEntry dent, NotNull!Dir parent)
	{
		this(dent.name.baseName, parent, dent.size.Bytes64,
			 dent.timeLastModified, dent.timeLastAccessed);
	}
	this(string name, NotNull!Dir parent, Bytes64 size, SysTime timeLastModified, SysTime timeLastAccessed)
	{
		super(name, parent, size, timeLastModified, timeLastAccessed);
		++parent.gstats.noRegFiles;
	}

	~this() nothrow @nogc
	{
		_cstat.deallocate(false);
	}

	override string toTextual() const @property { return `Regular File`; }

	/** Returns: Content Id of `this`. */
	const(SHA1Digest) contentId() @property @trusted /* @safe pure nothrow */
	{
		if (_cstat._contentId.isUntouched)
		{
			enum doSHA1 = true;
			calculateCStatInChunks(parent.gstats.filesByContentId,
								   32*pageSize(),
								   doSHA1);
			freeContents(); /+ TODO: Call lazily only when open count is too large +/
		}
		return _cstat._contentId;
	}

	/** Returns: Tree Content Id of `this`. */
	override const(SHA1Digest) treeContentId() @property @trusted /* @safe pure nothrow */
	{
		return contentId;
	}

	override Face!Color face() const @property @safe pure nothrow { return regFileFace; }

	/** Returns: SHA-1 of `this` `File` Contents at `src`. */
	const(SHA1Digest) contId(inout (ubyte[]) src,
							 File[][SHA1Digest] filesByContentId)
		@property pure out(result) { assert(!result.empty); } // must have be defined
	do
	{
		if (_cstat._contentId.empty) // if not yet defined
		{
			_cstat._contentId = src.sha1Of;
			filesByContentId[_cstat._contentId] ~= this;
		}
		return _cstat._contentId;
	}

	/** Returns: Cached/Memoized Binary Histogram of `this` `File`. */
	auto ref bistogram8() @property @safe // ref needed here!
	{
		if (_cstat.bist.empty)
		{
			_cstat.bist.put(readOnlyContents); // memoized calculated
		}
		return _cstat.bist;
	}

	/** Returns: Cached/Memoized XGram of `this` `File`. */
	auto ref xgram() @property @safe // ref needed here!
	{
		if (_cstat.xgram.empty)
		{
			_cstat.xgram.put(readOnlyContents); // memoized calculated
		}
		return _cstat.xgram;
	}

	/** Returns: Cached/Memoized XGram Deep Denseness of `this` `File`. */
	auto ref xgramDeepDenseness() @property @safe
	{
		if (!_cstat._xgramDeepDenseness)
		{
			_cstat._xgramDeepDenseness = xgram.denseness(-1).numerator;
		}
		return Rational!ulong(_cstat._xgramDeepDenseness,
							  _cstat.xgram.noBins);
	}

	/** Returns: true if empty file (zero length). */
	bool empty() @property const @safe { return size == 0; }

	/** Process File in Cache Friendly Chunks. */
	void calculateCStatInChunks(NotNull!File[][SHA1Digest] filesByContentId,
								size_t chunkSize = 32*pageSize(),
								bool doSHA1 = false,
								bool doBist = false,
								bool doBitStatus = false) @safe
	{
		if (_cstat._contentId.defined || empty) { doSHA1 = false; }
		if (!_cstat.bist.empty) { doBist = false; }
		if (_cstat.bitStatus != BitStatus.unknown) { doBitStatus = false; }

		import std.digest.sha;
		SHA1 sha1;
		if (doSHA1) { sha1.start(); }

		bool isASCII = true;

		if (doSHA1 || doBist || doBitStatus)
		{
			import std.range: chunks;
			foreach (chunk; readOnlyContents.chunks(chunkSize))
			{
				if (doSHA1) { sha1.put(chunk); }
				if (doBist) { _cstat.bist.put(chunk); }
				if (doBitStatus)
				{
					/* TODO: This can be parallelized using 64-bit wording!
					 * Write automatic parallelizing library for this? */
					foreach (elt; chunk)
					{
						import nxt.bitop_ex: bt;
						isASCII = isASCII && !elt.bt(7); // ASCII has no topmost bit set
					}
				}
			}
		}

		if (doBitStatus)
		{
			_cstat.bitStatus = isASCII ? BitStatus.bits7 : BitStatus.bits8;
		}

		if (doSHA1)
		{
			_cstat._contentId = sha1.finish();
			filesByContentId[_cstat._contentId] ~= cast(NotNull!File)assumeNotNull(this); /+ TODO: Prettier way? +/
		}
	}

	/** Clear/Reset Contents Statistics of `this` `File`. */
	void clearCStat(File[][SHA1Digest] filesByContentId) @safe nothrow
	{
		// SHA1-digest
		if (_cstat._contentId in filesByContentId)
		{
			auto dups = filesByContentId[_cstat._contentId];
			import std.algorithm: remove;
			immutable n = dups.length;
			dups = dups.remove!(a => a is this);
			assert(n == dups.length + 1); // assert that dups were not decreased by one);
		}
	}

	override string toString() @property @trusted
	{
		// import std.traits: fullyQualifiedName;
		// return fullyQualifiedName!(typeof(this)) ~ `(` ~ buildPath(parent.name, name) ~ `)`; /+ TODO: typenameof +/
		return (typeof(this)).stringof ~ `(` ~ this.path ~ `)`; /+ TODO: typenameof +/
	}

	version (msgpack)
	{
		/** Construct from msgpack `unpacker`.  */
		this(Unpacker)(ref Unpacker unpacker)
		{
			fromMsgpack(msgpack.Unpacker(unpacker));
		}

		/** Pack. */
		void toMsgpack(Packer)(ref Packer packer) const {
			/* writeln(`Entering RegFile.toMsgpack `, name); */

			packer.pack(name, size,
						timeLastModified.stdTime,
						timeLastAccessed.stdTime);

			// CStat: TODO: Group
			packer.pack(_cstat.kindId); // FKind
			packer.pack(_cstat._contentId); // Digest

			// Bist
			immutable bistFlag = !_cstat.bist.empty;
			packer.pack(bistFlag);
			if (bistFlag) { packer.pack(_cstat.bist); }

			// XGram
			immutable xgramFlag = !_cstat.xgram.empty;
			packer.pack(xgramFlag);
			if (xgramFlag)
			{
				/* debug dln("packing xgram. empty:", _cstat.xgram.empty); */
				packer.pack(_cstat.xgram,
							_cstat._xgramDeepDenseness);
			}

			/*	 auto this_ = (cast(RegFile)this); /+ TODO: Ugly! Is there another way? */ +/
			/*	 const tags = this_.parent.gstats.ftags.getTags(this_); */
			/*	 immutable tagsFlag = !tags.empty; */
			/*	 packer.pack(tagsFlag); */
			/*	 debug dln(`Packing tags `, tags, ` of `, this_.path); */
			/*	 if (tagsFlag) { packer.pack(tags); } */
		}

		/** Unpack. */
		void fromMsgpack(Unpacker)(auto ref Unpacker unpacker) @trusted
		{
			unpacker.unpack(name, size); // Name, Size

			// Time
			long stdTime;
			unpacker.unpack(stdTime); timeLastModified = SysTime(stdTime); /+ TODO: Functionize +/
			unpacker.unpack(stdTime); timeLastAccessed = SysTime(stdTime); /+ TODO: Functionize +/

			// CStat: TODO: Group
			unpacker.unpack(_cstat.kindId); // FKind
			if (_cstat.kindId.defined &&
				_cstat.kindId !in parent.gstats.allFKinds.byId)
			{
				dln(`warning: kindId `, _cstat.kindId, ` not found for `,
					path, `, FKinds length `, parent.gstats.allFKinds.byIndex.length);
				_cstat.kindId.reset; // forget it
			}
			unpacker.unpack(_cstat._contentId); // Digest
			if (_cstat._contentId)
			{
				parent.gstats.filesByContentId[_cstat._contentId] ~= cast(NotNull!File)this;
			}

			// Bist
			bool bistFlag; unpacker.unpack(bistFlag);
			if (bistFlag)
			{
				unpacker.unpack(_cstat.bist);
			}

			// XGram
			bool xgramFlag; unpacker.unpack(xgramFlag);
			if (xgramFlag)
			{
				/* if (_cstat.xgram == null) { */
				/*	 _cstat.xgram = cast(XGram*)core.stdc.stdlib.malloc(XGram.sizeof); */
				/* } */
				/* unpacker.unpack(*_cstat.xgram); */
				unpacker.unpack(_cstat.xgram,
								_cstat._xgramDeepDenseness);
				/* debug dln(`unpacked xgram. empty:`, _cstat.xgram.empty); */
			}

			// tags
			/* bool tagsFlag; unpacker.unpack(tagsFlag); */
			/* if (tagsFlag) { */
			/*	 string[] tags; */
			/*	 unpacker.unpack(tags); */
			/* } */
		}

		override void makeObselete() @trusted { _cstat.reset(); /* debug dln(`Reset CStat for `, path); */ }
	}

	/** Returns: Read-Only Contents of `this` Regular File. */
	// } catch (InvalidMemoryOperationError) { viz.ppln(outFile, useHTML, `Failed to mmap `, dent.name); }
	// scope immutable src = cast(immutable ubyte[]) read(dent.name, upTo);
	immutable(ubyte[]) readOnlyContents(string file = __FILE__, int line = __LINE__)() @trusted
	{
		if (_mmfile is null)
		{
			if (size == 0) // munmap fails for empty files
			{
				static assert([] !is null);
				return []; // empty file
			}
			else
			{
				_mmfile = new MmFile(path, MmFile.Mode.read,
									 mmfile_size, null, pageSize());
				if (parent.gstats.showMMaps)
				{
					writeln(`Mapped `, path, ` of size `, size);
				}
			}
		}
		return cast(typeof(return))_mmfile[];
	}

	/** Returns: Read-Writable Contents of `this` Regular File. */
	// } catch (InvalidMemoryOperationError) { viz.ppln(outFile, useHTML, `Failed to mmap `, dent.name); }
	// scope immutable src = cast(immutable ubyte[]) read(dent.name, upTo);
	ubyte[] readWriteableContents() @trusted
	{
		if (!_mmfile)
		{
			_mmfile = new MmFile(path, MmFile.Mode.readWrite,
								 mmfile_size, null, pageSize());
		}
		return cast(typeof(return))_mmfile[];
	}

	/** If needed Free Allocated Contents of `this` Regular File. */
	bool freeContents()
	{
		if (_mmfile) {
			delete _mmfile; _mmfile = null; return true;
		}
		else { return false; }
	}

	import std.mmfile;
	private MmFile _mmfile = null;
	private CStat _cstat;	 // Statistics about the contents of this RegFile.
}

/** Traits */
enum isFile(T) = (is(T == File) || is(T == NotNull!File));
enum isDir(T) = (is(T == Dir) || is(T == NotNull!Dir));
enum isSymlink(T) = (is(T == Symlink) || is(T == NotNull!Symlink));
enum isRegFile(T) = (is(T == RegFile) || is(T == NotNull!RegFile));
enum isSpecialFile(T) = (is(T == SpecFile) || is(T == NotNull!SpecFile));
enum isAnyFile(T) = (isFile!T ||
					 isDir!T ||
					 isSymlink!T ||
					 isRegFile!T ||
					 isSpecialFile!T);

/** Return true if T is a class representing File IO. */
enum isFileIO(T) = (isAnyFile!T ||
					is(T == ioFile));

/** Contents Statistics of a Regular File. */
struct CStat
{
	void reset() @safe nothrow
	{
		kindId[] = 0;
		_contentId[] = 0;
		hitCount = 0;
		bist.reset();
		xgram.reset();
		_xgramDeepDenseness = 0;
		deallocate();
	}

	void deallocate(bool nullify = true) @trusted nothrow
	{
		kindId[] = 0;
		/* if (xgram != null) { */
		/*	 import core.stdc.stdlib; */
		/*	 free(xgram); */
		/*	 if (nullify) { */
		/*		 xgram = null; */
		/*	 } */
		/* } */
	}

	SHA1Digest kindId; // FKind Identifier/Fingerprint of this regular file.
	SHA1Digest _contentId; // Content Identifier/Fingerprint.

	/** Boolean Single Bistogram over file contents. If
		binHist0[cast(ubyte)x] is set then this file contains byte x. Consumes
		32 bytes. */
	Bist bist; /+ TODO: Put in separate slice std.allocator. +/

	/** Boolean Pair Bistogram (Digram) over file contents (higher-order statistics).
		If this RegFile contains a sequence of [byte0, bytes1],
		then bit at index byte0 + byte1 * 256 is set in xgram.
	*/
	XGram xgram; /+ TODO: Use slice std.allocator +/
	private ulong _xgramDeepDenseness = 0;

	uint64_t hitCount = 0;
	BitStatus bitStatus = BitStatus.unknown;
}

import core.sys.posix.sys.types;

enum SymlinkFollowContext
{
	none,					   // Follow no symlinks
	internal,				   // Follow only symlinks outside of scanned tree
	external,				   // Follow only symlinks inside of scanned tree
	all,						// Follow all symlinks
	standard = external
}

/** Global Scanner Statistics. */
class GStats
{
	NotNull!File[][string] filesByName;	// Potential File Name Duplicates
	NotNull!File[][ino_t] filesByInode;	// Potential Link Duplicates
	NotNull!File[][SHA1Digest] filesByContentId; // File(s) (Duplicates) Indexed on Contents SHA1.
	NotNull!RegFile[][string] elfFilesBySymbol; // File(s) (Duplicates) Indexed on raw unmangled symbol.
	FileTags ftags;

	Bytes64[NotNull!File] treeSizesByFile; // Tree sizes.
	size_t[NotNull!File] lineCountsByFile; // Line counts.

	// VCS Directories
	DirKind[] vcDirKinds;
	DirKind[string] vcDirKindsMap;

	// Skipped Directories
	DirKind[] skippedDirKinds;
	DirKind[string] skippedDirKindsMap;

	FKinds txtFKinds = new FKinds; // Textual
	FKinds binFKinds = new FKinds; // Binary (Non-Textual)
	FKinds allFKinds = new FKinds; // All
	FKinds selFKinds = new FKinds; // User selected

	void loadFileKinds()
	{
		txtFKinds ~= new FKind("SCons", ["SConstruct", "SConscript"],
							   ["scons"],
							   [], 0, [], [],
							   defaultCommentDelims,
							   pythonStringDelims,
							   FileContent.buildSystemCode, FileKindDetection.equalsNameAndContents); // TOOD: Inherit Python

		txtFKinds ~= new FKind("Makefile", ["GNUmakefile", "Makefile", "makefile"],
							   ["mk", "mak", "makefile", "make", "gnumakefile"], [], 0, [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode, FileKindDetection.equalsName);
		txtFKinds ~= new FKind("Automakefile", ["Makefile.am", "makefile.am"],
							   ["am"], [], 0, [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode);
		txtFKinds ~= new FKind("Autoconffile", ["configure.ac", "configure.in"],
							   [], [], 0, [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode);
		txtFKinds ~= new FKind("Doxygen", ["Doxyfile"],
							   ["doxygen"], [], 0, [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode);

		txtFKinds ~= new FKind("Rake", ["Rakefile"],/+ TODO: inherit Ruby +/
							   ["mk", "makefile", "make", "gnumakefile"], [], 0, [], [],
							   [Delim("#"), Delim("=begin", "=end")],
							   defaultStringDelims,
							   FileContent.sourceCode, FileKindDetection.equalsName);

		txtFKinds ~= new FKind("HTML", [], ["htm", "html", "shtml", "xhtml"], [], 0, [], [],
							   [Delim("<!--", "-->")],
							   defaultStringDelims,
							   FileContent.text, FileKindDetection.equalsContents); // markup text
		txtFKinds ~= new FKind("XML", [], ["xml", "dtd", "xsl", "xslt", "ent", ], [], 0, "<?xml", [],
							   [Delim("<!--", "-->")],
							   defaultStringDelims,
							   FileContent.text, FileKindDetection.equalsContents); /+ TODO: markup text +/
		txtFKinds ~= new FKind("YAML", [], ["yaml", "yml"], [], 0, [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.text); /+ TODO: markup text +/
		txtFKinds ~= new FKind("CSS", [], ["css"], [], 0, [], [],
							   [Delim("/*", "*/")],
							   defaultStringDelims,
							   FileContent.text, FileKindDetection.equalsContents);

		txtFKinds ~= new FKind("Audacity Project", [], ["aup"], [], 0, "<?xml", [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.text, FileKindDetection.equalsNameAndContents);

		txtFKinds ~= new FKind("Comma-separated values", [], ["csv"], [], 0, [], [], /+ TODO: decribe with symbolic +/
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.text, FileKindDetection.equalsNameAndContents);

		txtFKinds ~= new FKind("Tab-separated values", [], ["tsv"], [], 0, [], [], /+ TODO: describe with symbolic +/
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.text, FileKindDetection.equalsNameAndContents);

		static immutable keywordsC = [
			"auto", "const", "double", "float", "int", "short", "struct",
			"unsigned", "break", "continue", "else", "for", "long", "signed",
			"switch", "void", "case", "default", "enum", "goto", "register",
			"sizeof", "typedef", "volatile", "char", "do", "extern", "if",
			"return", "static", "union", "while",
			];

		/* See_Also: https://en.wikipedia.org/wiki/Operators_in_C_and_C%2B%2B */
		auto opersCBasic = [
			// Arithmetic
			Op("+", OpArity.binary, OpAssoc.LR, 6, "Add"),
			Op("-", OpArity.binary, OpAssoc.LR, 6, "Subtract"),
			Op("*", OpArity.binary, OpAssoc.LR, 5, "Multiply"),
			Op("/", OpArity.binary, OpAssoc.LR, 5, "Divide"),
			Op("%", OpArity.binary, OpAssoc.LR, 5, "Remainder/Moduls"),

			Op("+", OpArity.unaryPrefix, OpAssoc.RL, 3, "Unary plus"),
			Op("-", OpArity.unaryPrefix, OpAssoc.RL, 3, "Unary minus"),

			Op("++", OpArity.unaryPostfix, OpAssoc.LR, 2, "Suffix increment"),
			Op("--", OpArity.unaryPostfix, OpAssoc.LR, 2, "Suffix decrement"),

			Op("++", OpArity.unaryPrefix, OpAssoc.RL, 3, "Prefix increment"),
			Op("--", OpArity.unaryPrefix, OpAssoc.RL, 3, "Prefix decrement"),

			// Assignment Arithmetic (binary)
			Op("=", OpArity.binary, OpAssoc.RL, 16, "Assign"),
			Op("+=", OpArity.binary, OpAssoc.RL, 16, "Assignment by sum"),
			Op("-=", OpArity.binary, OpAssoc.RL, 16, "Assignment by difference"),
			Op("*=", OpArity.binary, OpAssoc.RL, 16, "Assignment by product"),
			Op("/=", OpArity.binary, OpAssoc.RL, 16, "Assignment by quotient"),
			Op("%=", OpArity.binary, OpAssoc.RL, 16, "Assignment by remainder"),

			Op("&=", OpArity.binary, OpAssoc.RL, 16, "Assignment by bitwise AND"),
			Op("|=", OpArity.binary, OpAssoc.RL, 16, "Assignment by bitwise OR"),

			Op("^=", OpArity.binary, OpAssoc.RL, 16, "Assignment by bitwise XOR"),
			Op("<<=", OpArity.binary, OpAssoc.RL, 16, "Assignment by bitwise left shift"),
			Op(">>=", OpArity.binary, OpAssoc.RL, 16, "Assignment by bitwise right shift"),

			Op("==", OpArity.binary, OpAssoc.LR, 9, "Equal to"),
			Op("!=", OpArity.binary, OpAssoc.LR, 9, "Not equal to"),

			Op("<", OpArity.binary, OpAssoc.LR, 8, "Less than"),
			Op(">", OpArity.binary, OpAssoc.LR, 8, "Greater than"),
			Op("<=", OpArity.binary, OpAssoc.LR, 8, "Less than or equal to"),
			Op(">=", OpArity.binary, OpAssoc.LR, 8, "Greater than or equal to"),

			Op("&&", OpArity.binary, OpAssoc.LR, 13, "Logical AND"), /+ TODO: Convert to math in smallcaps AND +/
			Op("||", OpArity.binary, OpAssoc.LR, 14, "Logical OR"), /+ TODO: Convert to math in smallcaps OR +/

			Op("!", OpArity.unaryPrefix, OpAssoc.LR, 3, "Logical NOT"), /+ TODO: Convert to math in smallcaps NOT +/

			Op("&", OpArity.binary, OpAssoc.LR, 10, "Bitwise AND"),
			Op("^", OpArity.binary, OpAssoc.LR, 11, "Bitwise XOR (exclusive or)"),
			Op("|", OpArity.binary, OpAssoc.LR, 12, "Bitwise OR"),

			Op("<<", OpArity.binary, OpAssoc.LR, 7, "Bitwise left shift"),
			Op(">>", OpArity.binary, OpAssoc.LR, 7, "Bitwise right shift"),

			Op("~", OpArity.unaryPrefix, OpAssoc.LR, 3, "Bitwise NOT (One's Complement)"),
			Op(",", OpArity.binary, OpAssoc.LR, 18, "Comma"),
			Op("sizeof", OpArity.unaryPrefix, OpAssoc.LR, 3, "Size-of"),

			Op("->", OpArity.binary, OpAssoc.LR, 2, "Element selection through pointer"),
			Op(".", OpArity.binary, OpAssoc.LR, 2, "Element selection by reference"),

			];

		/* See_Also: https://en.wikipedia.org/wiki/Iso646.h */
		auto opersC_ISO646 = [
			OpAlias("and", "&&"),
			OpAlias("or", "||"),
			OpAlias("and_eq", "&="),

			OpAlias("bitand", "&"),
			OpAlias("bitor", "|"),

			OpAlias("compl", "~"),
			OpAlias("not", "!"),
			OpAlias("not_eq", "!="),
			OpAlias("or_eq", "|="),
			OpAlias("xor", "^"),
			OpAlias("xor_eq", "^="),
			];

		auto opersC = opersCBasic /* ~ opersC_ISO646 */;

		auto kindC = new FKind("C", [], ["c", "h"], [], 0, [],
							   keywordsC,
							   cCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode,
							   FileKindDetection.equalsWhatsGiven,
							   Lang.c);
		txtFKinds ~= kindC;
		kindC.operations ~= tuple(FOp.checkSyntax, `gcc -x c -fsyntax-only -c`);
		kindC.operations ~= tuple(FOp.checkSyntax, `clang -x c -fsyntax-only -c`);
		kindC.operations ~= tuple(FOp.preprocess, `cpp`);
		kindC.opers = opersC;

		static immutable keywordsCxx = (keywordsC ~ ["asm", "dynamic_cast", "namespace", "reinterpret_cast", "try",
													 "bool", "explicit", "new", "static_cast", "typeid",
													 "catch", "false", "operator", "template", "typename",
													 "class", "friend", "private", "this", "using",
													 "const_cast", "inline", "public", "throw", "virtual",
													 "delete", "mutable", "protected", "true", "wchar_t",
													 // The following are not essential when
													 // the standard ASCII character set is
													 // being used, but they have been added
													 // to provide more readable alternatives
													 // for some of the C++ operators, and
													 // also to facilitate programming with
													 // character sets that lack characters
													 // needed by C++.
													 "and", "bitand", "compl", "not_eq", "or_eq", "xor_eq",
													 "and_eq", "bitor", "not", "or", "xor", ]).uniq.array;

		auto opersCxx = opersC ~ [
			Op("->*", OpArity.binary, OpAssoc.LR, 4, "Pointer to member"),
			Op(".*", OpArity.binary, OpAssoc.LR, 4, "Pointer to member"),
			Op("::", OpArity.binary, OpAssoc.none, 1, "Scope resolution"),
			Op("typeid", OpArity.unaryPrefix, OpAssoc.LR, 2, "Run-time type information (RTTI))"),
			//Op("alignof", OpArity.unaryPrefix, OpAssoc.LR, _, _),
			Op("new", OpArity.unaryPrefix, OpAssoc.RL, 3, "Dynamic memory allocation"),
			Op("delete", OpArity.unaryPrefix, OpAssoc.RL, 3, "Dynamic memory deallocation"),
			Op("delete[]", OpArity.unaryPrefix, OpAssoc.RL, 3, "Dynamic memory deallocation"),
			/* Op("noexcept", OpArity.unaryPrefix, OpAssoc.none, _, _), */

			Op("dynamic_cast", OpArity.unaryPrefix, OpAssoc.LR, 2, "Type cast"),
			Op("reinterpret_cast", OpArity.unaryPrefix, OpAssoc.LR, 2, "Type cast"),
			Op("static_cast", OpArity.unaryPrefix, OpAssoc.LR, 2, "Type cast"),
			Op("const_cast", OpArity.unaryPrefix, OpAssoc.LR, 2, "Type cast"),

			Op("throw", OpArity.unaryPrefix, OpAssoc.LR, 17, "Throw operator"),
			/* Op("catch", OpArity.unaryPrefix, OpAssoc.LR, _, _) */
			];

		static immutable extsCxx = ["cpp", "hpp", "cxx", "hxx", "c++", "h++", "C", "H"];
		auto kindCxx = new FKind("C++", [], extsCxx, [], 0, [],
								 keywordsCxx,
								 cCommentDelims,
								 defaultStringDelims,
								 FileContent.sourceCode,
								 FileKindDetection.equalsWhatsGiven,
								 Lang.cxx);
		kindCxx.operations ~= tuple(FOp.checkSyntax, `gcc -x c++ -fsyntax-only -c`);
		kindCxx.operations ~= tuple(FOp.checkSyntax, `clang -x c++ -fsyntax-only -c`);
		kindCxx.operations ~= tuple(FOp.preprocess, `cpp`);
		kindCxx.opers = opersCxx;
		txtFKinds ~= kindCxx;
		static immutable keywordsCxx11 = keywordsCxx ~ ["alignas", "alignof",
														"char16_t", "char32_t",
														"constexpr",
														"decltype",
														"override", "final",
														"noexcept", "nullptr",
														"auto",
														"thread_local",
														"static_assert", ];
		/+ TODO: Define as subkind +/
		/* txtFKinds ~= new FKind("C++11", [], ["cpp", "hpp", "cxx", "hxx", "c++", "h++", "C", "H"], [], 0, [], */
		/*						keywordsCxx11, */
		/*						[Delim("/\*", "*\/"), */
		/*						 Delim("//")], */
		/*						defaultStringDelims, */
		/*						FileContent.sourceCode, */
		/*						FileKindDetection.equalsWhatsGiven); */

		/* See_Also: http://msdn.microsoft.com/en-us/library/2e6a4at9.aspx */
		static immutable opersCxxMicrosoft = ["__alignof"];

		/* See_Also: http://msdn.microsoft.com/en-us/library/2e6a4at9.aspx */
		static immutable keywordsCxxMicrosoft = (keywordsCxx ~ [/* __abstract 2 */
													 "__asm",
													 "__assume",
													 "__based",
													 /* __box 2 */
													 "__cdecl",
													 "__declspec",
													 /* __delegate 2 */
													 "__event",
													 "__except",
													 "__fastcall",
													 "__finally",
													 "__forceinline",
													 /* __gc 2 */
													 /* __hook 3 */
													 "__identifier",
													 "__if_exists",
													 "__if_not_exists",
													 "__inline",
													 "__int16",
													 "__int32",
													 "__int64",
													 "__int8",
													 "__interface",
													 "__leave",
													 "__m128",
													 "__m128d",
													 "__m128i",
													 "__m64",
													 "__multiple_inheritance",
													 /* __nogc 2 */
													 "__noop",
													 /* __pin 2 */
													 /* __property 2 */
													 "__raise",
													 /* __sealed 2 */
													 "__single_inheritance",
													 "__stdcall",
													 "__super",
													 "__thiscall",
													 "__try",
													 "__except",
													 "__finally",
													 /* __try_cast 2 */
													 "__unaligned",
													 /* __unhook 3 */
													 "__uuidof",
													 /* __value 2 */
													 "__virtual_inheritance",
													 "__w64",
													 "__wchar_t",
													 "wchar_t",
													 "abstract",
													 "array",
													 "auto",
													 "bool",
													 "break",
													 "case",
													 "catch",
													 "char",
													 "class",
													 "const",
													 "const_cast",
													 "continue",
													 "decltype",
													 "default",
													 "delegate",
													 "delete",
													 /* deprecated 1 */
													 /* dllexport 1 */
													 /* dllimport 1 */
													 "do",
													 "double",
													 "dynamic_cast",
													 "else",
													 "enum",
													 "enum class",
													 "enum struct",
													 "event",
													 "explicit",
													 "extern",
													 "false",
													 "finally",
													 "float",
													 "for",
													 "for each",
													 "in",
													 "friend",
													 "friend_as",
													 "gcnew",
													 "generic",
													 "goto",
													 "if",
													 "initonly",
													 "inline",
													 "int",
													 "interface class",
													 "interface struct",
													 "interior_ptr",
													 "literal",
													 "long",
													 "mutable",
													 /* naked 1 */
													 "namespace",
													 "new",
													 "new",
													 /* noinline 1 */
													 /* noreturn 1 */
													 /* nothrow 1 */
													 /* novtable 1 */
													 "nullptr",
													 "operator",
													 "private",
													 "property",
													 /* property 1 */
													 "protected",
													 "public",
													 "ref class",
													 "ref struct",
													 "register",
													 "reinterpret_cast",
													 "return",
													 "safecast",
													 "sealed",
													 /* selectany 1 */
													 "short",
													 "signed",
													 "sizeof",
													 "static",
													 "static_assert",
													 "static_cast",
													 "struct",
													 "switch",
													 "template",
													 "this",
													 /* thread 1 */
													 "throw",
													 "true",
													 "try",
													 "typedef",
													 "typeid",
													 "typeid",
													 "typename",
													 "union",
													 "unsigned",
													 "using" /* declaration */,
													 "using" /* directive */,
													 /* uuid 1 */
													 "value class",
													 "value struct",
													 "virtual",
													 "void",
													 "volatile",
													 "while"]).uniq.array;

		static immutable xattrCxxMicrosoft = [];

		static immutable keywordsNewObjectiveC = ["id",
												  "in",
												  "out", // Returned by reference
												  "inout", // Argument is used both to provide information and to get information back
												  "bycopy",
												  "byref", "oneway", "self",
												  "super", "@interface", "@end",
												  "@implementation", "@end",
												  "@interface", "@end",
												  "@implementation", "@end",
												  "@protoco", "@end", "@class" ];

		static immutable keywordsObjectiveC = keywordsC ~ keywordsNewObjectiveC;
		txtFKinds ~= new FKind("Objective-C", [], ["m", "h"], [], 0, [],
							   keywordsObjectiveC,
							   cCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode, FileKindDetection.equalsWhatsGiven,
							   Lang.objectiveC);

		static immutable keywordsObjectiveCxx = keywordsCxx ~ keywordsNewObjectiveC;
		txtFKinds ~= new FKind("Objective-C++", [], ["mm", "h"], [], 0, [],
							   keywordsObjectiveCxx,
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode,
							   FileKindDetection.equalsWhatsGiven,
							   Lang.objectiveCxx);

		static immutable keywordsSwift = ["break", "class", "continue", "default", "do", "else", "for", "func", "if", "import",
							  "in", "let", "return", "self", "struct", "super", "switch", "unowned", "var", "weak", "while",
							  "mutating", "extension"];
		auto opersOverflowSwift = opersC ~ [Op("&+"), Op("&-"), Op("&*"), Op("&/"), Op("&%")];
		auto builtinsSwift = ["print", "println"];
		auto kindSwift = new FKind("Swift", [], ["swift"], [], 0, [],
								   keywordsSwift,
								   cCommentDelims,
								   defaultStringDelims,
								   FileContent.sourceCode,
								   FileKindDetection.equalsWhatsGiven,
								   Lang.swift);
		kindSwift.builtins = builtinsSwift;
		kindSwift.opers = opersOverflowSwift;
		txtFKinds ~= kindSwift;

		static immutable keywordsCSharp = ["if"]; /+ TODO: Add keywords +/
		txtFKinds ~= new FKind("C#", [], ["cs"], [], 0, [], keywordsCSharp,
							   cCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode,
							   FileKindDetection.equalsWhatsGiven,
							   Lang.cSharp);

		static immutable keywordsOCaml = ["and", "as", "assert", "begin", "class",
										  "constraint", "do", "done", "downto", "else",
										  "end", "exception", "external", "false", "for",
										  "fun", "function", "functor", "if", "in",
										  "include", "inherit", "inherit!", "initializer",
										  "lazy", "let", "match", "method", "method!",
										  "module", "mutable", "new", "object", "of",
										  "open", "or",
										  "private", "rec", "sig", "struct", "then", "to",
										  "true", "try", "type",
										  "val", "val!", "virtual",
										  "when", "while", "with"];
		txtFKinds ~= new FKind("OCaml", [], ["ocaml"], [], 0, [], keywordsOCaml,
							   [Delim("(*", "*)")],
							   defaultStringDelims,
							   FileContent.sourceCode, FileKindDetection.equalsWhatsGiven);

		txtFKinds ~= new FKind("Parrot", [], ["pir", "pasm", "pmc", "ops", "pod", "pg", "tg", ], [], 0, [], keywordsOCaml,
							   [Delim("#"),
								Delim("^=", /+ TODO: Needs beginning of line instead of ^ +/
									  "=cut")],
							   defaultStringDelims,
							   FileContent.sourceCode, FileKindDetection.equalsWhatsGiven);

		static immutable keywordsProlog = [];
		txtFKinds ~= new FKind("Prolog", [], ["pl", "pro", "P"], [], 0, [], keywordsProlog,
							   [],
							   [],
							   FileContent.sourceCode, FileKindDetection.equalsWhatsGiven);

		auto opersD = [
			// Arithmetic
			Op("+", OpArity.binary, OpAssoc.LR, 10*2, "Add"),
			Op("-", OpArity.binary, OpAssoc.LR, 10*2, "Subtract"),
			Op("~", OpArity.binary, OpAssoc.LR, 10*2, "Concatenate"),

			Op("*", OpArity.binary, OpAssoc.LR, 11*2, "Multiply"),
			Op("/", OpArity.binary, OpAssoc.LR, 11*2, "Divide"),
			Op("%", OpArity.binary, OpAssoc.LR, 11*2, "Remainder/Moduls"),

			Op("++", OpArity.unaryPostfix, OpAssoc.LR, cast(int)(14.5*2), "Suffix increment"),
			Op("--", OpArity.unaryPostfix, OpAssoc.LR, cast(int)(14.5*2), "Suffix decrement"),

			Op("^^", OpArity.binary, OpAssoc.RL, 13*2, "Power"),

			Op("++", OpArity.unaryPrefix, OpAssoc.RL, 12*2, "Prefix increment"),
			Op("--", OpArity.unaryPrefix, OpAssoc.RL, 12*2, "Prefix decrement"),
			Op("&", OpArity.unaryPrefix, OpAssoc.RL, 12*2, "Address off"),
			Op("*", OpArity.unaryPrefix, OpAssoc.RL, 12*2, "Pointer Dereference"),
			Op("+", OpArity.unaryPrefix, OpAssoc.RL, 12*2, "Unary Plus"),
			Op("-", OpArity.unaryPrefix, OpAssoc.RL, 12*2, "Unary Minus"),
			Op("!", OpArity.unaryPrefix, OpAssoc.RL, 12*2, "Logical NOT"), /+ TODO: Convert to math in smallcaps NOT +/
			Op("~", OpArity.unaryPrefix, OpAssoc.LR, 12*2, "Bitwise NOT (One's Complement)"),

			// Bit shift
			Op("<<", OpArity.binary, OpAssoc.LR, 9*2, "Bitwise left shift"),
			Op(">>", OpArity.binary, OpAssoc.LR, 9*2, "Bitwise right shift"),

			// Comparison
			Op("==", OpArity.binary, OpAssoc.LR, 6*2, "Equal to"),
			Op("!=", OpArity.binary, OpAssoc.LR, 6*2, "Not equal to"),
			Op("<", OpArity.binary, OpAssoc.LR, 6*2, "Less than"),
			Op(">", OpArity.binary, OpAssoc.LR, 6*2, "Greater than"),
			Op("<=", OpArity.binary, OpAssoc.LR, 6*2, "Less than or equal to"),
			Op(">=", OpArity.binary, OpAssoc.LR, 6*2, "Greater than or equal to"),
			Op("in", OpArity.binary, OpAssoc.LR, 6*2, "In"),
			Op("!in", OpArity.binary, OpAssoc.LR, 6*2, "Not In"),
			Op("is", OpArity.binary, OpAssoc.LR, 6*2, "Is"),
			Op("!is", OpArity.binary, OpAssoc.LR, 6*2, "Not Is"),

			Op("&", OpArity.binary, OpAssoc.LR, 8*2, "Bitwise AND"),
			Op("^", OpArity.binary, OpAssoc.LR, 7*2, "Bitwise XOR (exclusive or)"),
			Op("|", OpArity.binary, OpAssoc.LR, 6*2, "Bitwise OR"),

			Op("&&", OpArity.binary, OpAssoc.LR, 5*2, "Logical AND"), /+ TODO: Convert to math in smallcaps AND +/
			Op("||", OpArity.binary, OpAssoc.LR, 4*2, "Logical OR"), /+ TODO: Convert to math in smallcaps OR +/

			// Assignment Arithmetic (binary)
			Op("=", OpArity.binary, OpAssoc.RL, 2*2, "Assign"),
			Op("+=", OpArity.binary, OpAssoc.RL, 2*2, "Assignment by sum"),
			Op("-=", OpArity.binary, OpAssoc.RL, 2*2, "Assignment by difference"),
			Op("*=", OpArity.binary, OpAssoc.RL, 2*2, "Assignment by product"),
			Op("/=", OpArity.binary, OpAssoc.RL, 2*2, "Assignment by quotient"),
			Op("%=", OpArity.binary, OpAssoc.RL, 2*2, "Assignment by remainder"),
			Op("&=", OpArity.binary, OpAssoc.RL, 2*2, "Assignment by bitwise AND"),
			Op("|=", OpArity.binary, OpAssoc.RL, 2*2, "Assignment by bitwise OR"),
			Op("^=", OpArity.binary, OpAssoc.RL, 2*2, "Assignment by bitwise XOR"),
			Op("<<=", OpArity.binary, OpAssoc.RL, 2*2, "Assignment by bitwise left shift"),
			Op(">>=", OpArity.binary, OpAssoc.RL, 2*2, "Assignment by bitwise right shift"),

			Op(",", OpArity.binary, OpAssoc.LR, 1*2, "Comma"),
			Op("..", OpArity.binary, OpAssoc.LR, cast(int)(0*2), "Range separator"),
			];

		enum interpretersForD = ["rdmd",
								 "gdmd"];
		auto magicForD = shebangLine(alt(lit("rdmd"),
										 lit("gdmd")));

		static immutable keywordsD = [`@property`, `@safe`, `@trusted`, `@system`, `@disable`, `abstract`, `alias`, `align`, `asm`, `assert`, `auto`, `body`, `bool`, `break`, `byte`, `case`, `cast`, `catch`,
									  `cdouble`, `cent`, `cfloat`, `char`, `class`, `const`, `continue`, `creal`, `dchar`, `debug`, `default`, `delegate`, `delete`, `deprecated`,
									  `do`, `double`, `else`, `enum`, `export`, `extern`, `false`, `final`, `finally`, `float`, `for`, `foreach`, `foreach_reverse`,
									  `function`, `goto`, `idouble`, `if`, `ifloat`, `immutable`, `import`, `in`, `inout`, `int`, `interface`, `invariant`, `ireal`,
									  `is`, `lazy`, `long`, `macro`, `mixin`, `module`, `new`, `nothrow`, `null`, `out`, `override`, `package`, `pragma`, `private`,
									  `protected`, `public`, `pure`, `real`, `ref`, `return`, `scope`, `shared`, `short`, `static`, `struct`, `super`, `switch`,
									  `synchronized`, `template`, `this`, `throw`, `true`, `try`, `typedef`, `typeid`, `typeof`, `ubyte`, `ucent`, `uint`, `ulong`,
									  `union`, `unittest`, `ushort`, `version`, `void`, `volatile`, `wchar`, `while`, `with`, `__gshared`,
									  `__thread`, `__traits`,
									  `string`, `wstring`, `dstring`, `size_t`, `hash_t`, `ptrdiff_t`, `equals_`]; // aliases

		static immutable builtinsD = [`toString`, `toHash`, `opCmp`, `opEquals`,
						  `opUnary`, `opBinary`, `opApply`, `opCall`, `opAssign`, `opIndexAssign`, `opSliceAssign`, `opOpAssign`,
						  `opIndex`, `opSlice`, `opDispatch`,
						  `toString`, `toHash`, `opCmp`, `opEquals`, `Monitor`, `factory`, `classinfo`, `vtbl`, `offset`, `getHash`, `equals`, `compare`, `tsize`, `swap`, `next`, `init`, `flags`, `offTi`, `destroy`, `postblit`, `toString`, `toHash`,
						  `factory`, `classinfo`, `Throwable`, `Exception`, `Error`, `capacity`, `reserve`, `assumeSafeAppend`, `clear`,
						  `ModuleInfo`, `ClassInfo`, `MemberInfo`, `TypeInfo`];

		static immutable propertiesD = [`sizeof`, `stringof`, `mangleof`, `nan`, `init`, `alignof`, `max`, `min`, `infinity`, `epsilon`, `mant_dig`, ``,
							`max_10_exp`, `max_exp`, `min_10_exp`, `min_exp`, `min_normal`, `re`, `im`];

		static immutable specialsD = [`__FILE__`, `__LINE__`, `__DATE__`, `__EOF__`, `__TIME__`, `__TIMESTAMP__`, `__VENDOR__`, `__VERSION__`, `#line`];

		auto kindDInterface = new FKind("D Interface", [], ["di"],
										magicForD, 0,
										[],
										keywordsD,
										dCommentDelims,
										defaultStringDelims,
										FileContent.sourceCode,
										FileKindDetection.equalsNameOrContents,
										Lang.d);
		kindDInterface.operations ~= tuple(FOp.checkSyntax, `gdc -fsyntax-only`);
		kindDInterface.operations ~= tuple(FOp.checkSyntax, `dmd -debug -wi -c -o-`); /+ TODO: Include paths +/
		txtFKinds ~= kindDInterface;

		auto kindDDoc = new FKind("D Documentation", [], ["dd"],
								  magicForD, 0,
								  [],
								  keywordsD,
								  dCommentDelims,
								  defaultStringDelims,
								  FileContent.sourceCode,
								  FileKindDetection.equalsNameOrContents);
		txtFKinds ~= kindDDoc;

		auto kindD = new FKind("D", [], ["d", "di"],
							   magicForD, 0,
							   [],
							   keywordsD,
							   dCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode,
							   FileKindDetection.equalsNameOrContents,
							   Lang.d);
		kindD.operations ~= tuple(FOp.checkSyntax, `gdc -fsyntax-only`);
		kindD.operations ~= tuple(FOp.checkSyntax, `dmd -debug -wi -c -o-`); /+ TODO: Include paths +/
		txtFKinds ~= kindD;

		auto kindDi = new FKind("D Interface", [], ["di"],
								magicForD, 0,
								[],
								keywordsD,
								dCommentDelims,
								defaultStringDelims,
								FileContent.sourceCode,
								FileKindDetection.equalsNameOrContents,
								Lang.d);
		kindDi.operations ~= tuple(FOp.checkSyntax, `gdc -fsyntax-only`);
		kindDi.operations ~= tuple(FOp.checkSyntax, `dmd -debug -wi -c -o-`); /+ TODO: Include paths +/
		txtFKinds ~= kindDi;

		static immutable keywordsRust = ["as", "box", "break", "continue", "crate",
										 "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
										 "let", "loop", "match", "mod", "mut", "priv", "proc", "pub", "ref",
										 "return", "self", "static", "struct", "super", "true", "trait",
										 "type", "unsafe", "use", "while"];

		auto kindRust = new FKind("Rust", [], ["rs"],
								  [], 0,
								  [],
								  keywordsRust,
								  cCommentDelims,
								  defaultStringDelims,
								  FileContent.sourceCode,
								  FileKindDetection.equalsNameOrContents,
								  Lang.rust);
		txtFKinds ~= kindRust;

		static immutable keywordsFortran77 = ["if", "else"];
		/+ TODO: Support .h files but require it to contain some Fortran-specific or be parseable. +/
		auto kindFortan = new FKind("Fortran", [], ["f", "fortran", "f77", "f90", "f95", "f03", "for", "ftn", "fpp"], [], 0, [], keywordsFortran77,
									[Delim("^C")], /+ TODO: Need beginning of line instead ^. seq(bol(), alt(lit('C'), lit('c'))); /+ TODO: Add chars chs("cC"); +/ +/
									defaultStringDelims,
									FileContent.sourceCode,
									FileKindDetection.equalsNameOrContents,
									Lang.fortran);
		kindFortan.operations ~= tuple(FOp.checkSyntax, `gcc -x fortran -fsyntax-only`);
		txtFKinds ~= kindFortan;

		// Ada
		import nxt.ada_defs;
		static immutable keywordsAda83 = ada_defs.keywords83;
		static immutable keywordsAda95 = keywordsAda83 ~ ada_defs.keywordsNew95;
		static immutable keywordsAda2005 = keywordsAda95 ~ ada_defs.keywordsNew2005;
		static immutable keywordsAda2012 = keywordsAda2005 ~ ada_defs.keywordsNew2012;
		static immutable extsAda = ["ada", "adb", "ads"];
		txtFKinds ~= new FKind("Ada 82", [], extsAda, [], 0, [], keywordsAda83,
							   [Delim("--")],
							   defaultStringDelims,
							   FileContent.sourceCode);
		txtFKinds ~= new FKind("Ada 95", [], extsAda, [], 0, [], keywordsAda95,
							   [Delim("--")],
							   defaultStringDelims,
							   FileContent.sourceCode);
		txtFKinds ~= new FKind("Ada 2005", [], extsAda, [], 0, [], keywordsAda2005,
							   [Delim("--")],
							   defaultStringDelims,
							   FileContent.sourceCode);
		txtFKinds ~= new FKind("Ada 2012", [], extsAda, [], 0, [], keywordsAda2012,
							   [Delim("--")],
							   defaultStringDelims,
							   FileContent.sourceCode);
		txtFKinds ~= new FKind("Ada", [], extsAda, [], 0, [], keywordsAda2012,
							   [Delim("--")],
							   defaultStringDelims,
							   FileContent.sourceCode);

		auto aliKind = new FKind("Ada Library File", [], ["ali"], [], 0, `V "GNAT Lib v`, [],
								 [], // N/A
								 defaultStringDelims,
								 FileContent.fingerprint); /+ TODO: Parse version following magic tag? +/
		aliKind.machineGenerated = true;
		txtFKinds ~= aliKind;

		txtFKinds ~= new FKind("Pascal", [], ["pas", "pascal"], [], 0, [], [],
							   [Delim("(*", "*)"),// Old-Style
								Delim("{", "}"),// Turbo Pascal
								Delim("//")],// Delphi
							   defaultStringDelims,
							   FileContent.sourceCode, FileKindDetection.equalsContents);
		txtFKinds ~= new FKind("Delphi", [], ["pas", "int", "dfm", "nfm", "dof", "dpk", "dproj", "groupproj", "bdsgroup", "bdsproj"],
							   [], 0, [], [],
							   [Delim("//")],
							   defaultStringDelims,
							   FileContent.sourceCode, FileKindDetection.equalsContents);

		txtFKinds ~= new FKind("Objective-C", [], ["m"], [], 0, [], [],
							   cCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode);

		static immutable keywordsPython = ["and", "del", "for", "is", "raise", "assert", "elif", "from", "lambda", "return",
							   "break", "else", "global", "not", "try", "class", "except", "if", "or", "while",
							   "continue", "exec", "import", "pass", "yield", "def", "finally", "in", "print"];

		// Scripting

		auto kindPython = new FKind("Python", [], ["py"],
									shebangLine(lit("python")), 0, [],
									keywordsPython,
									defaultCommentDelims,
									pythonStringDelims,
									FileContent.scriptCode);
		txtFKinds ~= kindPython;

		txtFKinds ~= new FKind("Ruby", [], ["rb", "rhtml", "rjs", "rxml", "erb", "rake", "spec", ],
							   shebangLine(lit("ruby")), 0,
							   [], [],
							   [Delim("#"), Delim("=begin", "=end")],
							   defaultStringDelims,
							   FileContent.scriptCode);

		txtFKinds ~= new FKind("Scala", [], ["scala", ],
							   shebangLine(lit("scala")), 0,
							   [], [],
							   cCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("Scheme", [], ["scm", "ss"],
							   [], 0,
							   [], [],
							   [Delim(";")],
							   defaultStringDelims,
							   FileContent.scriptCode);

		txtFKinds ~= new FKind("Smalltalk", [], ["st"], [], 0, [], [],
							   [Delim("\"", "\"")],
							   defaultStringDelims,
							   FileContent.sourceCode);

		txtFKinds ~= new FKind("Perl", [], ["pl", "pm", "pm6", "pod", "t", "psgi", ],
							   shebangLine(lit("perl")), 0,
							   [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("PHP", [], ["php", "phpt", "php3", "php4", "php5", "phtml", ],
							   shebangLine(lit("php")), 0,
							   [], [],
							   defaultCommentDelims ~ cCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("Plone", [], ["pt", "cpt", "metadata", "cpy", "py", ], [], 0, [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);

		txtFKinds ~= new FKind("Shell", [], ["sh"],
							   shebangLine(lit("sh")), 0,
							   [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("Bash", [], ["bash"],
							   shebangLine(lit("bash")), 0,
							   [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("Zsh", [], ["zsh"],
							   shebangLine(lit("zsh")), 0,
							   [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);

		txtFKinds ~= new FKind("Batch", [], ["bat", "cmd"], [], 0, [], [],
							   [Delim("REM")],
							   defaultStringDelims,
							   FileContent.scriptCode);

		txtFKinds ~= new FKind("TCL", [], ["tcl", "itcl", "itk", ], [], 0, [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("Tex", [], ["tex", "cls", "sty", ], [], 0, [], [],
							   [Delim("%")],
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("TT", [], ["tt", "tt2", "ttml", ], [], 0, [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("Viz Basic", [], ["bas", "cls", "frm", "ctl", "vb", "resx", ], [], 0, [], [],
							   [Delim("'")],
							   defaultStringDelims,
							   FileContent.scriptCode);

		txtFKinds ~= new FKind("Verilog", [], ["v", "vh", "sv"], [], 0, [], [],
							   cCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("VHDL", [], ["vhd", "vhdl"], [], 0, [], [],
							   [Delim("--")],
							   defaultStringDelims,
							   FileContent.scriptCode);

		txtFKinds ~= new FKind("Clojure", [], ["clj"], [], 0, [], [],
							   [Delim(";")],
							   defaultStringDelims,
							   FileContent.sourceCode);
		txtFKinds ~= new FKind("Go", [], ["go"], [], 0, [], [],
							   cCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode);

		auto kindJava = new FKind("Java", [], ["java", "properties"], [], 0, [], [],
								  cCommentDelims,
								  defaultStringDelims,
								  FileContent.sourceCode);
		txtFKinds ~= kindJava;
		kindJava.operations ~= tuple(FOp.byteCompile, `javac`);

		txtFKinds ~= new FKind("Groovy", [], ["groovy", "gtmpl", "gpp", "grunit"], [], 0, [], [],
							   cCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode);
		txtFKinds ~= new FKind("Haskell", [], ["hs", "lhs"], [], 0, [], [],
							   [Delim("--}"),
								Delim("{-", "-}")],
							   defaultStringDelims,
							   FileContent.sourceCode);

		static immutable keywordsJavascript = ["break", "case", "catch", "continue", "debugger", "default", "delete",
											   "do", "else", "finally", "for", "function", "if", "in", "instanceof",
											   "new", "return", "switch", "this", "throw", "try", "typeof", "var",
											   "void", "while", "with" ];
		txtFKinds ~= new FKind("JavaScript", [], ["js"],
							   [], 0, [],
							   keywordsJavascript,
							   cCommentDelims,
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("JavaScript Object Notation",
							   [], ["json"],
							   [], 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.sourceCode);

		auto dubFKind = new FKind("DUB",
								  ["dub.json"], ["json"],
								  [], 0, [], [],
								  [], // N/A
								  defaultStringDelims,
								  FileContent.scriptCode);
		txtFKinds ~= dubFKind;
		dubFKind.operations ~= tuple(FOp.build, `dub`);

		/+ TODO: Inherit XML +/
		txtFKinds ~= new FKind("JSP", [], ["jsp", "jspx", "jhtm", "jhtml"], [], 0, [], [],
							   [Delim("<!--", "--%>"), // XML
								Delim("<%--", "--%>")],
							   defaultStringDelims,
							   FileContent.scriptCode);

		txtFKinds ~= new FKind("ActionScript", [], ["as", "mxml"], [], 0, [], [],
							   cCommentDelims, // N/A
							   defaultStringDelims,
							   FileContent.scriptCode);

		txtFKinds ~= new FKind("LUA", [], ["lua"], [], 0, [], [],
							   [Delim("--")],
							   defaultStringDelims,
							   FileContent.scriptCode);
		txtFKinds ~= new FKind("Mason", [], ["mas", "mhtml", "mpl", "mtxt"], [], 0, [], [],
							   [], /+ TODO: Need symbolic +/
							   defaultStringDelims,
							   FileContent.scriptCode);

		txtFKinds ~= new FKind("CFMX", [], ["cfc", "cfm", "cfml"], [], 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.scriptCode);

		// Simulation
		static immutable keywordsModelica = ["algorithm", "discrete", "false", "loop", "pure",
											 "and", "each", "final", "model", "record",
											 "annotation", "else", "flow", "not", "redeclare",
											 "elseif", "for", "operator", "replaceable",
											 "block", "elsewhen", "function", "or", "return",
											 "break", "encapsulated", "if", "outer", "stream",
											 "class", "end", "import", "output", "then",
											 "connect", "enumeration", "impure", "package", "true",
											 "connector", "equation", "in", "parameter", "type",
											 "constant", "expandable", "initial", "partial", "when",
											 "constrainedby", "extends", "inner", "protected", "while",
											 "der", "external", "input", "public", "within"];
		auto kindModelica = new FKind("Modelica", [], ["mo"], [], 0, [],
									  keywordsModelica,
									  cCommentDelims,
									  defaultStringDelims,
									  FileContent.sourceCode,
									  FileKindDetection.equalsWhatsGiven,
									  Lang.modelica);

		// Numerical Computing

		txtFKinds ~= new FKind("Matlab", [], ["m"], [], 0, [], [],
							   [Delim("%{", "}%"), /+ TODO: Prio 1 +/
								Delim("%")], /+ TODO: Prio 2 +/
							   defaultStringDelims,
							   FileContent.sourceCode);
		auto kindOctave = new FKind("Octave", [], ["m"], [], 0, [], [],
									[Delim("%{", "}%"), /+ TODO: Prio 1 +/
									 Delim("%"),
									 Delim("#")],
									defaultStringDelims,
									FileContent.sourceCode);
		txtFKinds ~= kindOctave;
		kindOctave.operations ~= tuple(FOp.byteCompile, `octave`);

		txtFKinds ~= new FKind("Julia", [], ["jl"], [], 0, [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode); // ((:execute "julia") (:evaluate "julia -e"))

		txtFKinds ~= new FKind("Erlang", [], ["erl", "hrl"], [], 0, [], [],
							   [Delim("%")],
							   defaultStringDelims,
							   FileContent.sourceCode);

		auto magicForElisp = seq(shebangLine(lit("emacs")),
								 ws(),
								 lit("--script"));
		auto kindElisp = new FKind("Emacs-Lisp", [],
								   ["el", "lisp"],
								   magicForElisp, 0, // Script Execution
								   [], [],
								   [Delim(";")],
								   defaultStringDelims,
								   FileContent.sourceCode);
		kindElisp.operations ~= tuple(FOp.byteCompile, `emacs -batch -f batch-byte-compile`);
		kindElisp.operations ~= tuple(FOp.byteCompile, `emacs --script`);
		/* kindELisp.moduleName = "(provide 'MODULE_NAME)"; */
		/* kindELisp.moduleImport = "(require 'MODULE_NAME)"; */
		txtFKinds ~= kindElisp;

		txtFKinds ~= new FKind("Lisp", [], ["lisp", "lsp"], [], 0, [], [],
							   [Delim(";")],
							   defaultStringDelims,
							   FileContent.sourceCode);
		txtFKinds ~= new FKind("PostScript", [], ["ps", "postscript"], [], 0, "%!", [],
							   [Delim("%")],
							   defaultStringDelims,
							   FileContent.sourceCode);

		txtFKinds ~= new FKind("CMake", [], ["cmake"], [], 0, [], [],
							   defaultCommentDelims,
							   defaultStringDelims,
							   FileContent.sourceCode);

		// http://stackoverflow.com/questions/277521/how-to-identify-the-file-content-as-ascii-or-binary
		txtFKinds ~= new FKind("Pure ASCII", [], ["ascii", "txt", "text", "README", "INSTALL"], [], 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.textASCII); // NOTE: Extend with matcher where all bytes are in either: 9–13 or 32–126
		txtFKinds ~= new FKind("8-Bit Text", [], ["ascii", "txt", "text", "README", "INSTALL"], [], 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.text8Bit); // NOTE: Extend with matcher where all bytes are in either: 9–13 or 32–126 or 128–255

		txtFKinds ~= new FKind("Assembler", [], ["asm", "s"], [], 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.sourceCode);

		// https://en.wikipedia.org/wiki/Diff
		auto diffKind = new FKind("Diff", [], ["diff", "patch"],
								  "diff", 0,
								  [], [],
								  [], // N/A
								  defaultStringDelims,
								  FileContent.text);
		txtFKinds ~= diffKind;
		diffKind.wikip = "https://en.wikipedia.org/wiki/Diff";

		auto pemCertKind = new FKind(`PEM certificate`, [], [`cert`],
									 `-----BEGIN CERTIFICATE-----`, 0,
									 [], [],
									 [], // N/A
									 [], // N/A
									 FileContent.text,
									 FileKindDetection.equalsContents);
		txtFKinds ~= pemCertKind;

		auto pemCertReqKind = new FKind(`PEM certificate request`, [], [`cert`],
										`-----BEGIN CERTIFICATE REQ`, 0,
										[], [],
										[], // N/A
										[], // N/A
										FileContent.text,
										FileKindDetection.equalsContents);
		txtFKinds ~= pemCertReqKind;

		auto pemRSAPrivateKeyKind = new FKind(`PEM RSA private key`, [], [`cert`],
											  `-----BEGIN RSA PRIVATE`, 0,
											  [], [],
											  [], // N/A
											  [], // N/A
											  FileContent.text,
											  FileKindDetection.equalsContents);
		txtFKinds ~= pemRSAPrivateKeyKind;

		auto pemDSAPrivateKeyKind = new FKind(`PEM DSA private key`, [], [`cert`],
											  `-----BEGIN DSA PRIVATE`, 0,
											  [], [],
											  [], // N/A
											  [], // N/A
											  FileContent.text,
											  FileKindDetection.equalsContents);
		txtFKinds ~= pemDSAPrivateKeyKind;

		auto pemECPrivateKeyKind = new FKind(`PEM EC private key`, [], [`cert`],
											  `-----BEGIN EC PRIVATE`, 0,
											  [], [],
											  [], // N/A
											  [], // N/A
											  FileContent.text,
											  FileKindDetection.equalsContents);
		txtFKinds ~= pemECPrivateKeyKind;

		// Binaries

		static immutable extsELF = ["o", "so", "ko", "os", "out", "bin", "x", "elf", "axf", "prx", "puff", "none"]; // ELF file extensions

		auto elfKind = new FKind("ELF",
								 [], extsELF, x"7F 45 4C 46", 0, [], [],
								 [], // N/A
								 [], // N/A
								 FileContent.machineCode,
								 FileKindDetection.equalsContents);
		elfKind.wikip = "https://en.wikipedia.org/wiki/Executable_and_Linkable_Format";
		binFKinds ~= elfKind;
		/* auto extsExeELF = ["out", "bin", "x", "elf", ]; // ELF file extensions */
		/* auto elfExeKind  = new FKind("ELF executable",	[], extsExeELF,  [0x2, 0x0], 16, [], [], FileContent.machineCode, FileKindDetection.equalsContents, elfKind); */
		/* auto elfSOKind   = new FKind("ELF shared object", [], ["so", "ko"],  [0x3, 0x0], 16, [], [], FileContent.machineCode, FileKindDetection.equalsContents, elfKind); */
		/* auto elfCoreKind = new FKind("ELF core file",	 [], ["core"], [0x4, 0x0], 16, [], [], FileContent.machineCode, FileKindDetection.equalsContents, elfKind); */
		/* binFKinds ~= elfExeKind; */
		/* elfKind.subKinds ~= elfSOKind; */
		/* elfKind.subKinds ~= elfCoreKind; */
		/* elfKind.subKinds ~= elfKind; */

		/+ TODO: Specialize to not steal results from file's magics. +/
		auto linuxFirmwareKind = new FKind("Linux Firmware",
								 [], ["bin", "ucode", "dat", "sbcf", "fw"], [], 0, [], [],
								 [], // N/A
								 [], // N/A
								 FileContent.binaryUnknown,
								 FileKindDetection.equalsParentPathDirsAndName);
		linuxFirmwareKind.parentPathDirs = ["lib", "firmware"];
		binFKinds ~= linuxFirmwareKind;

		/+ TODO: Specialize to not steal results from file's magics. +/
		auto linuxHwDbKind = new FKind("Linux Hardware Database Index",
									   "hwdb.bin", ["bin"], "KSLPHHRH", 0, [], [],
									   [], // N/A
									   [], // N/A
									   FileContent.binaryUnknown,
									   FileKindDetection.equalsNameAndContents);
		binFKinds ~= linuxHwDbKind;

		// Executables
		binFKinds ~= new FKind("Mach-O", [], ["o"], x"CE FA ED FE", 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.machineCode, FileKindDetection.equalsContents);

		binFKinds ~= new FKind("modules.symbols.bin", [], ["bin"],
							   cast(ubyte[])[0xB0, 0x07, 0xF4, 0x57, 0x00, 0x02, 0x00, 0x01, 0x20], 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.binaryUnknown, FileKindDetection.equalsContents);

		auto kindCOFF = new FKind("COFF/i386/32", [], ["o"], x"4C 01", 0, [], [],
								  [], // N/A
								  [], // N/A
								  FileContent.machineCode, FileKindDetection.equalsContents);
		kindCOFF.description = "Common Object File Format";
		binFKinds ~= kindCOFF;

		auto kindPECOFF = new FKind("PE/COFF", [], ["cpl", "exe", "dll", "ocx", "sys", "scr", "drv", "obj"],
									"PE\0\0", 0x60, // And ("MZ") at offset 0x0
									[], [],
									[], // N/A
									[], // N/A
									FileContent.machineCode, FileKindDetection.equalsContents);
		kindPECOFF.description = "COFF Portable Executable";
		binFKinds ~= kindPECOFF;

		auto kindDOSMZ = new FKind("DOS-MZ", [], ["exe", "dll"], "MZ", 0, [], [],
								   [], // N/A
								   [], // N/A
								   FileContent.machineCode);
		kindDOSMZ.description = "MS-DOS, OS/2 or MS Windows executable";
		binFKinds ~= kindDOSMZ;

		// Caches
		binFKinds ~= new FKind("ld.so.cache", [], ["cache"], "ld.so-", 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.binaryCache);

		// Profile Data
		binFKinds ~= new FKind("perf benchmark data", [], ["data"], "PERFILE2h", 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.performanceBenchmark);

		// Images
		binFKinds ~= new FKind("GIF87a", [], ["gif"], "GIF87a", 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.image);
		binFKinds ~= new FKind("GIF89a", [], ["gif"], "GIF89a", 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.image);
		auto extJPEG = ["jpeg", "jpg", "j2k", "jpeg2000"];
		binFKinds ~= new FKind("JPEG", [], extJPEG, x"FF D8", 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.image); /+ TODO: Support ends with [0xFF, 0xD9] +/
		binFKinds ~= new FKind("JPEG/JFIF", [], extJPEG, x"FF D8", 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.image); /+ TODO: Support ends with ['J','F','I','F', 0x00] +/
		binFKinds ~= new FKind("JPEG/Exif", [], extJPEG, x"FF D8", 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.image); /+ TODO: Support contains ['E','x','i','f', 0x00] followed by metadata +/

		binFKinds ~= new FKind("Pack200-Compressed Java Bytes Code", [], ["class"], x"CA FE BA BE", 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.machineCode);

		binFKinds ~= new FKind("JRun Server Application", [], ["jsa"],
							   cast(ubyte[])[0xa2,0xab,0x0b,0xf0,
											 0x01,0x00,0x00,0x00,
											 0x00,0x00,0x20,0x00], 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.machineCode);

		binFKinds ~= new FKind("PNG", [], ["png"],
							   cast(ubyte[])[137, 80, 78, 71, 13, 10, 26, 10], 0, [], [],
							   [], // N/A
							   [], // N/A
							   FileContent.image);

		auto icnsKind = new FKind("Apple Icon Image", [], ["icns"],
								  "icns", 0, [], [],
								  [], // N/A
								  [], // N/A
								  FileContent.imageIcon);
		icnsKind.wikip = "https://en.wikipedia.org/wiki/Apple_Icon_Image_format";
		binFKinds ~= icnsKind;
		/+ TODO: read with http://icns.sourceforge.net/ +/

		auto kindPDF = new FKind("PDF", [], ["pdf"], "%PDF", 0, [], [],
								 [], // N/A
								 [], // N/A
								 FileContent.document);
		kindPDF.description = "Portable Document Format";
		binFKinds ~= kindPDF;

		auto kindMarkdownFmt = new FKind("Markdown", [], ["md", "markdown"],
										 [], 0,
										 [], [],
										 [], // N/A
										 defaultStringDelims,
										 FileContent.binaryCache);
		kindMarkdownFmt.wikip = "https://en.wikipedia.org/wiki/Markdown";
		binFKinds ~= kindMarkdownFmt;

		auto kindAsciiDocFmt = new FKind("AsciiDoc", [], ["ad", "adoc", "asciidoc"],
										 [], 0,
										 [], [],
										 [], // N/A
										 defaultStringDelims,
										 FileContent.binaryCache);
		binFKinds ~= kindAsciiDocFmt;

		auto kindLatexPDFFmt = new FKind("LaTeX PDF Format", [], ["fmt"],
										 cast(ubyte[])['W','2','T','X',
													   0x00,0x00,0x00,0x08,
													   0x70,0x64,0x66,0x74,
													   0x65,0x78], 0, [], [],
										 [], // N/A
										 defaultStringDelims,
										 FileContent.binaryCache);
		binFKinds ~= kindLatexPDFFmt;

		binFKinds ~= new FKind("Microsoft Office Document", [], ["doc", "docx", "xls", "ppt"], x"D0 CF 11 E0", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.document);

		// Fonts

		auto kindTTF = new FKind("TrueType Font", [], ["ttf"], x"00 01 00 00 00", 0, [], [],
								 [], // N/A
								 defaultStringDelims,
								 FileContent.font);
		binFKinds ~= kindTTF;

		auto kindTTCF = new FKind("TrueType/OpenType Font Collection", [], ["ttc"], "ttcf", 0, [], [],
								  [], // N/A
								  defaultStringDelims,
								  FileContent.font);
		binFKinds ~= kindTTCF;

		auto kindWOFF = new FKind("Web Open Font", [], ["woff"], "wOFF", 0, [], [],
								  [], // N/A
								  defaultStringDelims,
								  FileContent.font); /+ TODO: container for kindSFNT +/
		binFKinds ~= kindWOFF;

		auto kindSFNT = new FKind("Spline Font", [], ["sfnt"], "sfnt", 0, [], [],
								  [], // N/A
								  defaultStringDelims,
								  FileContent.font); /+ TODO: container for Sfnt +/
		binFKinds ~= kindSFNT;

		// Audio

		binFKinds ~= new FKind("MIDI", [], ["mid", "midi"], "MThd", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.audio, FileKindDetection.equalsNameAndContents);

		// Au
		auto auKind = new FKind("Au", [], ["au", "snd"], ".snd", 0, [], [],
								[], // N/A
								defaultStringDelims,
								FileContent.audio, FileKindDetection.equalsNameAndContents);
		auKind.wikip = "https://en.wikipedia.org/wiki/Au_file_format";
		binFKinds ~= auKind;

		binFKinds ~= new FKind("Ogg", [], ["ogg", "oga", "ogv"],
							   cast(ubyte[])[0x4F,0x67,0x67,0x53,
											 0x00,0x02,0x00,0x00,
											 0x00,0x00,0x00,0x00,
											 0x00, 0x00], 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.media);

		/+ TODO: Support RIFF....WAVEfmt using symbolic seq(lit("RIFF"), any(4), lit("WAVEfmt")) +/
		binFKinds ~= new FKind("WAV", [], ["wav", "wave"], "RIFF", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.audio, FileKindDetection.equalsContents);

		// Archives

		auto kindBSDAr = new FKind("BSD Archive", [], ["a", "ar"], "!<arch>\n", 0, [], [],
								   [], // N/A
								   defaultStringDelims,
								   FileContent.archive, FileKindDetection.equalsContents);
		kindBSDAr.description = "BSD 4.4 and Mac OSX Archive";
		binFKinds ~= kindBSDAr;

		binFKinds ~= new FKind("GNU tar Archive", [], ["tar"], "ustar\040\040\0", 257, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.archive, FileKindDetection.equalsContents); /+ TODO: Specialized Derivation of "POSIX tar Archive" +/
		binFKinds ~= new FKind("POSIX tar Archive", [], ["tar"], "ustar\0", 257, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.archive, FileKindDetection.equalsContents);

		binFKinds ~= new FKind("pkZip Archive", [], ["zip", "jar", "pptx", "docx", "xlsx"], "PK\003\004", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.archive, FileKindDetection.equalsContents);
		binFKinds ~= new FKind("pkZip Archive (empty)", [], ["zip", "jar"], "PK\005\006", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.archive, FileKindDetection.equalsContents);

		binFKinds ~= new FKind("PAK file", [], ["pak"], cast(ubyte[])[0x40, 0x00, 0x00, 0x00,
																	  0x4a, 0x12, 0x00, 0x00,
																	  0x01, 0x2d, 0x23, 0xcb,
																	  0x6d, 0x00, 0x00, 0x2f], 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.spellCheckWordList,
							   FileKindDetection.equalsNameAndContents);

		binFKinds ~= new FKind("LZW-Compressed", [], ["z", "tar.z"], x"1F 9D", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.compressed);
		binFKinds ~= new FKind("LZH-Compressed", [], ["z", "tar.z"], x"1F A0", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.compressed);

		binFKinds ~= new FKind("CompressedZ", [], ["z"], "\037\235", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.compressed);
		binFKinds ~= new FKind("GNU-Zip (gzip)", [], ["tgz", "gz", "gzip", "dz"], "\037\213", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.compressed);
		binFKinds ~= new FKind("BZip", [], ["bz2", "bz", "tbz2", "bzip2"], "BZh", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.compressed);
		binFKinds ~= new FKind("XZ/7-Zip", [], ["xz", "txz", "7z", "t7z", "lzma", "tlzma", "lz", "tlz"],
							   cast(ubyte[])[0xFD, '7', 'z', 'X', 'Z', 0x00], 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.compressed);
		binFKinds ~= new FKind("LZX", [], ["lzx"], "LZX", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.compressed);
		binFKinds ~= new FKind("SZip", [], ["szip"], "SZ\x0a\4", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.compressed);

		binFKinds ~= new FKind("Git Bundle", [], ["bundle"], "# v2 git bundle", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.versionControl);

		binFKinds ~= new FKind("Emacs-Lisp Bytes Code", [], ["elc"], ";ELC\27\0\0\0", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.byteCode, FileKindDetection.equalsContents);
		binFKinds ~= new FKind("Python Bytes Code", [], ["pyc"], x"0D 0A", 2, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.byteCode, FileKindDetection.equalsNameAndContents); /+ TODO: Handle versions at src[0..2] +/

		binFKinds ~= new FKind("Zshell Wordcode", [], ["zwc"], x"07 06 05 04", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.byteCode);

		binFKinds ~= new FKind("Java Bytes Code", [], ["class"], x"CA FE BA BE", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.byteCode, FileKindDetection.equalsContents);
		binFKinds ~= new FKind("Java KeyStore", [], [], x"FE ED FE ED", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.binaryUnknown, FileKindDetection.equalsContents);
		binFKinds ~= new FKind("Java JCE KeyStore", [], [], x"CE CE CE CE", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.binaryUnknown, FileKindDetection.equalsContents);

		binFKinds ~= new FKind("LLVM Bitcode", [], ["bc"], "BC", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.byteCode, FileKindDetection.equalsNameAndContents);

		binFKinds ~= new FKind("MATLAB MAT", [], ["mat"], "MATLAB 5.0 MAT-file", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.numericalData, FileKindDetection.equalsContents);

		auto hdf4Kind = new FKind("HDF4", [], ["hdf", "h4", "hdf4", "he4"], x"0E 03 13 01", 0, [], [],
								  [], // N/A
								  defaultStringDelims,
								  FileContent.numericalData);
		binFKinds ~= hdf4Kind;
		hdf4Kind.description = "Hierarchical Data Format version 4";

		auto hdf5Kind = new FKind("HDF5", "Hierarchical Data Format version 5", ["hdf", "h5", "hdf5", "he5"], x"89 48 44 46 0D 0A 1A 0A", 0, [], [],
								  [], // N/A
								  defaultStringDelims,
								  FileContent.numericalData);
		binFKinds ~= hdf5Kind;
		hdf5Kind.description = "Hierarchical Data Format version 5";

		auto numpyKind = new FKind("NUMPY", "NUMPY", ["npy", "numpy"], x"93 4E 55 4D 50 59", 0, [], [],
								  [], // N/A
								  defaultStringDelims,
								  FileContent.numericalData);
		binFKinds ~= numpyKind;

		binFKinds ~= new FKind("GNU GLOBAL Database", ["GTAGS", "GRTAGS", "GPATH", "GSYMS"], [], "b1\5\0", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.tagsDatabase, FileKindDetection.equalsContents);

		// SQLite
		static immutable extsSQLite = ["sql", "sqlite", "sqlite3"];
		binFKinds ~= new FKind("MySQL table definition file", [], extsSQLite, x"FE 01", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.tagsDatabase, FileKindDetection.equalsContents);
		binFKinds ~= new FKind("MySQL MyISAM index file", [], extsSQLite, x"FE FE 07", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.tagsDatabase, FileKindDetection.equalsContents);
		binFKinds ~= new FKind("MySQL MyISAM compressed data file", [], extsSQLite, x"FE FE 08", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.tagsDatabase, FileKindDetection.equalsContents);
		binFKinds ~= new FKind("MySQL Maria index file", [], extsSQLite, x"FF FF FF", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.tagsDatabase, FileKindDetection.equalsContents);
		binFKinds ~= new FKind("MySQL Maria compressed data file", [], extsSQLite, x"FF FF FF", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.tagsDatabase, FileKindDetection.equalsContents);
		binFKinds ~= new FKind("SQLite format 3", [], extsSQLite , "SQLite format 3", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.tagsDatabase, FileKindDetection.equalsContents); /+ TODO: Why is this detected at 49:th try? +/

		binFKinds ~= new FKind("Vim swap", [], ["swo"], [], 0, "b0VIM ", [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.binaryCache);

		binFKinds ~= new FKind("PCH", "(GCC) Precompiled header", ["pch", "gpch"], "gpch", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.cache);

		binFKinds ~= new FKind("Firmware", [], ["fw"], cast(ubyte[])[], 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.cache, FileKindDetection.equalsName); /+ TODO: Add check for binary contents and that some parenting directory is named "firmware" +/

		binFKinds ~= new FKind("LibreOffice or OpenOffice RDB", [], ["rdb"],
							   cast(ubyte[])[0x43,0x53,0x4d,0x48,
											 0x4a,0x2d,0xd0,0x26,
											 0x00,0x02,0x00,0x00,
											 0x00,0x02,0x00,0x02], 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.database, FileKindDetection.equalsName); /+ TODO: Add check for binary contents and that some parenting directory is named "firmware" +/

		binFKinds ~= new FKind("sconsign", [], ["sconsign", "sconsign.dblite", "dblite"], x"7d 71 01 28", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.cache, FileKindDetection.equalsNameAndContents);

		binFKinds ~= new FKind("GnuPG (GPG) key public ring", [], ["gpg"], x"99 01", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.binary, FileKindDetection.equalsNameOrContents);
		binFKinds ~= new FKind("GnuPG (GPG) encrypted data", [], [], x"85 02", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.binary, FileKindDetection.equalsContents);
		binFKinds ~= new FKind("GNUPG (GPG) key trust database", [], [], "\001gpg", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.binary, FileKindDetection.equalsContents);

		binFKinds ~= new FKind("aspell word list (rowl)", [], ["rws"], "aspell default speller rowl ", 0, [], [],
							   [], // N/A
							   defaultStringDelims,
							   FileContent.spellCheckWordList, FileKindDetection.equalsNameAndContents);

		binFKinds ~= new FKind("DS_Store", ".DS_Store", [], "Mac OS X Desktop Services Store ", 0, [], [],
							   [], // N/A
							   [],
							   FileContent.binary, FileKindDetection.equalsName);

		/* Fax image created in the CCITT Group 3 compressed format, which is
		 * used for digital transmission of fax data and supports 1 bit per
		 * pixel
		 */
		binFKinds ~= new FKind("CCITT Group 3 compressed format", [], /+ TODO: Altenative name: Digifax-G3, G3 Fax +/
							   ["g3", "G3"],
							   "PC Research, Inc", 0, [], [],
							   [], // N/A
							   [],
							   FileContent.imageModemFax1BPP, FileKindDetection.equalsContents);

		binFKinds ~= new FKind("Raw Modem Data version 1", [],
							   ["rmd1"],
							   "RMD1", 0, [], [],
							   [], // N/A
							   [],
							   FileContent.modemData, FileKindDetection.equalsContents);

		binFKinds ~= new FKind("Portable voice format 1", [],
							   ["pvf1"],
							   "PVF1\n", 0, [], [],
							   [], // N/A
							   [],
							   FileContent.voiceModem, FileKindDetection.equalsContents);

		binFKinds ~= new FKind("Portable voice format 2", [],
							   ["pvf2"],
							   "PVF2\n", 0, [], [],
							   [], // N/A
							   [],
							   FileContent.voiceModem, FileKindDetection.equalsContents);

		allFKinds ~= txtFKinds;
		allFKinds ~= binFKinds;

		assert(allFKinds.byIndex.length ==
			   (txtFKinds.byIndex.length +
				binFKinds.byIndex.length));

		assert(allFKinds.byId.length ==
			   (txtFKinds.byId.length +
				binFKinds.byId.length));

		txtFKinds.rehash;
		binFKinds.rehash;
		allFKinds.rehash;
	}

	// Code

	// Interpret Command Line
	void loadDirKinds()
	{
		vcDirKinds ~= new DirKind(".git", "Git");
		vcDirKinds ~= new DirKind(".svn", "Subversion (Svn)");
		vcDirKinds ~= new DirKind(".bzr", "Bazaar (Bzr)");
		vcDirKinds ~= new DirKind("RCS", "RCS");
		vcDirKinds ~= new DirKind("CVS", "CVS");
		vcDirKinds ~= new DirKind("MCVS", "MCVS");
		vcDirKinds ~= new DirKind("RCS", "RCS");
		vcDirKinds ~= new DirKind(".hg", "Mercurial (Hg)");
		vcDirKinds ~= new DirKind("SCCS", "SCCS");
		vcDirKinds ~= new DirKind(".wact", "WACT");
		vcDirKinds ~= new DirKind("_MTN", "Monotone");
		vcDirKinds ~= new DirKind("_darcs", "Darcs");
		vcDirKinds ~= new DirKind("{arch}", "Arch");

		skippedDirKinds ~= vcDirKinds;

		DirKind[string] vcDirKindsMap_;
		foreach (kind; vcDirKinds)
		{
			vcDirKindsMap[kind.fileName] = kind;
		}
		vcDirKindsMap.rehash;

		skippedDirKinds ~= new DirKind(".trash",  "Trash");
		skippedDirKinds ~= new DirKind(".undo",  "Undo");
		skippedDirKinds ~= new DirKind(".deps",  "Dependencies");
		skippedDirKinds ~= new DirKind(".backups",  "Backups");
		skippedDirKinds ~= new DirKind(".autom4te.cache",  "Automake Cache");

		foreach (kind; skippedDirKinds) { skippedDirKindsMap[kind.fileName] = kind; }
		skippedDirKindsMap.rehash;
	}

	ScanContext scanContext = ScanContext.standard;
	KeyStrictness keyStrictness = KeyStrictness.standard;

	bool showNameDups = false;
	bool showTreeContentDups = false;
	bool showFileContentDups = false;
	bool showELFSymbolDups = false;
	bool linkContentDups = false;

	bool showLinkDups = false;
	SymlinkFollowContext followSymlinks = SymlinkFollowContext.external;
	bool showBrokenSymlinks = true;
	bool showSymlinkCycles = true;

	bool showAnyDups = false;
	bool showMMaps = false;
	bool showUsage = false;
	bool showSHA1 = false;
	bool showLineCounts = false;

	uint64_t noFiles = 0;
	uint64_t noRegFiles = 0;
	uint64_t noSymlinks = 0;
	uint64_t noSpecialFiles = 0;
	uint64_t noDirs = 0;

	uint64_t noScannedFiles = 0;
	uint64_t noScannedRegFiles = 0;
	uint64_t noScannedSymlinks = 0;
	uint64_t noScannedSpecialFiles = 0;
	uint64_t noScannedDirs = 0;

	auto shallowDensenessSum = Rational!ulong(0, 1);
	auto deepDensenessSum = Rational!ulong(0, 1);
	uint64_t densenessCount = 0;

	FOp fOp = FOp.none;

	bool keyAsWord = false;
	bool keyAsSymbol = false;
	bool keyAsAcronym = false;
	bool keyAsExact = false;

	bool showTree = false;

	bool useHTML = false;
	bool browseOutput = false;
	bool collectTypeHits = false;
	bool colorFlag = false;

	int scanDepth = -1;

	bool demangleELF = true;

	bool recache = false;

	bool useNGrams = false;

	PathFormat pathFormat = PathFormat.relative;

	DirSorting subsSorting = DirSorting.onTimeLastModified;
	BuildType buildType = BuildType.none;
	DuplicatesContext duplicatesContext = DuplicatesContext.internal;

	Dir[] topDirs;
	Dir rootDir;
}

struct Results
{
	size_t numTotalHits; // Number of total hits.
	size_t numFilesWithHits; // Number of files with hits
	Bytes64 noBytesTotal; // Number of bytes total.
	Bytes64 noBytesTotalContents; // Number of contents bytes total.
	Bytes64 noBytesScanned; // Number of bytes scanned.
	Bytes64 noBytesSkipped; // Number of bytes skipped.
	Bytes64 noBytesUnreadable; // Number of bytes unreadable.
}

version (cerealed)
{
	void grain(T)(ref Cereal cereal, ref SysTime systime)
	{
		auto stdTime = systime.stdTime;
		cereal.grain(stdTime);
		if (stdTime != 0)
		{
			systime = SysTime(stdTime);
		}
	}
}

/** Directory Sorting Order. */
enum DirSorting
{
	/* onTimeCreated, /\* Windows only. Currently stored in Linux on ext4 but no */
	/*			   * standard interface exists yet, it will probably be called */
	/*			   * xstat(). *\/ */
	onTimeLastModified,
	onTimeLastAccessed,
	onSize,
	onNothing,
}

enum BuildType
{
	none,	// Don't compile
	devel,   // Compile with debug symbols
	release, // Compile without debugs symbols and optimizations
	standard = devel,
}

enum PathFormat
{
	absolute,
	relative,
}

/** Dir.
 */
class Dir : File
{
	/** Construct File System Root Directory. */
	this(Dir parent = null, GStats gstats = null)
	{
		super(parent);
		this._gstats = gstats;
		if (gstats) { ++gstats.noDirs; }
	}

	this(string rootPath, GStats gstats)
		in { assert(rootPath == "/"); assert(gstats); }
	do
	{
		auto rootDent = DirEntry(rootPath);
		Dir rootParent = null;
		this(rootDent, rootParent, gstats);
	}

	this(ref DirEntry dent, Dir parent, GStats gstats)
		in { assert(gstats); }
	do
	{
		this(dent.name.baseName, parent, dent.size.Bytes64, dent.timeLastModified, dent.timeLastAccessed, gstats);
	}

	this(string name, Dir parent, Bytes64 size, SysTime timeLastModified, SysTime timeLastAccessed,
		 GStats gstats = null)
	{
		super(name, parent, size, timeLastModified, timeLastAccessed);
		this._gstats = gstats;
		if (gstats) { ++gstats.noDirs; }
	}

	override string toTextual() const @property { return "Directory"; }

	override Bytes64 treeSize() @property @trusted /* @safe nothrow */
	{
		if (_treeSize.isUntouched)
		{
			_treeSize = (this.size +
						 reduce!"a+b"(0.Bytes64,
									  subs.byValue.map!"a.treeSize")); // recurse!
		}
		return _treeSize.get.bytes;
	}

	/** Returns: Directory Tree Content Id of `this`. */
	override const(SHA1Digest) treeContentId() @property @trusted /* @safe nothrow */
	{
		if (_treeContentId.isUntouched)
		{
			_treeContentId = subs.byValue.map!"a.treeContentId".sha1Of; /+ TODO: join loops for calculating treeSize +/
			assert(_treeContentId, "Zero tree content digest");
			if (treeSize() != 0)
			{
				gstats.filesByContentId[_treeContentId] ~= assumeNotNull(cast(File)this); /+ TODO: Avoid cast when DMD and NotNull is fixed +/
			}
		}
		return _treeContentId;
	}

	override Face!Color face() const @property @safe pure nothrow { return dirFace; }

	/** Return true if `this` is a file system root directory. */
	bool isRoot() @property @safe const pure nothrow { return !parent; }

	GStats gstats(GStats gstats) @property @safe pure /* nothrow */ {
		return this._gstats = gstats;
	}
	GStats gstats() @property @safe nothrow
	{
		if (!_gstats && this.parent)
		{
			_gstats = this.parent.gstats();
		}
		return _gstats;
	}

	/** Returns: Depth of Depth from File System root to this File. */
	override int depth() @property @safe nothrow
	{
		if (_depth ==- 1)
		{
			_depth = parent ? parent.depth + 1 : 0; // memoized depth
		}
		return _depth;
	}

	/** Scan `this` recursively for a non-diretory file with basename `name`.
		TODO: Reuse range based algorithm this.tree(depthFirst|breadFirst)
	 */
	File find(string name) @property
	{
		auto subs_ = subs();
		if (name in subs_)
		{
			auto hit = subs_[name];
			Dir hitDir = cast(Dir)hit;
			if (!hitDir) // if not a directory
				return hit;
		}
		else
		{
			foreach (sub; subs_)
			{
				Dir subDir = cast(Dir)sub;
				if (subDir)
				{
					auto hit = subDir.find(name);
					if (hit) // if not a directory
						return hit;
				}
			}
		}
		return null;
	}

	/** Append Tree Statistics. */
	void addTreeStatsFromSub(F)(NotNull!F subFile, ref DirEntry subDent)
	{
		if (subDent.isFile)
		{
			/* _treeSize += subDent.size.Bytes64; */
			// dbg("Updating ", _treeSize, " of ", path);

			/++ TODO: Move these overloads to std.datetime +/
			auto ref min(in SysTime a, in SysTime b) @trusted pure nothrow { return (a < b ? a : b); }
			auto ref max(in SysTime a, in SysTime b) @trusted pure nothrow { return (a > b ? a : b); }

			const lastMod = subDent.timeLastModified;
			_timeModifiedInterval = Interval!SysTime(min(lastMod, _timeModifiedInterval.begin),
													 max(lastMod, _timeModifiedInterval.end));
			const lastAcc = subDent.timeLastAccessed;
			_timeAccessedInterval = Interval!SysTime(min(lastAcc, _timeAccessedInterval.begin),
													 max(lastAcc, _timeAccessedInterval.end));
		}
	}

	/** Update Statistics for Sub-File `sub` with `subDent` of `this` Dir. */
	void updateStats(F)(NotNull!F subFile, ref DirEntry subDent, bool isRegFile)
	{
		auto lGS = gstats();
		if (lGS)
		{
			if (lGS.showNameDups/*  && */
				/* !subFile.underAnyDir!(a => a.name in lGS.skippedDirKindsMap) */)
			{
				lGS.filesByName[subFile.name] ~= cast(NotNull!File)subFile;
			}
			if (lGS.showLinkDups &&
				isRegFile)
			{
				import core.sys.posix.sys.stat;
				immutable stat_t stat = subDent.statBuf();
				if (stat.st_nlink >= 2)
				{
					lGS.filesByInode[stat.st_ino] ~= cast(NotNull!File)subFile;
				}
			}
		}
	}

	/** Load Contents of `this` Directory from Disk using DirEntries.
		Returns: `true` iff Dir was updated (reread) from disk.
	*/
	bool load(int depth = 0, bool force = false)
	{
		import std.range: empty;
		if (!_obseleteDir && // already loaded
			!force)		  // and not forced reload
		{
			return false;	// signal already scanned
		}

		// dbg("Zeroing ", _treeSize, " of ", path);
		_treeSize.reset; // this.size;
		auto oldSubs = _subs;
		_subs.reset;
		assert(_subs.length == 0); /+ TODO: Remove when verified +/

		import std.file: dirEntries, SpanMode;
		auto entries = dirEntries(path, SpanMode.shallow, false); // false: skip symlinks
		foreach (dent; entries)
		{
			immutable basename = dent.name.baseName;
			File sub = null;
			if (basename in oldSubs)
			{
				sub = oldSubs[basename]; // reuse from previous cache
			}
			else
			{
				bool isRegFile = false;
				if (dent.isSymlink)
				{
					sub = new Symlink(dent, assumeNotNull(this));
				}
				else if (dent.isDir)
				{
					sub = new Dir(dent, this, gstats);
				}
				else if (dent.isFile)
				{
					/+ TODO: Delay construction of and specific files such as +/
					// CFile, ELFFile, after FKind-recognition has been made.
					sub = new RegFile(dent, assumeNotNull(this));
					isRegFile = true;
				}
				else
				{
					sub = new SpecFile(dent, assumeNotNull(this));
				}
				updateStats(enforceNotNull(sub), dent, isRegFile);
			}
			auto nnsub = enforceNotNull(sub);
			addTreeStatsFromSub(nnsub, dent);
			_subs[basename] = nnsub;
		}
		_subs.rehash;		   // optimize hash for faster lookups

		_obseleteDir = false;
		return true;
	}

	bool reload(int depth = 0) { return load(depth, true); }
	alias sync = reload;

	/* TODO: Can we get make this const to the outside world perhaps using inout? */
	ref NotNull!File[string] subs() @property { load(); return _subs; }

	NotNull!File[] subsSorted(DirSorting sorted = DirSorting.onTimeLastModified) @property
	{
		load();
		auto ssubs = _subs.values;
		/* TODO: Use radix sort to speed things up. */
		final switch (sorted)
		{
			/* case DirSorting.onTimeCreated: */
			/*	 break; */
		case DirSorting.onTimeLastModified:
			ssubs.sort!((a, b) => (a.timeLastModified >
								   b.timeLastModified));
			break;
		case DirSorting.onTimeLastAccessed:
			ssubs.sort!((a, b) => (a.timeLastAccessed >
								   b.timeLastAccessed));
			break;
		case DirSorting.onSize:
			ssubs.sort!((a, b) => (a.size >
								   b.size));
			break;
		case DirSorting.onNothing:
			break;
		}
		return ssubs;
	}

	File sub(Name)(Name sub_name)
	{
		load();
		return (sub_name in _subs) ? _subs[sub_name] : null;
	}
	File sub(File sub)
	{
		load();
		return (sub.path in _subs) != null ? sub : null;
	}

	version (cerealed)
	{
		void accept(Cereal cereal)
		{
			auto stdTime = timeLastModified.stdTime;
			cereal.grain(name, size, stdTime);
			timeLastModified = SysTime(stdTime);
		}
	}
	version (msgpack)
	{
		/** Construct from msgpack `unpacker`.  */
		this(Unpacker)(ref Unpacker unpacker)
		{
			fromMsgpack(msgpack.Unpacker(unpacker));
		}

		void toMsgpack(Packer)(ref Packer packer) const
		{
			/* writeln("Entering Dir.toMsgpack ", this.name); */
			packer.pack(name, size,
						timeLastModified.stdTime,
						timeLastAccessed.stdTime,
						kind);

			// Contents
			/* TODO: serialize map of polymorphic objects using
			 * packer.packArray(_subs) and type trait lookup up all child-classes of
			 * File */
			packer.pack(_subs.length);

			if (_subs.length >= 1)
			{
				auto diffsLastModified = _subs.byValue.map!"a.timeLastModified.stdTime".encodeForwardDifference;
				auto diffsLastAccessed = _subs.byValue.map!"a.timeLastAccessed.stdTime".encodeForwardDifference;
				/* auto timesLastModified = _subs.byValue.map!"a.timeLastModified.stdTime"; */
				/* auto timesLastAccessed = _subs.byValue.map!"a.timeLastAccessed.stdTime"; */

				packer.pack(diffsLastModified, diffsLastAccessed);

				/* debug dbg(this.name, " sub.length: ", _subs.length); */
				/* debug dbg(name, " modified diffs: ", diffsLastModified.pack.length); */
				/* debug dbg(name, " accessed diffs: ", diffsLastAccessed.pack.length); */
				/* debug dbg(name, " modified: ", timesLastModified.array.pack.length); */
				/* debug dbg(name, " accessed: ", timesLastAccessed.array.pack.length); */
			}

			foreach (sub; _subs)
			{
				if		(const regFile = cast(RegFile)sub)
				{
					packer.pack("RegFile");
					regFile.toMsgpack(packer);
				}
				else if (const dir = cast(Dir)sub)
				{
					packer.pack("Dir");
					dir.toMsgpack(packer);
				}
				else if (const symlink = cast(Symlink)sub)
				{
					packer.pack("Symlink");
					symlink.toMsgpack(packer);
				}
				else if (const special = cast(SpecFile)sub)
				{
					packer.pack("SpecFile");
					special.toMsgpack(packer);
				}
				else
				{
					immutable subClassName = sub.classinfo.name;
					assert(0, "Unknown sub File class " ~ subClassName); /+ TODO: Exception +/
				}
			}
		}

		void fromMsgpack(Unpacker)(auto ref Unpacker unpacker)
		{
			unpacker.unpack(name, size);

			long stdTime;
			unpacker.unpack(stdTime); timeLastModified = SysTime(stdTime); /+ TODO: Functionize +/
			unpacker.unpack(stdTime); timeLastAccessed = SysTime(stdTime); /+ TODO: Functionize +/

			/* dbg("before:", path, " ", size, " ", timeLastModified, " ", timeLastAccessed); */

			// FKind
			if (!kind) { kind = null; }
			unpacker.unpack(kind); /* TODO: kind = new DirKind(unpacker); */
			/* dbg("after:", path); */

			_treeSize.reset; // this.size;

			// Contents
			/* TODO: unpacker.unpack(_subs); */
			immutable noPreviousSubs = _subs.length == 0;
			size_t subs_length; unpacker.unpack(subs_length); /+ TODO: Functionize to unpacker.unpack!size_t() +/

			ForwardDifferenceCode!(long[]) diffsLastModified,
				diffsLastAccessed;
			if (subs_length >= 1)
			{
				unpacker.unpack(diffsLastModified, diffsLastAccessed);
				/* auto x = diffsLastModified.decodeForwardDifference; */
			}

			foreach (ix; 0..subs_length) // repeat for subs_length times
			{
				string subClassName; unpacker.unpack(subClassName); /+ TODO: Functionize +/
				File sub = null;
				try
				{
					switch (subClassName)
					{
					default:
						assert(0, "Unknown File parent class " ~ subClassName); /+ TODO: Exception +/
					case "Dir":
						auto subDir = new Dir(this, gstats);
						unpacker.unpack(subDir); sub = subDir;
						auto subDent = DirEntry(sub.path);
						subDir.checkObseleted(subDent); // Invalidate Statistics using fresh CStat if needed
						addTreeStatsFromSub(assumeNotNull(subDir), subDent);
						break;
					case "RegFile":
						auto subRegFile = new RegFile(assumeNotNull(this));
						unpacker.unpack(subRegFile); sub = subRegFile;
						auto subDent = DirEntry(sub.path);
						subRegFile.checkObseleted(subDent); // Invalidate Statistics using fresh CStat if needed
						updateStats(assumeNotNull(subRegFile), subDent, true);
						addTreeStatsFromSub(assumeNotNull(subRegFile), subDent);
						break;
					case "Symlink":
						auto subSymlink = new Symlink(assumeNotNull(this));
						unpacker.unpack(subSymlink); sub = subSymlink;
						break;
					case "SpecFile":
						auto SpecFile = new SpecFile(assumeNotNull(this));
						unpacker.unpack(SpecFile); sub = SpecFile;
						break;
					}
					if (noPreviousSubs ||
						!(sub.name in _subs))
					{
						_subs[sub.name] = enforceNotNull(sub);
					}
					/* dbg("Unpacked Dir sub ", sub.path, " of type ", subClassName); */
				} catch (FileException) { // this may be a too generic exception
					/* dbg(sub.path, " is not accessible anymore"); */
				}
			}

		}
	}

	override void makeObselete() @trusted
	{
		_obseleteDir = true;
		_treeSize.reset;
		_timeModifiedInterval.reset;
		_timeAccessedInterval.reset;
	}
	override void makeUnObselete() @safe
	{
		_obseleteDir = false;
	}

	private NotNull!File[string] _subs; // Directory contents
	DirKind kind;			   // Kind of this directory
	uint64_t hitCount = 0;
	private int _depth = -1;			// Memoized Depth
	private bool _obseleteDir = true;  // Flags that this is obselete
	GStats _gstats = null;

	/* TODO: Reuse Span and span in Phobos. (Span!T).init should be (T.max, T.min) */
	Interval!SysTime _timeModifiedInterval;
	Interval!SysTime _timeAccessedInterval;

	Nullable!(size_t, size_t.max) _treeSize; // Size of tree with this directory as root.
	/* TODO: Make this work instead: */
	/* import std.typecons: Nullable; */
	/* Nullable!(Bytes64, Bytes64.max) _treeSize; // Size of tree with this directory as root. */

	SHA1Digest _treeContentId;
}

/** Externally Directory Memoized Calculation of Tree Size.
	Is it possible to make get any of @safe pure nothrow?
 */
Bytes64 treeSizeMemoized(NotNull!File file, Bytes64[File] cache) @trusted /* nothrow */
{
	typeof(return) sum = file.size;
	if (auto dir = cast(Dir)file)
	{
		if (file in cache)
		{
			sum = cache[file];
		}
		else
		{
			foreach (sub; dir.subs.byValue)
			{
				sum += treeSizeMemoized(sub, cache);
			}
			cache[file] = sum;
		}
	}
	return sum;
}

/** Save File System Tree Cache under Directory `rootDir`.
	Returns: Serialized Byte Array.
*/
const(ubyte[]) saveRootDirTree(Viz viz,
							   Dir rootDir, string cacheFile) @trusted
{
	immutable tic = Clock.currTime;
	version (msgpack)
	{
		const data = rootDir.pack();
		import std.file: write;
	}
	else version (cerealed)
		 {
			 auto enc = new Cerealiser(); // encoder
			 enc ~= rootDir;
			 auto data = enc.bytes;
		 }
	else
	{
		ubyte[] data;
	}
	cacheFile.write(data);
	immutable toc = Clock.currTime;

	viz.ppln("Cache Write".asH!2,
			 "Wrote tree cache of size ",
			 data.length.Bytes64, " to ",
			 cacheFile.asPath,
			 " in ",
			 shortDurationString(toc - tic));

	return data;
}

/** Load File System Tree Cache from `cacheFile`.
	Returns: Root Directory of Loaded Tree.
*/
Dir loadRootDirTree(Viz viz,
					string cacheFile, GStats gstats) @trusted
{
	immutable tic = Clock.currTime;

	import std.file: read;
	try
	{
		const data = read(cacheFile);

		auto rootDir = new Dir(cast(Dir)null, gstats);
		version (msgpack)
		{
			unpack(cast(ubyte[])data, rootDir); /* Dir rootDir = new Dir(cast(const(ubyte)[])data); */
		}
		immutable toc = Clock.currTime;

		viz.pp("Cache Read".asH!2,
			   "Read cache of size ",
			   data.length.Bytes64, " from ",
			   cacheFile.asPath,
			   " in ",
			   shortDurationString(toc - tic), " containing",
			   asUList(asItem(gstats.noDirs, " Dirs,"),
					   asItem(gstats.noRegFiles, " Regular Files,"),
					   asItem(gstats.noSymlinks, " Symbolic Links,"),
					   asItem(gstats.noSpecialFiles, " Special Files,"),
					   asItem("totalling ", gstats.noFiles + 1, " Files")));
		assert(gstats.noDirs +
			   gstats.noRegFiles +
			   gstats.noSymlinks +
			   gstats.noSpecialFiles == gstats.noFiles + 1);
		return rootDir;
	}
	catch (FileException)
	{
		viz.ppln("Failed to read cache from ", cacheFile);
		return null;
	}
}

Dir[] getDirs(NotNull!Dir rootDir, string[] topDirNames)
{
	Dir[] topDirs;
	foreach (topName; topDirNames)
	{
		Dir topDir = getDir(rootDir, topName);

		if (!topDir)
		{
			dbg("Directory " ~ topName ~ " is missing");
		}
		else
		{
			topDirs ~= topDir;
		}
	}
	return topDirs;
}

/** (Cached) Lookup of File `filePath`.
 */
File getFile(NotNull!Dir rootDir, string filePath,
			 bool isDir = false,
			 bool tolerant = false) @trusted
{
	if (isDir)
	{
		return getDir(rootDir, filePath);
	}
	else
	{
		auto parentDir = getDir(rootDir, filePath.dirName);
		if (parentDir)
		{
			auto hit = parentDir.sub(filePath.baseName);
			if (hit)
				return hit;
			else
			{
				dbg("File path " ~ filePath ~ " doesn't exist. TODO: Query user to instead find it under "
					~ parentDir.path);
				parentDir.find(filePath.baseName);
			}
		}
		else
		{
			dbg("Directory " ~ parentDir.path ~ " doesn't exist");
		}
	}
	return null;
}

/** (Cached) Lookup of Directory `dirpath`.
	Returns: Dir if present under rootDir, null otherwise.
	TODO: Make use of dent
*/
import std.path: isRooted;
Dir getDir(NotNull!Dir rootDir, string dirPath, ref DirEntry dent,
		   ref Symlink[] followedSymlinks) @trusted
	in { assert(dirPath.isRooted); }
do
{
	Dir currDir = rootDir;

	import std.range: drop;
	import std.path: pathSplitter;
	foreach (part; dirPath.pathSplitter().drop(1)) // all but first
	{
		auto sub = currDir.sub(part);
		if		(auto subDir = cast(Dir)sub)
		{
			currDir = subDir;
		}
		else if (auto subSymlink = cast(Symlink)sub)
		{
			auto subDent = DirEntry(subSymlink.absoluteNormalizedTargetPath);
			if (subDent.isDir)
			{
				if (followedSymlinks.find(subSymlink))
				{
					dbg("Infinite recursion in ", subSymlink);
					return null;
				}
				followedSymlinks ~= subSymlink;
				currDir = getDir(rootDir, subSymlink.absoluteNormalizedTargetPath, subDent, followedSymlinks); /+ TODO: Check for infinite recursion +/
			}
			else
			{
				dbg("Loaded path " ~ dirPath ~ " is not a directory");
				return null;
			}
		}
		else
		{
			return null;
		}
	}
	return currDir;
}

/** (Cached) Lookup of Directory `dirPath`. */
Dir getDir(NotNull!Dir rootDir, string dirPath) @trusted
{
	Symlink[] followedSymlinks;
	try
	{
		auto dirDent = DirEntry(dirPath);
		return getDir(rootDir, dirPath, dirDent, followedSymlinks);
	}
	catch (FileException)
	{
		dbg("Exception getting Dir");
		return null;
	}
}
unittest {
	/* auto tmp = tempfile("/tmp/fsfile"); */
}

enum ulong mmfile_size = 0; // 100*1024

auto pageSize() @trusted
{
	version (linux)
	{
		import core.sys.posix.sys.shm: __getpagesize;
		return __getpagesize();
	}
	else
	{
		return 4096;
	}
}

enum KeyStrictness
{
	exact,
	acronym,
	eitherExactOrAcronym,
	standard = eitherExactOrAcronym,
}

/** Language Operator Associativity. */
enum OpAssoc { none,
			   LR, // Left-to-Right
			   RL, // Right-to-Left
}

/** Language Operator Arity. */
enum OpArity
{
	unknown,
	unaryPostfix, // 1-arguments
	unaryPrefix, // 1-arguments
	binary, // 2-arguments
	ternary, // 3-arguments
}

/** Language Operator. */
struct Op
{
	this(string op,
		 OpArity arity = OpArity.unknown,
		 OpAssoc assoc = OpAssoc.none,
		 byte prec = -1,
		 string desc = [])
	{
		this.op = op;
		this.arity = arity;
		this.assoc = assoc;
		this.prec = prec;
		this.desc = desc;
	}
	/** Make `this` an alias of `opOrig`. */
	Op aliasOf(string opOrig)
	{
		/+ TODO: set relation in map from op to opOrig +/
		return this;
	}
	string op; // Operator. TODO: Optimize this storage using a value type?
	string desc; // Description
	OpAssoc assoc; // Associativity
	ubyte prec; // Precedence
	OpArity arity; // Arity
	bool overloadable; // Overloadable
}

/** Language Operator Alias. */
struct OpAlias
{
	this(string op, string opOrigin)
	{
		this.op = op;
		this.opOrigin = opOrigin;
	}
	string op;
	string opOrigin;
}

FKind tryLookupKindIn(RegFile regFile,
					  FKind[SHA1Digest] kindsById)
{
	immutable id = regFile._cstat.kindId;
	if (id in kindsById)
	{
		return kindsById[id];
	}
	else
	{
		return null;
	}
}

string displayedFilename(AnyFile)(GStats gstats,
								  AnyFile theFile) @safe pure
{
	return ((gstats.pathFormat == PathFormat.relative &&
			 gstats.topDirs.length == 1) ?
			"./" ~ theFile.name :
			theFile.path);
}

/** File System Scanner. */
class Scanner(Term)
{
	this(string[] args, ref Term term)
	{
		prepare(args, term);
	}

	SysTime _currTime;
	import std.getopt;
	import std.string: toLower, toUpper, startsWith, CaseSensitive;
	import std.mmfile;
	import std.stdio: writeln, stdout, stderr, stdin, popen;
	import std.algorithm: find, count, countUntil, min, splitter;
	import std.range: join;
	import std.conv: to;

	import core.sys.posix.sys.mman;
	import core.sys.posix.pwd: passwd, getpwuid_r;
	version (linux)
	{
		// import core.sys.linux.sys.inotify;
		import core.sys.linux.sys.xattr;
	}
	import core.sys.posix.unistd: getuid, getgid;
	import std.file: read, FileException, exists, getcwd;
	import std.range: retro;
	import std.exception: ErrnoException;
	import core.sys.posix.sys.stat: stat_t, S_IRUSR, S_IRGRP, S_IROTH;

	uint64_t _hitsCountTotal = 0;

	Symlink[] _brokenSymlinks;

	bool _beVerbose = false;
	bool _caseFold = false;
	bool _showSkipped = false;
	bool listTxtFKinds = false;
	bool listBinFKinds = false;
	string selFKindNames;
	string[] _topDirNames;
	string[] addTags;
	string[] removeTags;

	private
	{
		GStats gstats = new GStats();

		string _cacheFile = "~/.cache/fs-root.msgpack";

		uid_t _uid;
		gid_t _gid;
	}

	ioFile outFile;

	string[] keys; // Keys to scan.
	typeof(keys.map!bistogramOverRepresentation) keysBists;
	typeof(keys.map!(sparseUIntNGramOverRepresentation!NGramOrder)) keysXGrams;
	Bist keysBistsUnion;
	XGram keysXGramsUnion;

	string selFKindsNote;

	void prepare(string[] args, ref Term term)
	{
		_scanChunkSize = 32*pageSize;
		gstats.loadFileKinds;
		gstats.loadDirKinds;

		bool helpPrinted = getoptEx("FS --- File System Scanning Utility in D.\n" ~
									"Usage: fs { --switches } [KEY]...\n" ~
									"Note that scanning for multiple KEYs is possible.\nIf so hits are highlighted in different colors!\n" ~
									"Sample calls: \n" ~
									"  fdo.d --color -d /lib/modules/3.13.0-24-generic/kernel/drivers/staging --browse --duplicates --recache lirc\n" ~
									"  fdo.d --color -d /etc -s --tree --usage -l --duplicates stallman\n" ~
									"  fdo.d --color -d /etc -d /var --acronym sttccc\n" ~
									"  fdo.d --color -d /etc -d /var --acronym dktp\n" ~
									"  fdo.d --color -d /etc -d /var --acronym tms sttc prc dtp xsr\n" ~
									"  fdo.d --color -d /etc min max delta\n" ~
									"  fdo.d --color -d /etc if elif return len --duplicates --sort=onSize\n" ~
									"  fdo.d --color -k -d /bin alpha\n" ~
									"  fdo.d --color -d /lib -k linus" ~
									"  fdo.d --color -d /etc --symbol alpha beta gamma delta" ~
									"  fdo.d --color -d /var/spool/postfix/dev " ~
									"  fdo.d --color -d /etc alpha" ~
									"  fdo.d --color -d ~/Work/dmd  --browse xyz --duplicates --do=preprocess",

									args,
									std.getopt.config.caseInsensitive,

									"verbose|v", "\tVerbose",  &_beVerbose,

									"color|C", "\tColorize Output" ~ defaultDoc(gstats.colorFlag),  &gstats.colorFlag,
									"types|T", "\tComma separated list (CSV) of file types/kinds to scan" ~ defaultDoc(selFKindNames), &selFKindNames,
									"list-textual-kinds", "\tList registered textual types/kinds" ~ defaultDoc(listTxtFKinds), &listTxtFKinds,
									"list-binary-kinds", "\tList registered binary types/kinds" ~ defaultDoc(listBinFKinds), &listBinFKinds,
									"group-types|G", "\tCollect and group file types found" ~ defaultDoc(gstats.collectTypeHits), &gstats.collectTypeHits,

									"i", "\tCase-Fold, Case-Insensitive" ~ defaultDoc(_caseFold), &_caseFold,
									"k", "\tShow Skipped Directories and Files" ~ defaultDoc(_showSkipped), &_showSkipped,
									"d", "\tRoot Directory(s) of tree(s) to scan, defaulted to current directory" ~ defaultDoc(_topDirNames), &_topDirNames,
									"depth", "\tDepth of tree to scan, defaulted to unlimited (-1) depth" ~ defaultDoc(gstats.scanDepth), &gstats.scanDepth,

									// Contexts
									"context|x", "\tComma Separated List of Contexts. Among: " ~ enumDoc!ScanContext, &gstats.scanContext,

									"word|w", "\tSearch for key as a complete Word (A Letter followed by more Letters and Digits)." ~ defaultDoc(gstats.keyAsWord), &gstats.keyAsWord,
									"symbol|ident|id|s", "\tSearch for key as a complete Symbol (Identifier)" ~ defaultDoc(gstats.keyAsSymbol), &gstats.keyAsSymbol,
									"acronym|a", "\tSearch for key as an acronym (relaxed)" ~ defaultDoc(gstats.keyAsAcronym), &gstats.keyAsAcronym,
									"exact", "\tSearch for key only with exact match (strict)" ~ defaultDoc(gstats.keyAsExact), &gstats.keyAsExact,

									"name-duplicates|snd", "\tDetect & Show file name duplicates" ~ defaultDoc(gstats.showNameDups), &gstats.showNameDups,
									"hardlink-duplicates|inode-duplicates|shd", "\tDetect & Show multiple links to same inode" ~ defaultDoc(gstats.showLinkDups), &gstats.showLinkDups,
									"file-content-duplicates|scd", "\tDetect & Show file contents duplicates" ~ defaultDoc(gstats.showFileContentDups), &gstats.showFileContentDups,
									"tree-content-duplicates", "\tDetect & Show directory tree contents duplicates" ~ defaultDoc(gstats.showTreeContentDups), &gstats.showTreeContentDups,

									"elf-symbol-duplicates", "\tDetect & Show ELF Symbol Duplicates" ~ defaultDoc(gstats.showELFSymbolDups), &gstats.showELFSymbolDups,

									"duplicates|D", "\tDetect & Show file name and contents duplicates" ~ defaultDoc(gstats.showAnyDups), &gstats.showAnyDups,
									"duplicates-context", "\tDuplicates Detection Context. Among: " ~ enumDoc!DuplicatesContext, &gstats.duplicatesContext,
									"hardlink-content-duplicates", "\tConvert all content duplicates into hardlinks (common inode) if they reside on the same file system" ~ defaultDoc(gstats.linkContentDups), &gstats.linkContentDups,

									"usage", "\tShow disk usage (tree size) of scanned directories" ~ defaultDoc(gstats.showUsage), &gstats.showUsage,
									"count-lines", "\tShow line counts of scanned files" ~ defaultDoc(gstats.showLineCounts), &gstats.showLineCounts,

									"sha1", "\tShow SHA1 content digests" ~ defaultDoc(gstats.showSHA1), &gstats.showSHA1,

									"mmaps", "\tShow when files are memory mapped (mmaped)" ~ defaultDoc(gstats.showMMaps), &gstats.showMMaps,

									"follow-symlinks|f", "\tFollow symbolic links" ~ defaultDoc(gstats.followSymlinks), &gstats.followSymlinks,
									"broken-symlinks|l", "\tDetect & Show broken symbolic links (target is non-existing file) " ~ defaultDoc(gstats.showBrokenSymlinks), &gstats.showBrokenSymlinks,
									"show-symlink-cycles|l", "\tDetect & Show symbolic links cycles" ~ defaultDoc(gstats.showSymlinkCycles), &gstats.showSymlinkCycles,

									"add-tag", "\tAdd tag string(s) to matching files" ~ defaultDoc(addTags), &addTags,
									"remove-tag", "\tAdd tag string(s) to matching files" ~ defaultDoc(removeTags), &removeTags,

									"tree|W", "\tShow Scanned Tree and Followed Symbolic Links" ~ defaultDoc(gstats.showTree), &gstats.showTree,
									"sort|S", "\tDirectory contents sorting order. Among: " ~ enumDoc!DirSorting, &gstats.subsSorting,
									"build", "\tBuild Source Code. Among: " ~ enumDoc!BuildType, &gstats.buildType,

									"path-format", "\tFormat of paths. Among: " ~ enumDoc!PathFormat ~ "." ~ defaultDoc(gstats.pathFormat), &gstats.pathFormat,

									"cache-file|F", "\tFile System Tree Cache File" ~ defaultDoc(_cacheFile), &_cacheFile,
									"recache", "\tSkip initial load of cache from disk" ~ defaultDoc(gstats.recache), &gstats.recache,

									"do", "\tOperation to perform on matching files. Among: " ~ enumDoc!FOp, &gstats.fOp,

									"demangle-elf", "\tDemangle ELF files.", &gstats.demangleELF,

									"use-ngrams", "\tUse NGrams to cache statistics and thereby speed up search" ~ defaultDoc(gstats.useNGrams), &gstats.useNGrams,

									"html|H", "\tFormat output as HTML" ~ defaultDoc(gstats.useHTML), &gstats.useHTML,
									"browse|B", ("\tFormat output as HTML to a temporary file" ~
												 defaultDoc(_cacheFile) ~
												 " and open it with default Web browser" ~
												 defaultDoc(gstats.browseOutput)), &gstats.browseOutput,

									"author", "\tPrint name of\n"~"\tthe author",
									delegate() { writeln("Per Nordlöw"); }
			);

		if (gstats.showAnyDups)
		{
			gstats.showNameDups = true;
			gstats.showLinkDups = true;
			gstats.showFileContentDups = true;
			gstats.showTreeContentDups = true;
			gstats.showELFSymbolDups = true;
		}
		if (helpPrinted)
			return;

		_cacheFile = std.path.expandTilde(_cacheFile);

		if (_topDirNames.empty)
		{
			_topDirNames = ["."];
		}
		if (_topDirNames == ["."])
		{
			gstats.pathFormat = PathFormat.relative;
		}
		else
		{
			gstats.pathFormat = PathFormat.absolute;
		}
		foreach (ref topName; _topDirNames)
		{
			if (topName ==  ".")
			{
				topName = topName.absolutePath.buildNormalizedPath;
			}
			else
			{
				topName = topName.expandTilde.buildNormalizedPath;
			}
		}

		// Output Handling
		if (gstats.browseOutput)
		{
			gstats.useHTML = true;
			immutable ext = gstats.useHTML ? "html" : "results.txt";
			import std.uuid: randomUUID;
			outFile = ioFile("/tmp/fs-" ~ randomUUID.toString() ~
							 "." ~ ext,
							 "w");
			/* popen("gnome-open " ~ outFile.name); */
			popen("firefox -new-tab " ~ outFile.name);
		}
		else
		{
			outFile = stdout;
		}

		auto cwd = getcwd();

		foreach (arg; args[1..$])
		{
			if (!arg.startsWith("-")) // if argument not a flag
			{
				keys ~= arg;
			}
		}

		// Calc stats
		keysBists = keys.map!bistogramOverRepresentation;
		keysXGrams = keys.map!(sparseUIntNGramOverRepresentation!NGramOrder);
		keysBistsUnion = reduce!"a | b"(typeof(keysBists.front).init, keysBists);
		keysXGramsUnion = reduce!"a + b"(typeof(keysXGrams.front).init, keysXGrams);

		auto viz = new Viz(outFile,
						   &term,
						   gstats.showTree,
						   gstats.useHTML ? VizForm.HTML : VizForm.textAsciiDocUTF8,
						   gstats.colorFlag,
						   !gstats.useHTML, // only use if HTML
						   true, /+ TODO: Only set if in debug mode +/
			);

		if (gstats.useNGrams &&
			(!keys.empty) &&
			keysXGramsUnion.empty)
		{
			gstats.useNGrams = false;
			viz.ppln("Keys must be at least of length " ~
					 to!string(NGramOrder + 1) ~
					 " in order for " ~
					 keysXGrams[0].typeName ~
					 " to be calculated");
		}

		// viz.ppln("<meta http-equiv=\"refresh\" content=\"1\"/>"); // refresh every second

		if (selFKindNames)
		{
			foreach (lang; selFKindNames.splitterASCIIAmong!(","))
			{
				if	  (lang		 in gstats.allFKinds.byName) // try exact match
				{
					gstats.selFKinds ~= gstats.allFKinds.byName[lang];
				}
				else if (lang.toLower in gstats.allFKinds.byName) // else try all in lower case
				{
					gstats.selFKinds ~= gstats.allFKinds.byName[lang.toLower];
				}
				else if (lang.toUpper in gstats.allFKinds.byName) // else try all in upper case
				{
					gstats.selFKinds ~= gstats.allFKinds.byName[lang.toUpper];
				}
				else
				{
					writeln("warning: Language ", lang, " not registered");
				}
			}
			if (gstats.selFKinds.byIndex.empty)
			{
				writeln("warning: None of the languages ", to!string(selFKindNames), " are registered. Defaulting to all file types.");
				gstats.selFKinds = gstats.allFKinds; // just reuse allFKinds
			}
			else
			{
				gstats.selFKinds.rehash;
			}
		}
		else
		{
			gstats.selFKinds = gstats.allFKinds; // just reuse allFKinds
		}

		// Keys
		auto commaedKeys = keys.joiner(",");
		const keysPluralExt = keys.length >= 2 ? "s" : "";
		string commaedKeysString = to!string(commaedKeys);
		if (keys)
		{
			selFKindsNote = " in " ~ (gstats.selFKinds == gstats.allFKinds ?
									  "all " :
									  gstats.selFKinds.byIndex.map!(a => a.kindName).join(",") ~ "-") ~ "files";
			immutable underNote = " under \"" ~ (_topDirNames.reduce!"a ~ ',' ~ b") ~ "\"";
			const exactNote = gstats.keyAsExact ? "exact " : "";
			string asNote;
			if (gstats.keyAsAcronym)
			{
				asNote = (" as " ~ exactNote ~
						  (gstats.keyAsWord ? "word" : "symbol") ~
						  " acronym" ~ keysPluralExt);
			}
			else if (gstats.keyAsSymbol)
			{
				asNote = " as " ~ exactNote ~ "symbol" ~ keysPluralExt;
			}
			else if (gstats.keyAsWord)
			{
				asNote = " as " ~ exactNote ~ "word" ~ keysPluralExt;
			}
			else
			{
				asNote = "";
			}

			const title = ("Searching for \"" ~ commaedKeysString ~ "\"" ~
						   " case-" ~ (_caseFold ? "in" : "") ~"sensitively"
						   ~asNote ~selFKindsNote ~underNote);
			if (viz.form == VizForm.HTML) // only needed for HTML output
			{
				viz.ppln(faze(title, titleFace));
			}

			viz.pp(asH!1("Searching for \"", commaedKeysString, "\"",
						 " case-", (_caseFold ? "in" : ""), "sensitively",
						 asNote, selFKindsNote,
						 " under ", _topDirNames.map!(a => a.asPath)));
		}

		if (listTxtFKinds)
		{
			viz.pp("Textual (Source) Kinds".asH!2,
				   gstats.txtFKinds.byIndex.asTable);
		}

		if (listBinFKinds)
		{
			viz.pp("Binary Kinds".asH!2,
				   gstats.binFKinds.byIndex.asTable);
		}

		/* binFKinds.asTable, */

		if (_showSkipped)
		{
			viz.pp("Skipping files of type".asH!2,
				   asUList(gstats.binFKinds.byIndex.map!(a => asItem(a.kindName.asBold,
																	 ": ",
																	 asCSL(a.exts.map!(b => b.asCode))))));
			viz.pp("Skipping directories of type".asH!2,
				   asUList(gstats.skippedDirKinds.map!(a => asItem(a.kindName.asBold,
																   ": ",
																   a.fileName.asCode))));
		}

		// if (key && key == key.toLower()) { // if search key is all lowercase
		//	 _caseFold = true;			   // we do case-insensitive search like in Emacs
		// }

		_uid = getuid;
		_gid = getgid;

		// Setup root directory
		if (!gstats.recache)
		{
			GC.disable;
			gstats.rootDir = loadRootDirTree(viz, _cacheFile, gstats);
			GC.enable;
		}
		if (!gstats.rootDir) // if first time
		{
			gstats.rootDir = new Dir("/", gstats); // filesystem root directory. TODO: Make this uncopyable?
		}

		// Scan for exact key match
		gstats.topDirs = getDirs(enforceNotNull(gstats.rootDir), _topDirNames);

		_currTime = Clock.currTime;

		GC.disable;
		scanTopDirs(viz, commaedKeysString);
		GC.enable;

		GC.disable;
		saveRootDirTree(viz, gstats.rootDir, _cacheFile);
		GC.enable;

		// Print statistics
		showStats(viz);
	}

	void scanTopDirs(Viz viz,
					 string commaedKeysString)
	{
		viz.pp("Results".asH!2);
		if (gstats.topDirs)
		{
			foreach (topIndex, topDir; gstats.topDirs)
			{
				scanDir(viz, assumeNotNull(topDir), assumeNotNull(topDir), keys);
				if (ctrlC)
				{
					auto restDirs = gstats.topDirs[topIndex + 1..$];
					if (!restDirs.empty)
					{
						debug dbg("Ctrl-C pressed: Skipping search of " ~ to!string(restDirs));
						break;
					}
				}
			}

			viz.pp("Summary".asH!2);

			if ((gstats.noScannedFiles - gstats.noScannedDirs) == 0)
			{
				viz.ppln("No files with any content found");
			}
			else
			{
				// Scan for acronym key match
				if (keys && _hitsCountTotal == 0)  // if keys given but no hit found
				{
					auto keysString = (keys.length >= 2 ? "s" : "") ~ " \"" ~ commaedKeysString;
					if (gstats.keyAsAcronym)
					{
						viz.ppln(("No acronym matches for key" ~ keysString ~ `"` ~
								  (gstats.keyAsSymbol ? " as symbol" : "") ~
								  " found in files of type"));
					}
					else if (!gstats.keyAsExact)
					{
						viz.ppln(("No exact matches for key" ~ keysString ~ `"` ~
								  (gstats.keyAsSymbol ? " as symbol" : "") ~
								  " found" ~ selFKindsNote ~
								  ". Relaxing scan to" ~ (gstats.keyAsSymbol ? " symbol" : "") ~ " acronym match."));
						gstats.keyAsAcronym = true;

						foreach (topDir; gstats.topDirs)
						{
							scanDir(viz, assumeNotNull(topDir), assumeNotNull(topDir), keys);
						}
					}
				}
			}
		}

		assert(gstats.noScannedDirs +
			   gstats.noScannedRegFiles +
			   gstats.noScannedSymlinks +
			   gstats.noScannedSpecialFiles == gstats.noScannedFiles);
	}

	version (linux)
	{
		@trusted bool readable(in stat_t stat, uid_t uid, gid_t gid, ref string msg)
		{
			immutable mode = stat.st_mode;
			immutable ok = ((stat.st_uid == uid) && (mode & S_IRUSR) ||
							(stat.st_gid == gid) && (mode & S_IRGRP) ||
							(mode & S_IROTH));
			if (!ok)
			{
				msg = " is not readable by you, but only by";
				bool can = false; // someone can access
				if (mode & S_IRUSR)
				{
					can = true;
					msg ~= " user id " ~ to!string(stat.st_uid);

					// Lookup user name from user id
					passwd pw;
					passwd* pw_ret;
					immutable size_t bufsize = 16384;
					char* buf = cast(char*)core.stdc.stdlib.malloc(bufsize);
					getpwuid_r(stat.st_uid, &pw, buf, bufsize, &pw_ret);
					if (pw_ret != null)
					{
						string userName;
						{
							size_t n = 0;
							while (pw.pw_name[n] != 0)
							{
								userName ~= pw.pw_name[n];
								n++;
							}
						}
						msg ~= " (" ~ userName ~ ")";

						// string realName;
						// {
						//	 size_t n = 0;
						//	 while (pw.pw_gecos[n] != 0)
						//	 {
						//		 realName ~= pw.pw_gecos[n];
						//		 n++;
						//	 }
						// }
					}
					core.stdc.stdlib.free(buf);

				}
				if (mode & S_IRGRP)
				{
					can = true;
					if (msg != "")
					{
						msg ~= " or";
					}
					msg ~= " group id " ~ to!string(stat.st_gid);
				}
				if (!can)
				{
					msg ~= " root";
				}
			}
			return ok;
		}
	}

	Results results;

	void handleError(F)(Viz viz,
						NotNull!F file, bool isDir, size_t subIndex)
	{
		auto dent = DirEntry(file.path);
		immutable stat_t stat = dent.statBuf;
		string msg;
		if (!readable(stat, _uid, _gid, msg))
		{
			results.noBytesUnreadable += dent.size;
			if (_showSkipped)
			{
				if (gstats.showTree)
				{
					auto parentDir = file.parent;
					immutable intro = subIndex == parentDir.subs.length - 1 ? "└" : "├";
					viz.pp("│  ".repeat(parentDir.depth + 1).join("") ~ intro ~ "─ ");
				}
				viz.ppln(file,
						 ":  ", isDir ? "Directory" : "File",
						 faze(msg, warnFace));
			}
		}
	}

	void printSkipped(Viz viz,
					  NotNull!RegFile regFile,
					  size_t subIndex,
					  const NotNull!FKind kind, KindHit kindhit,
					  const string skipCause)
	{
		auto parentDir = regFile.parent;
		if (_showSkipped)
		{
			if (gstats.showTree)
			{
				immutable intro = subIndex == parentDir.subs.length - 1 ? "└" : "├";
				viz.pp("│  ".repeat(parentDir.depth + 1).join("") ~ intro ~ "─ ");
			}
			viz.pp(horizontalRuler,
				   asH!3(regFile,
						 ": Skipped ", kind, " file",
						 skipCause));
		}
	}

	size_t _scanChunkSize;

	KindHit isSelectedFKind(NotNull!RegFile regFile) @safe /* nothrow */
	{
		typeof(return) kindHit = KindHit.none;
		FKind hitKind;

		// Try cached kind first
		// First Try with kindId as try
		if (regFile._cstat.kindId.defined) // kindId is already defined and uptodate
		{
			if (regFile._cstat.kindId in gstats.selFKinds.byId)
			{
				hitKind = gstats.selFKinds.byId[regFile._cstat.kindId];
				kindHit = KindHit.cached;
				return kindHit;
			}
		}

		immutable ext = regFile.realExtension;

		// Try with hash table first
		if (!ext.empty && // if file has extension and
			ext in gstats.selFKinds.byExt) // and extensions may match specified included files
		{
			auto possibleKinds = gstats.selFKinds.byExt[ext];
			foreach (kind; possibleKinds)
			{
				auto nnKind = enforceNotNull(kind);
				immutable hit = regFile.ofKind(nnKind, gstats.collectTypeHits, gstats.allFKinds);
				if (hit)
				{
					hitKind = nnKind;
					kindHit = hit;
					break;
				}
			}
		}

		if (!hitKind) // if no hit yet
		{
			// blindly try the rest
			foreach (kind; gstats.selFKinds.byIndex)
			{
				auto nnKind = enforceNotNull(kind);
				immutable hit = regFile.ofKind(nnKind, gstats.collectTypeHits, gstats.allFKinds);
				if (hit)
				{
					hitKind = nnKind;
					kindHit = hit;
					break;
				}
			}
		}

		return kindHit;
	}

	/** Search for Keys `keys` in Source `src`.
	 */
	size_t scanForKeys(Source, Keys)(Viz viz,
									 NotNull!Dir topDir,
									 NotNull!File theFile,
									 NotNull!Dir parentDir,
									 ref Symlink[] fromSymlinks,
									 in Source src,
									 in Keys keys,
									 in bool[] bistHits = [],
									 ScanContext ctx = ScanContext.standard)
	{
		bool anyFileHit = false; // will become true if any hit in this file

		typeof(return) hitCount = 0;

		import std.ascii: newline;

		auto thisFace = stdFace;
		if (gstats.colorFlag)
		{
			if (ScanContext.fileName)
			{
				thisFace = fileFace;
			}
		}

		size_t nL = 0; // line counter
		foreach (line; src.splitterASCIIAmong!(newline))
		{
			auto rest = cast(string)line; // rest of line as a string

			bool anyLineHit = false; // will become true if any hit on current line
			// Hit search loop
			while (!rest.empty)
			{
				// Find any key

				/* TODO: Convert these to a range. */
				ptrdiff_t offKB = -1;
				ptrdiff_t offKE = -1;

				foreach (uint ix, key; keys) /+ TODO: Call variadic-find instead to speed things up. +/
				{
					/* Bistogram Discardal */
					if ((!bistHits.empty) &&
						!bistHits[ix]) // if neither exact nor acronym match possible
					{
						continue; // try next key
					}

					/* dbg("key:", key, " line:", line); */
					ptrdiff_t[] acronymOffsets;
					if (gstats.keyAsAcronym) // acronym search
					{
						auto hit = (cast(immutable ubyte[])rest).findAcronymAt(key,
																			   gstats.keyAsSymbol ? FindContext.inSymbol : FindContext.inWord);
						if (!hit[0].empty)
						{
							acronymOffsets = hit[1];
							offKB = hit[1][0];
							offKE = hit[1][$-1] + 1;
						}
					}
					else
					{ // normal search
						import std.string: indexOf;
						offKB = rest.indexOf(key,
											 _caseFold ? CaseSensitive.no : CaseSensitive.yes); // hit begin offset
						offKE = offKB + key.length; // hit end offset
					}

					if (offKB >= 0) // if hit
					{
						if (!gstats.showTree && ctx == ScanContext.fileName)
						{
							viz.pp(parentDir, dirSeparator);
						}

						// Check Context
						if ((gstats.keyAsSymbol && !isSymbolASCII(rest, offKB, offKE)) ||
							(gstats.keyAsWord   && !isWordASCII  (rest, offKB, offKE)))
						{
							rest = rest[offKE..$]; // move forward in line
							continue;
						}

						if (ctx == ScanContext.fileContent &&
							!anyLineHit) // if this is first hit
						{
							if (viz.form == VizForm.HTML)
							{
								if (!anyFileHit)
								{
									viz.pp(horizontalRuler,
										   displayedFilename(gstats, theFile).asPath.asH!3);
									viz.ppTagOpen(`table`, `border=1`);
									anyFileHit = true;
								}
							}
							else
							{
								if (gstats.showTree)
								{
									viz.pp("│  ".repeat(parentDir.depth + 1).join("") ~ "├" ~ "─ ");
								}
								else
								{
									foreach (fromSymlink; fromSymlinks)
									{
										viz.pp(fromSymlink,
											   " modified ",
											   faze(shortDurationString(_currTime - fromSymlink.timeLastModified),
													timeFace),
											   " ago",
											   " -> ");
									}
									// show file path/name
									viz.pp(displayedFilename(gstats, theFile).asPath); // show path
								}
							}

							// show line:column
							if (viz.form == VizForm.HTML)
							{
								viz.ppTagOpen("tr");
								viz.pp(to!string(nL+1).asCell,
									   to!string(offKB+1).asCell);
								viz.ppTagOpen("td");
								viz.ppTagOpen("code");
							}
							else
							{
								viz.pp(faze(":" ~ to!string(nL+1) ~ ":" ~ to!string(offKB+1) ~ ":",
											contextFace));
							}
							anyLineHit = true;
						}

						// show content prefix
						viz.pp(faze(to!string(rest[0..offKB]), thisFace));

						// show hit part
						if (!acronymOffsets.empty)
						{
							foreach (aIndex, currOff; acronymOffsets) /+ TODO: Reuse std.algorithm: zip or lockstep? Or create a new kind say named conv. +/
							{
								// context before
								if (aIndex >= 1)
								{
									immutable prevOff = acronymOffsets[aIndex-1];
									if (prevOff + 1 < currOff) // at least one letter in between
									{
										viz.pp(asCtx(ix, to!string(rest[prevOff + 1 .. currOff])));
									}
								}
								// hit letter
								viz.pp(asHit(ix, to!string(rest[currOff])));
							}
						}
						else
						{
							viz.pp(asHit(ix, to!string(rest[offKB..offKE])));
						}

						rest = rest[offKE..$]; // move forward in line

						hitCount++; // increase hit count
						parentDir.hitCount++;
						_hitsCountTotal++;

						goto foundHit;
					}
				}
			foundHit:
				if (offKB == -1) { break; }
			}

			// finalize line
			if (anyLineHit)
			{
				// show final context suffix
				viz.ppln(faze(rest, thisFace));
				if (viz.form == VizForm.HTML)
				{
					viz.ppTagClose("code");
					viz.ppTagClose("td");
					viz.pplnTagClose("tr");
				}
			}
			nL++;
		}

		if (gstats.showLineCounts)
		{
			gstats.lineCountsByFile[theFile] = nL;
		}

		if (anyFileHit)
		{
			viz.pplnTagClose("table");
		}

		// Previous solution
		// version (none)
		// {
		//	 ptrdiff_t offHit = 0;
		//	 foreach (ix, key; keys)
		//	 {
		//		 scope immutable hit1 = src.find(key); // single key hit
		//		 offHit = hit1.ptr - src.ptr;
		//		 if (!hit1.empty)
		//		 {
		//			 scope immutable src0 = src[0..offHit]; // src beforce hi
		//			 immutable rowHit = count(src0, newline);
		//			 immutable colHit = src0.retro.countUntil(newline); // count backwards till beginning of rowHit
		//			 immutable offBOL = offHit - colHit;
		//			 immutable cntEOL = src[offHit..$].countUntil(newline); // count forwards to end of rowHit
		//			 immutable offEOL = (cntEOL == -1 ? // if no hit
		//								 src.length :   // end of file
		//								 offHit + cntEOL); // normal case
		//			 viz.pp(faze(asPath(gstats.useHTML, dent.name), pathFace));
		//			 viz.ppln(":", rowHit + 1,
		//																			   ":", colHit + 1,
		//																			   ":", cast(string)src[offBOL..offEOL]);
		//		 }
		//	 }
		// }

		// switch (keys.length)
		// {
		// default:
		//	 break;
		// case 0:
		//	 break;
		// case 1:
		//	 immutable hit1 = src.find(keys[0]);
		//	 if (!hit1.empty)
		//	 {
		//		 viz.ppln(asPath(gstats.useHTML, dent.name[2..$]), ":1: HIT offset: ", hit1.length);
		//	 }
		//	 break;
		// // case 2:
		// //	 immutable hit2 = src.find(keys[0], keys[1]); // find two keys
		// //	 if (!hit2[0].empty) { viz.ppln(asPath(gstats.useHTML, dent.name[2..$]), ":1: HIT offset: ", hit2[0].length); }
		// //	 if (!hit2[1].empty) { viz.ppln(asPath(gstats.useHTML, dent.name[2..$]) , ":1: HIT offset: ", hit2[1].length); }
		// //	 break;
		// // case 3:
		// //	 immutable hit3 = src.find(keys[0], keys[1], keys[2]); // find two keys
		// //	 if (!hit3.empty)
		//		{
		// //		 viz.ppln(asPath(gstats.useHTML, dent.name[2..$]) , ":1: HIT offset: ", hit1.length);
		// //	 }
		// //	 break;
		// }
		return hitCount;
	}

	/** Process Regular File `theRegFile`. */
	void processRegFile(Viz viz,
						NotNull!Dir topDir,
						NotNull!RegFile theRegFile,
						NotNull!Dir parentDir,
						const string[] keys,
						ref Symlink[] fromSymlinks,
						size_t subIndex,
						GStats gstats)
	{
		scanRegFile(viz,
					topDir,
					theRegFile,
					parentDir,
					keys,
					fromSymlinks,
					subIndex);

		// check for operations
		/+ TODO: Reuse isSelectedFKind instead of this +/
		immutable ext = theRegFile.realExtension;
		if (ext in gstats.selFKinds.byExt)
		{
			auto matchingFKinds = gstats.selFKinds.byExt[ext];
			foreach (kind; matchingFKinds)
			{
				const hit = kind.operations.find!(a => a[0] == gstats.fOp);
				if (!hit.empty)
				{
					const fOp = hit.front;
					const cmd = fOp[1]; // command string
					import std.process: spawnProcess;
					import std.algorithm: splitter;
					dbg("TODO: Performing operation ", to!string(cmd),
						" on ", theRegFile.path,
						" by calling it using ", cmd);
					auto pid = spawnProcess(cmd.splitterASCIIAmong!(" ").array ~ [theRegFile.path]);
				}
			}
		}
	}

	/** Scan `elfFile` for ELF Symbols. */
	void scanELFFile(Viz viz,
					 NotNull!RegFile elfFile,
					 const string[] keys,
					 GStats gstats)
	{
		import nxt.elfdoc: sectionNameExplanations;
		/* TODO: Add mouse hovering help for sectionNameExplanations[section] */
		dbg("before: ", elfFile);
		ELF decoder = ELF.fromFile(elfFile._mmfile);
		dbg("after: ", elfFile);

		/* foreach (section; decoder.sections) */
		/* { */
		/*	 if (section.name.length) */
		/*	 { */
		/*		 /\* auto sst = section.StringTable; *\/ */
		/*		 //writeln("ELF Section named ", section.name); */
		/*	 } */
		/* } */

		/* const sectionNames = [".symtab"/\* , ".strtab", ".dynsym" *\/];	/+ TODO: These two other sections causes range exceptions. */ +/
		/* foreach (sectionName; sectionNames) */
		/* { */
		/*	 auto sts = decoder.getSection(sectionName); */
		/*	 if (!sts.isNull) */
		/*	 { */
		/*		 SymbolTable symtab = SymbolTable(sts); */
		/*		 /+ TODO: Use range: auto symbolsDemangled = symtab.symbols.map!(sym => demangler(sym.name).decodeSymbol); */ +/
		/*		 foreach (sym; symtab.symbols) // you can add filters here */
		/*		 { */
		/*			 if (gstats.demangleELF) */
		/*			 { */
		/*				 const hit = demangler(sym.name).decodeSymbol; */
		/*			 } */
		/*			 else */
		/*			 { */
		/*				 writeln("?: ", sym.name); */
		/*			 } */
		/*		 } */
		/*	 } */
		/* } */

		auto sst = decoder.getSymbolsStringTable;
		if (!sst.isNull)
		{
			import nxt.algorithm_ex: findFirstOfAnyInOrder;
			import std.range : tee;

			auto scan = (sst.strings
							.filter!(raw => !raw.empty) // skip empty raw string
							.tee!(raw => gstats.elfFilesBySymbol[raw.idup] ~= elfFile) // WARNING: needs raw.idup here because we can't rever to raw
							.map!(raw => demangler(raw).decodeSymbol)
							.filter!(demangling => (!keys.empty && // don't show anything if no keys given
													demangling.unmangled.findFirstOfAnyInOrder(keys)[1]))); // I love D :)

			if (!scan.empty &&
				`ELF` in gstats.selFKinds.byName) // if user selected ELF file show them
			{
				viz.pp(horizontalRuler,
					   displayedFilename(gstats, elfFile).asPath.asH!3,
					   asH!4(`ELF Symbol Strings Table (`, `.strtab`.asCode, `)`),
					   scan.asTable);
			}
		}
	}

	/** Search for Keys `keys` in Regular File `theRegFile`. */
	void scanRegFile(Viz viz,
					 NotNull!Dir topDir,
					 NotNull!RegFile theRegFile,
					 NotNull!Dir parentDir,
					 const string[] keys,
					 ref Symlink[] fromSymlinks,
					 size_t subIndex)
	{
		results.noBytesTotal += theRegFile.size;
		results.noBytesTotalContents += theRegFile.size;

		// Scan name
		if ((gstats.scanContext == ScanContext.all ||
			 gstats.scanContext == ScanContext.fileName ||
			 gstats.scanContext == ScanContext.regularFilename) &&
			!keys.empty)
		{
			immutable hitCountInName = scanForKeys(viz,
												   topDir, cast(NotNull!File)theRegFile, parentDir,
												   fromSymlinks,
												   theRegFile.name, keys, [], ScanContext.fileName);
		}

		// Scan Contents
		if ((gstats.scanContext == ScanContext.all ||
			 gstats.scanContext == ScanContext.fileContent) &&
			(gstats.showFileContentDups ||
			 gstats.showELFSymbolDups ||
			 !keys.empty) &&
			theRegFile.size != 0)		// non-empty file
		{
			// immutable upTo = size_t.max;

			/+ TODO: Flag for readText +/
			try
			{
				++gstats.noScannedRegFiles;
				++gstats.noScannedFiles;

				// ELF Symbols
				if (gstats.showELFSymbolDups &&
					theRegFile.ofKind(`ELF`, gstats.collectTypeHits, gstats.allFKinds))
				{
					scanELFFile(viz, theRegFile, keys, gstats);
				}

				// Check included kinds first because they are fast.
				KindHit incKindHit = isSelectedFKind(theRegFile);
				if (!gstats.selFKinds.byIndex.empty && /+ TODO: Do we really need this one? +/
					!incKindHit)
				{
					return;
				}

				// Super-Fast Key-File Bistogram Discardal. TODO: Trim scale factor to optimal value.
				enum minFileSize = 256; // minimum size of file for discardal.
				immutable bool doBist = theRegFile.size > minFileSize;
				immutable bool doNGram = (gstats.useNGrams &&
										  (!gstats.keyAsSymbol) &&
										  theRegFile.size > minFileSize);
				immutable bool doBitStatus = true;

				// Chunked Calculation of CStat in one pass. TODO: call async.
				theRegFile.calculateCStatInChunks(gstats.filesByContentId,
												  _scanChunkSize,
												  gstats.showFileContentDups,
												  doBist,
												  doBitStatus);

				// Match Bist of Keys with BistX of File
				bool[] bistHits;
				bool noBistMatch = false;
				if (doBist)
				{
					const theHist = theRegFile.bistogram8;
					auto hitsHist = keysBists.map!(a =>
												   ((a.value & theHist.value) ==
													a.value)); /+ TODO: Functionize to x.subsetOf(y) or reuse std.algorithm: setDifference or similar +/
					bistHits = hitsHist.map!`a == true`.array;
					noBistMatch = hitsHist.all!`a == false`;
				}
				/* int kix = 0; */
				/* foreach (hit; bistHits) { if (!hit) { debug dbg(`Assert key ` ~ keys[kix] ~ ` not in file ` ~ theRegFile.path); } ++kix; } */

				bool allXGramsMiss = false;
				if (doNGram)
				{
					ulong keysXGramUnionMatch = keysXGramsUnion.matchDenser(theRegFile.xgram);
					debug dbg(theRegFile.path,
							  ` sized `, theRegFile.size, ` : `,
							  keysXGramsUnion.length, `, `,
							  theRegFile.xgram.length,
							  ` gave match:`, keysXGramUnionMatch);
					allXGramsMiss = keysXGramUnionMatch == 0;
				}

				auto binHit = theRegFile.ofAnyKindIn(gstats.binFKinds,
													 gstats.collectTypeHits);
				const binKindHit = binHit[0];
				if (binKindHit)
				{
					import nxt.numerals: toOrdinal;
					const nnKind = binHit[1].enforceNotNull;
					const kindIndex = binHit[2];
					if (_showSkipped)
					{
						if (gstats.showTree)
						{
							immutable intro = subIndex == parentDir.subs.length - 1 ? `└` : `├`;
							viz.pp(`│  `.repeat(parentDir.depth + 1).join(``) ~ intro ~ `─ `);
						}
						viz.ppln(theRegFile, `: Skipped `, nnKind, ` file at `,
								 toOrdinal(kindIndex + 1), ` blind try`);
					}
					final switch (binKindHit)
					{
						case KindHit.none:
							break;
						case KindHit.cached:
							printSkipped(viz, theRegFile, subIndex, nnKind, binKindHit,
										 ` using cached KindId`);
							break;
						case KindHit.uncached:
							printSkipped(viz, theRegFile, subIndex, nnKind, binKindHit,
										 ` at ` ~ toOrdinal(kindIndex + 1) ~ ` extension try`);
							break;
					}
				}

				if (binKindHit != KindHit.none ||
					noBistMatch ||
					allXGramsMiss) // or no hits possible. TODO: Maybe more efficient to do histogram discardal first
				{
					results.noBytesSkipped += theRegFile.size;
				}
				else
				{
					// Search if not Binary

					// If Source file is ok
					auto src = theRegFile.readOnlyContents[];

					results.noBytesScanned += theRegFile.size;

					if (keys)
					{
						// Fast discardal of files with no match
						bool fastOk = true;
						if (!_caseFold) { // if no relaxation of search
							if (gstats.keyAsAcronym) // if no relaxation of search
							{
								/* TODO: Reuse findAcronym in algorith_ex. */
							}
							else // if no relaxation of search
							{
								switch (keys.length)
								{
								default: break;
								case 1: immutable hit1 = src.find(keys[0]); fastOk = !hit1.empty; break;
									// case 2: immutable hit2 = src.find(keys[0], keys[1]); fastOk = !hit2[0].empty; break;
									// case 3: immutable hit3 = src.find(keys[0], keys[1], keys[2]); fastOk = !hit3[0].empty; break;
									// case 4: immutable hit4 = src.find(keys[0], keys[1], keys[2], keys[3]); fastOk = !hit4[0].empty; break;
									// case 5: immutable hit5 = src.find(keys[0], keys[1], keys[2], keys[3], keys[4]); fastOk = !hit5[0].empty; break;
								}
							}
						}

						/+ TODO: Continue search from hit1, hit2 etc. +/

						if (fastOk)
						{
							foreach (tag; addTags) gstats.ftags.addTag(theRegFile, tag);
							foreach (tag; removeTags) gstats.ftags.removeTag(theRegFile, tag);

							if (theRegFile.size >= 8192)
							{
								/* if (theRegFile.xgram == null) { */
								/*	 theRegFile.xgram = cast(XGram*)core.stdc.stdlib.malloc(XGram.sizeof); */
								/* } */
								/* (*theRegFile.xgram).put(src); */
								/* theRegFile.xgram.put(src); */
								/* foreach (lix, ub0; line) { // for each ubyte in line */
								/*	 if (lix + 1 < line.length) { */
								/*		 immutable ub1 = line[lix + 1]; */
								/*		 immutable dix = (cast(ushort)ub0 | */
								/*						  cast(ushort)ub1*256); */
								/*		 (*theRegFile.xgram)[dix] = true; */
								/*	 } */
								/* } */
								auto shallowDenseness = theRegFile.bistogram8.denseness;
								auto deepDenseness = theRegFile.xgramDeepDenseness;
								// assert(deepDenseness >= 1);
								gstats.shallowDensenessSum += shallowDenseness;
								gstats.deepDensenessSum += deepDenseness;
								++gstats.densenessCount;
								/* dbg(theRegFile.path, `:`, theRegFile.size, */
								/*	 `, length:`, theRegFile.xgram.length, */
								/*	 `, deepDenseness:`, deepDenseness); */
							}

							theRegFile._cstat.hitCount = scanForKeys(viz,
																	 topDir, cast(NotNull!File)theRegFile, parentDir,
																	 fromSymlinks,
																	 src, keys, bistHits,
																	 ScanContext.fileContent);
						}
					}
				}

			}
			catch (FileException)
			{
				handleError(viz, theRegFile, false, subIndex);
			}
			catch (ErrnoException)
			{
				handleError(viz, theRegFile, false, subIndex);
			}
			theRegFile.freeContents; /+ TODO: Call lazily only when open count is too large +/
		}
	}

	/** Scan Symlink `symlink` at `parentDir` for `keys`
		Put results in `results`. */
	void scanSymlink(Viz viz,
					 NotNull!Dir topDir,
					 NotNull!Symlink theSymlink,
					 NotNull!Dir parentDir,
					 const string[] keys,
					 ref Symlink[] fromSymlinks)
	{
		// check for symlink cycles
		if (!fromSymlinks.find(theSymlink).empty)
		{
			if (gstats.showSymlinkCycles)
			{
				import std.range: back;
				viz.ppln(`Cycle of symbolic links: `,
						 fromSymlinks.asPath,
						 ` -> `,
						 fromSymlinks.back.target);
			}
			return;
		}

		// Scan name
		if ((gstats.scanContext == ScanContext.all ||
			 gstats.scanContext == ScanContext.fileName ||
			 gstats.scanContext == ScanContext.symlinkName) &&
			!keys.empty)
		{
			scanForKeys(viz,
						topDir, cast(NotNull!File)theSymlink, enforceNotNull(theSymlink.parent),
						fromSymlinks,
						theSymlink.name, keys, [], ScanContext.fileName);
		}

		// try {
		//	 results.noBytesTotal += dent.size;
		// } catch (Exception)
		//   {
		//	 dbg(`Couldn't get size of `,  dir.name);
		// }
		if (gstats.followSymlinks == SymlinkFollowContext.none) { return; }

		import std.range: popBackN;
		fromSymlinks ~= theSymlink;
		immutable targetPath = theSymlink.absoluteNormalizedTargetPath;
		if (targetPath.exists)
		{
			theSymlink._targetStatus = SymlinkTargetStatus.present;
			if (_topDirNames.all!(a => !targetPath.startsWith(a))) { // if target path lies outside of all rootdirs
				auto targetDent = DirEntry(targetPath);
				auto targetFile = getFile(enforceNotNull(gstats.rootDir), targetPath, targetDent.isDir);

				if (gstats.showTree)
				{
					viz.ppln(`│  `.repeat(parentDir.depth + 1).join(``) ~ `├` ~ `─ `,
							 theSymlink,
							 ` modified `,
							 faze(shortDurationString(_currTime - theSymlink.timeLastModified),
								  timeFace),
							 ` ago`, ` -> `,
							 targetFile.asPath,
							 faze(` outside of ` ~ (_topDirNames.length == 1 ? `tree ` : `all trees `),
								  infoFace),
							 gstats.topDirs.asPath,
							 faze(` is followed`, infoFace));
				}

				++gstats.noScannedSymlinks;
				++gstats.noScannedFiles;

				if	  (auto targetRegFile = cast(RegFile)targetFile)
				{
					processRegFile(viz, topDir, assumeNotNull(targetRegFile), parentDir, keys, fromSymlinks, 0, gstats);
				}
				else if (auto targetDir = cast(Dir)targetFile)
				{
					scanDir(viz, topDir, assumeNotNull(targetDir), keys, fromSymlinks);
				}
				else if (auto targetSymlink = cast(Symlink)targetFile) // target is a Symlink
				{
					scanSymlink(viz, topDir,
								assumeNotNull(targetSymlink),
								enforceNotNull(targetSymlink.parent),
								keys, fromSymlinks);
				}
			}
		}
		else
		{
			theSymlink._targetStatus = SymlinkTargetStatus.broken;

			if (gstats.showBrokenSymlinks)
			{
				_brokenSymlinks ~= theSymlink;

				foreach (ix, fromSymlink; fromSymlinks)
				{
					if (gstats.showTree && ix == 0)
					{
						immutable intro = `├`;
						viz.pp(`│  `.repeat(theSymlink.parent.depth + 1).join(``) ~ intro ~ `─ `,
							   theSymlink);
					}
					else
					{
						viz.pp(fromSymlink);
					}
					viz.pp(` -> `);
				}

				viz.ppln(faze(theSymlink.target, missingSymlinkTargetFace),
						 faze(` is missing`, warnFace));
			}
		}
		fromSymlinks.popBackN(1);
	}

	/** Scan Directory `parentDir` for `keys`. */
	void scanDir(Viz viz,
				 NotNull!Dir topDir,
				 NotNull!Dir theDir,
				 const string[] keys,
				 Symlink[] fromSymlinks = [],
				 int maxDepth = -1)
	{
		if (theDir.isRoot)  { results.reset; }

		// scan in directory name
		if ((gstats.scanContext == ScanContext.all ||
			 gstats.scanContext == ScanContext.fileName ||
			 gstats.scanContext == ScanContext.dirName) &&
			!keys.empty)
		{
			scanForKeys(viz,
						topDir,
						cast(NotNull!File)theDir,
						enforceNotNull(theDir.parent),
						fromSymlinks,
						theDir.name, keys, [], ScanContext.fileName);
		}

		try
		{
			size_t subIndex = 0;
			if (gstats.showTree)
			{
				immutable intro = subIndex == theDir.subs.length - 1 ? `└` : `├`;

				viz.pp(`│  `.repeat(theDir.depth).join(``) ~ intro ~
					   `─ `, theDir, ` modified `,
					   faze(shortDurationString(_currTime -
												theDir.timeLastModified),
							timeFace),
					   ` ago`);

				if (gstats.showUsage)
				{
					viz.pp(` of Tree-Size `, theDir.treeSize);
				}

				if (gstats.showSHA1)
				{
					viz.pp(` with Tree-Content-Id `, theDir.treeContentId);
				}
				viz.ppendl;
			}

			++gstats.noScannedDirs;
			++gstats.noScannedFiles;

			auto subsSorted = theDir.subsSorted(gstats.subsSorting);
			foreach (key, sub; subsSorted)
			{
				/* TODO: Functionize to scanFile */
				if (auto regFile = cast(RegFile)sub)
				{
					processRegFile(viz, topDir, assumeNotNull(regFile), theDir, keys, fromSymlinks, subIndex, gstats);
				}
				else if (auto subDir = cast(Dir)sub)
				{
					if (maxDepth == -1 || // if either all levels or
						maxDepth >= 1) { // levels left
						if (sub.name in gstats.skippedDirKindsMap) // if sub should be skipped
						{
							if (_showSkipped)
							{
								if (gstats.showTree)
								{
									immutable intro = subIndex == theDir.subs.length - 1 ? `└` : `├`;
									viz.pp(`│  `.repeat(theDir.depth + 1).join(``) ~ intro ~ `─ `);
								}

								viz.pp(subDir,
									   ` modified `,
									   faze(shortDurationString(_currTime -
																subDir.timeLastModified),
											timeFace),
									   ` ago`,
									   faze(`: Skipped Directory of type `, infoFace),
									   gstats.skippedDirKindsMap[sub.name].kindName);
							}
						}
						else
						{
							scanDir(viz, topDir,
									assumeNotNull(subDir),
									keys,
									fromSymlinks,
									maxDepth >= 0 ? --maxDepth : maxDepth);
						}
					}
				}
				else if (auto subSymlink = cast(Symlink)sub)
				{
					scanSymlink(viz, topDir, assumeNotNull(subSymlink), theDir, keys, fromSymlinks);
				}
				else
				{
					if (gstats.showTree) { viz.ppendl; }
				}
				++subIndex;

				if (ctrlC)
				{
					viz.ppln(`Ctrl-C pressed: Aborting scan of `, theDir);
					break;
				}
			}

			if (gstats.showTreeContentDups)
			{
				theDir.treeContentId; // better to put this after file scan for now
			}
		}
		catch (FileException)
		{
			handleError(viz, theDir, true, 0);
		}
	}

	/** Filter out `files` that lie under any of the directories `dirPaths`. */
	F[] filterUnderAnyOfPaths(F)(F[] files,
								 string[] dirPaths)
	{
		import std.algorithm: any;
		import std.array: array;
		auto dupFilesUnderAnyTopDirName = (files
										   .filter!(dupFile =>
													dirPaths.any!(dirPath =>
																  dupFile.path.startsWith(dirPath)))
										   .array // evaluate to array to get .length below
			);
		F[] hits;
		final switch (gstats.duplicatesContext)
		{
		case DuplicatesContext.internal:
			if (dupFilesUnderAnyTopDirName.length >= 2)
				hits = dupFilesUnderAnyTopDirName;
			break;
		case DuplicatesContext.external:
			if (dupFilesUnderAnyTopDirName.length >= 1)
				hits = files;
			break;
		}
		return hits;
	}

	/** Show Statistics. */
	void showContentDups(Viz viz)
	{
		import std.meta : AliasSeq;
		foreach (ix, kind; AliasSeq!(RegFile, Dir))
		{
			immutable typeName = ix == 0 ? `Regular File` : `Directory Tree`;
			viz.pp((typeName ~ ` Content Duplicates`).asH!2);
			foreach (digest, dupFiles; gstats.filesByContentId)
			{
				auto dupFilesOk = filterUnderAnyOfPaths(dupFiles, _topDirNames);
				if (dupFilesOk.length >= 2) // non-empty file/directory
				{
					auto firstDup = cast(kind)dupFilesOk[0];
					if (firstDup)
					{
						static if (is(kind == RegFile))
						{
							if (firstDup._cstat.kindId)
							{
								if (firstDup._cstat.kindId in gstats.allFKinds.byId)
								{
									viz.pp(asH!3(gstats.allFKinds.byId[firstDup._cstat.kindId],
												 ` files sharing digest `, digest, ` of size `, firstDup.treeSize));
								}
								else
								{
									dbg(firstDup.path ~ ` kind Id ` ~ to!string(firstDup._cstat.kindId) ~
										` could not be found in allFKinds.byId`);
								}
							}
							viz.pp(asH!3((firstDup._cstat.bitStatus == BitStatus.bits7) ? `ASCII File` : typeName,
										 `s sharing digest `, digest, ` of size `, firstDup.treeSize));
						}
						else
						{
							viz.pp(asH!3(typeName, `s sharing digest `, digest, ` of size `, firstDup.size));
						}

						viz.pp(asUList(dupFilesOk.map!(x => x.asPath.asItem)));
					}
				}
			}
		}
	}

	/** Show Statistics. */
	void showStats(Viz viz)
	{
		/* Duplicates */

		if (gstats.showNameDups)
		{
			viz.pp(`Name Duplicates`.asH!2);
			foreach (digest, dupFiles; gstats.filesByName)
			{
				auto dupFilesOk = filterUnderAnyOfPaths(dupFiles, _topDirNames);
				if (!dupFilesOk.empty)
				{
					viz.pp(asH!3(`Files with same name `,
								 faze(dupFilesOk[0].name, fileFace)),
						   asUList(dupFilesOk.map!(x => x.asPath.asItem)));
				}
			}
		}

		if (gstats.showLinkDups)
		{
			viz.pp(`Inode Duplicates (Hardlinks)`.asH!2);
			foreach (inode, dupFiles; gstats.filesByInode)
			{
				auto dupFilesOk = filterUnderAnyOfPaths(dupFiles, _topDirNames);
				if (dupFilesOk.length >= 2)
				{
					viz.pp(asH!3(`Files with same inode ` ~ to!string(inode) ~
								 ` (hardlinks): `),
						   asUList(dupFilesOk.map!(x => x.asPath.asItem)));
				}
			}
		}

		if (gstats.showFileContentDups)
		{
			showContentDups(viz);
		}

		if (gstats.showELFSymbolDups &&
			!keys.empty) // don't show anything if no keys where given
		{
			viz.pp(`ELF Symbol Duplicates`.asH!2);
			foreach (raw, dupFiles; gstats.elfFilesBySymbol)
			{
				auto dupFilesOk = filterUnderAnyOfPaths(dupFiles, _topDirNames);
				if (dupFilesOk.length >= 2)
				{
					const demangling = demangler(raw).decodeSymbol;
					if (demangling.unmangled.findFirstOfAnyInOrder(keys)[1])
					{
						viz.pp(asH!3(`ELF Files with same symbol ` ~ to!string(raw)),
							   asUList(dupFilesOk.map!(x => x.asPath.asItem)));
					}
				}
			}
		}

		/* Broken Symlinks */
		if (gstats.showBrokenSymlinks &&
			!_brokenSymlinks.empty)
		{
			viz.pp(`Broken Symlinks `.asH!2,
				   asUList(_brokenSymlinks.map!(x => x.asPath.asItem)));
		}

		/* Counts */
		viz.pp(`Scanned Types`.asH!2,
			   /* asUList(asItem(gstats.noScannedDirs, ` Dirs, `), */
			   /*		 asItem(gstats.noScannedRegFiles, ` Regular Files, `), */
			   /*		 asItem(gstats.noScannedSymlinks, ` Symbolic Links, `), */
			   /*		 asItem(gstats.noScannedSpecialFiles, ` Special Files, `), */
			   /*		 asItem(`totalling `, gstats.noScannedFiles, ` Files`) // on extra because of lack of root */
			   /*	 ) */
			   asTable(asRow(asCell(asBold(`Scan Count`)),
							 asCell(asBold(`File Type`))),
					   asRow(asCell(gstats.noScannedDirs),
							 asCell(asItalic(`Dirs`))),
					   asRow(asCell(gstats.noScannedRegFiles),
							 asCell(asItalic(`Regular Files`))),
					   asRow(asCell(gstats.noScannedSymlinks),
							 asCell(asItalic(`Symbolic Links`))),
					   asRow(asCell(gstats.noScannedSpecialFiles),
							 asCell(asItalic(`Special Files`))),
					   asRow(asCell(gstats.noScannedFiles),
							 asCell(asItalic(`Files`)))
				   )
			);

		if (gstats.densenessCount)
		{
			viz.pp(`Histograms`.asH!2,
				   asUList(asItem(`Average Byte Bistogram (Binary Histogram) Denseness `,
								  cast(real)(100*gstats.shallowDensenessSum / gstats.densenessCount), ` Percent`),
						   asItem(`Average Byte `, NGramOrder, `-Gram Denseness `,
								  cast(real)(100*gstats.deepDensenessSum / gstats.densenessCount), ` Percent`)));
		}

		viz.pp(`Scanned Bytes`.asH!2,
			   asUList(asItem(`Scanned `, results.noBytesScanned),
					   asItem(`Skipped `, results.noBytesSkipped),
					   asItem(`Unreadable `, results.noBytesUnreadable),
					   asItem(`Total Contents `, results.noBytesTotalContents),
					   asItem(`Total `, results.noBytesTotal),
					   asItem(`Total number of hits `, results.numTotalHits),
					   asItem(`Number of Files with hits `, results.numFilesWithHits)));

		viz.pp(`Some Math`.asH!2);

		{
			struct Stat
			{
				particle2f particle;
				point2r point;
				vec2r velocity;
				vec2r acceleration;
				mat2 rotation;
				Rational!uint ratInt;
				Vector!(Rational!int, 4) ratIntVec;
				Vector!(float, 2, true) normFloatVec2;
				Vector!(float, 3, true) normFloatVec3;
				Point!(Rational!int, 4) ratIntPoint;
			}

			/* Vector!(Complex!float, 4) complexVec; */

			viz.ppln(`A number: `, 1.2e10);
			viz.ppln(`Randomize particle2f as TableNr0: `, randomInstanceOf!particle2f.asTableNr0);

			alias Stats3 = Stat[3];
			auto stats = new Stat[3];
			randomize(stats);
			viz.ppln(`A ` ~ typeof(stats).stringof, `: `, stats.randomize.asTable);

			{
				auto x = randomInstanceOf!Stats3;
				foreach (ref e; x)
				{
					e.velocity *= 1e9;
				}
				viz.ppln(`Some Stats: `,
						 x.asTable);
			}
		}


	}
}

void scanner(string[] args)
{
	// Register the SIGINT signal with the signalHandler function call:
	version (linux)
	{
		signal(SIGABRT, &signalHandler);
		signal(SIGTERM, &signalHandler);
		signal(SIGQUIT, &signalHandler);
		signal(SIGINT, &signalHandler);
	}


	auto term = Terminal(ConsoleOutputType.linear);
	auto scanner = new Scanner!Terminal(args, term);
}
