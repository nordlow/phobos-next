module deimos.libtcc;

pragma(lib, "tcc");

extern (C) nothrow @nogc:

struct TCCState{}

/** Create a new TCC compilation context */
TCCState* tcc_new() pure;

/** Free a TCC compilation context */
void tcc_delete(scope TCCState* s) pure;

/** Set CONFIG_TCCDIR at runtime */
void tcc_set_lib_path(scope TCCState* s, scope const char* path) pure;

/** Set error/warning display callback */
void tcc_set_error_func(scope TCCState* s, void* error_opaque,
						void function(void* opaque, const char* msg) error_func) pure;

/** Set options as from command line (multiple supported) */
int tcc_set_options(scope TCCState *s, scope const char *str) pure;

/*****************************/
/** Preprocessor */

/** Add include path */
int tcc_add_include_path(scope TCCState* s, scope const char* pathname) pure;

/** Add const system include path */
int tcc_add_sysinclude_path(scope TCCState* s, scope const char* pathname) pure;

/** Define preprocessor symbol 'sym'. Can put optional value */
void tcc_define_symbol(scope TCCState* s, scope const char* sym, scope const char* value) pure;

/** Undefine preprocess symbol 'sym' */
void tcc_undefine_symbol(scope TCCState* s, scope const char* sym) pure;

/*****************************/
/** Compiling */

/** Add a file (C file, dll, object, library, ld script). Return -1 if error. */
int tcc_add_file(scope TCCState* s, scope const char* filename) pure;

/** Compile a string containing a C source. Return -1 if error. */
int tcc_compile_string(scope TCCState* s, scope const char* buf) pure;

/*****************************/
/** Linking commands */

/** Set output type. MUST BE CALLED before any compilation */
int tcc_set_output_type(scope TCCState* s, int output_type) pure;

enum {
	TCC_OUTPUT_MEMORY   = 0, /** Output will be run const memory (default) */
	TCC_OUTPUT_EXE	  = 1, /** Executable file */
	TCC_OUTPUT_DLL	  = 2, /** Dynamic library */
	TCC_OUTPUT_OBJ	  = 3, /** Object file */
	TCC_OUTPUT_PREPROCESS = 4, /** Only preprocess (used internally) */
}

/** Equivalent to -Lpath option */
int tcc_add_library_path(scope TCCState* s, scope const char* pathname) pure;

/** The library name is the same as the argument of the '-l' option */
int tcc_add_library(scope TCCState* s, scope const char* libraryname) pure;

/** Add a symbol to the compiled program */
int tcc_add_symbol(scope TCCState* s, scope const char* name, scope const void* val) pure;

/** Output an executable, library or object file. DO NOT call
   tcc_relocate() before. */
int tcc_output_file(scope TCCState* s, scope const char* filename);

/** Link and run main() function and return its value. DO NOT call
   tcc_relocate() before. */
int tcc_run(scope TCCState* s, int argc, char** argv);


/** Do all relocations (needed before using tcc_get_symbol()) */
int tcc_relocate(scope TCCState* s1, void* ptr);
/** Possible values for 'ptr':
   - TCC_RELOCATE_AUTO : Allocate and manage memory internally
   - NULL			  : return required memory size for the step below
   - memory address	: copy code to memory passed by the caller
   returns -1 if error. */
enum TCC_RELOCATE_AUTO = cast(void*) 1;

/** Return symbol value or NULL if not found */
void* tcc_get_symbol(scope TCCState* s, scope const char* name) pure;
