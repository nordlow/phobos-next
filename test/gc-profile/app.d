int main(string[] args) {
	const n = 10;
	foreach (i; 0 .. n)
		f(2);
	return 0;
}

void f(size_t n) {
	foreach (i; 0 .. n) {
		auto _ = new int[1];
		g(2);
	}
}

void g(size_t n) {
	foreach (i; 0 .. n)
		auto _ = new int[1];
}
