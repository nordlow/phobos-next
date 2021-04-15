/// File system types and operations.
module nxt.file_system;

@safe:

/// URL.
struct URL
{
    string value;
    alias value this;
}

/// Computer Path.
struct Path
{
    string value;
    alias value this;
}

/// Directory Name.
struct DirName
{
    string value;
    alias value this;
}

/// Directory Path.
struct DirPath                  // TOOD: public Path
{
    string value;
    alias value this;
}
