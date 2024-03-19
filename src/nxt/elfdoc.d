module nxt.elfdoc;

/* See_Also: http://forum.dlang.org/thread/owhfdwrpfuiehzpiuqux@forum.dlang.org#post-mailman.1520.1346443034.31962.digitalmars-d-learn:40puremagic.com */
enum string[string] sectionNameExplanations = [
	/* Special Sections */
	".bss" : "Holds data that contributes to the program's memory image. The program may treat this data as uninitialized. However, the system shall initialize this data with zeroes when the program begins to run. The section occupies no file space, as indicated by the section type, SHT_NOBITS",
	".comment" : "This section holds version control information.",
	".data" : "This section holds initialized data that contribute to the program's memory image.",
	".data1" : "This section holds initialized data that contribute to the program's memory image.",
	".debug" : "This section holds information for symbolic debugging. The contents are unspecified. All section names with the prefix .debug hold information for symbolic debugging. The contents of these sections are unspecified.",
	".dynamic" : "This section holds dynamic linking information. The section's attributes will include the SHF_ALLOC bit. Whether the SHF_WRITE bit is set is processor specific. See Chapter 5 for more information.",
	".dynstr" : "This section holds strings needed for dynamic linking, most commonly the strings that represent the names associated with symbol table entries. See Chapter 5 for more information.",
	".dynsym" : "This section holds the dynamic linking symbol table, as described in `Symbol Table'. See Chapter 5 for more information.",
	".fini" : "This section holds executable instructions that contribute to the process termination code. That is, when a program exits normally, the system arranges to execute the code in this section.",
	".fini_array" : "This section holds an array of function pointers that contributes to a single termination array for the executable or shared object containing the section.",
	".hash" : "This section holds a symbol hash table. See `Hash Table' in Chapter 5 for more information.",
	".init" : "This section holds executable instructions that contribute to the process initialization code. When a program starts to run, the system arranges to execute the code in this section before calling the main program entry point (called main for C programs)",
	".init_array" : "This section holds an array of function pointers that contributes to a single initialization array for the executable or shared object containing the section.",
	".interp" : "This section holds the path name of a program interpreter. If the file has a loadable segment that includes relocation, the sections' attributes will include the SHF_ALLOC bit; otherwise, that bit will be off. See Chapter 5 for more information.",
	".line" : "This section holds line number information for symbolic debugging, which describes the correspondence between the source program and the machine code. The contents are unspecified.",
	".note" : "This section holds information in the format that `Note Section' in Chapter 5 describes of the System V Application Binary Interface, Edition 4.1.",
	".preinit_array" : "This section holds an array of function pointers that contributes to a single pre-initialization array for the executable or shared object containing the section.",
	".rodata" : "This section holds read-only data that typically contribute to a non-writable segment in the process image. See `Program Header' in Chapter 5 for more information.",
	".rodata1" : "This section hold sread-only data that typically contribute to a non-writable segment in the process image. See `Program Header' in Chapter 5 for more information.",
	".shstrtab" : "This section holds section names.",
	".strtab" : "This section holds strings, most commonly the strings that represent the names associated with symbol table entries. If the file has a loadable segment that includes the symbol string table, the section's attributes will include the SHF_ALLOC bit; otherwi",
	".symtab" : "This section holds a symbol table, as `Symbol Table'. in this chapter describes. If the file has a loadable segment that includes the symbol table, the section's attributes will include the SHF_ALLOC bit; otherwise, that bit will be off.",
	".tbss" : "This section holds uninitialized thread-local data that contribute to the program's memory image. By definition, the system initializes the data with zeros when the data is instantiated for each new execution flow. The section occupies no file space, as indicated by the section type, SHT_NOBITS. Implementations need not support thread-local storage.",
	".tdata" : "This section holds initialized thread-local data that contributes to the program's memory image. A copy of its contents is instantiated by the system for each new execution flow. Implementations need not support thread-local storage.",
	".text" : "This section holds the `text,' or executable instructions, of a program.",

	/* Additional Special Sections */
	".ctors" : "This section contains a list of global constructor function pointers.",
	".dtors" : "This section contains a list of global destructor function pointers.",
	".eh_frame" : "This section contains information necessary for frame unwinding during exception handling.",
	".eh_frame_hdr" : "This section contains a pointer to the .eh_frame section which is accessible to the runtime support code of a C++ application. This section may also contain a binary search table which may be used by the runtime support code to more efficiently access records in the .eh_frame section.",
	".gnu.version" : "This section contains the Symbol Version Table.",
	".gnu.version_d" : "This section contains the Version Definitions.",
	".gnu.version_r" : "This section contains the Version Requirments.",
	".jcr" : "This section contains information necessary for registering compiled Java classes. The contents are compiler-specific and used by compiler initialization functions.",
	".note.ABI-tag" : "Specify ABI details.",
	".stab" : "This section contains debugging information. The contents are not specified as part of the LSB.",
	".stabstr" : "This section contains strings associated with the debugging infomation contained in the .stab section.",
	];
