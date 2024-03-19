// version = useMir;
version = usePhobos;

int main(string[] args)
{
	version (useMir)
	{
		import mir.format : text;
		assert(text("hello", " world ", 42) == "hello world 42");
	}
	version (usePhobos)
	{
		import std.format :  format;
		assert(format("%s %s %d", "hello", "world", 42) == "hello world 42");
	}
	return 0;
}
