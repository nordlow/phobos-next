#include <numeric>

using namespace std;

constexpr int naiveSum(unsigned int n) { // uses iterators
    auto p = new int[n];
    iota(p, p+n, 1);
    auto tmp = accumulate(p, p+n, 0);
    delete[] p;
    return tmp;
}

constexpr int smartSum(unsigned int n) {
    return (n*(1+n))/2;
}

static_assert(naiveSum(10) == smartSum(10));
static_assert(naiveSum(11) == smartSum(11));
