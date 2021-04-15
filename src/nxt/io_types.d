/// Input output types.
module nxt.io_types;

@safe:

// TODO: make these strong sub-types of string
alias URL = string;             ///< URL.
alias Path = string;            ///< Path.
alias DirName = string;         ///< Directory name.
alias DirPath = string;         ///< Directory path.
alias Name = string;            ///< Build name.
alias Cmd = string;             ///< Commad (name or path).
alias CmdFlag = string;         ///< Command line flag.
alias DlangVersionName = string; ///< D `version` symbol.
