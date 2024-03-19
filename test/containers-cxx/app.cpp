#include <iostream>
#include <iomanip>
#include <string>
#include <vector>
#include <unordered_set>
#include <unordered_map>
#include <set>
#include <map>
#include <chrono>
#include <algorithm>
#include <random>
#include <bit>

#include <typeinfo>
#include <cxxabi.h>

#include "flat_hash_map.hpp"
#include "bytell_hash_map.hpp"
#include "robin_hood.h"

// https://github.com/Tessil/robin-map
#include "tsl/robin_set.h"
#include "tsl/robin_map.h"

#include "has_member.hpp"
define_has_member(reserve);

using namespace std;
namespace cr = chrono;

std::string& inplace_replace_all(std::string& s, const std::string& from, const std::string& to)
{
    if (!from.empty())
        for (size_t pos = 0; (pos = s.find(from, pos)) != std::string::npos; pos += to.size())
            s.replace(pos, from.size(), to);
    return s;
}

using Sample = ulong;                ///< Sample.
using TestSource = std::vector<Sample>; ///< TestSource.
using Clock = cr::high_resolution_clock;
using Dur = decltype(Clock::now() - Clock::now()); ///< Duration.
using Durs = std::vector<Dur>;                     ///< Durations.

template<class T>
void showHeader()
{
    int status;
    std::string name = abi::__cxa_demangle(typeid(T).name(), 0, 0, &status);
    name = inplace_replace_all(name, "unsigned long", "ulong");
    // name = inplace_replace_all(name, "std::", "");
    cout << "--- " << name << ":" << endl;
}

void showResults(const string& tag, const Durs& durs, size_t elementCount, bool okFlag)
{
    const auto min_dur = *min_element(begin(durs), end(durs));
    const auto dur_ns = cr::duration_cast<cr::nanoseconds>(min_dur).count();
    cout << tag << ":"
         << fixed << right << setprecision(0) << setw(3) << setfill(' ')
         << (static_cast<double>(dur_ns)) / elementCount
         << "ns"
         << (okFlag ? "" : " ERR")
         << ", ";
}

template<class Vector>
void benchmarkVector(const TestSource& testSource, const size_t runCount)
{
    cout << "- ";
    Vector x;
    if constexpr (has_member(Vector, reserve))
        x.reserve(testSource.size());

    Durs durs(runCount);

    for (size_t runIx = 0; runIx != runCount; ++runIx)
    {
        auto beg = Clock::now();
        for (size_t i = 0; i < testSource.size(); ++i)
            x.push_back(testSource[i]);
        durs[runIx] = Clock::now() - beg;
    }
    showResults("push_back", durs, testSource.size(), true);

    showHeader<Vector>();
}

template<class Set, bool reserveFlag>
Set benchmarkSet_insert(const TestSource& testSource, const size_t runCount)
{
    Durs durs(runCount);

    Set x;

    if constexpr (reserveFlag)
        x.reserve(testSource.size());

    for (size_t runIx = 0; runIx != runCount; ++runIx)
    {
        const auto beg = Clock::now();
        for (const auto& e : testSource)
            x.insert(e);
        durs[runIx] = Clock::now() - beg;
    }
    if constexpr (reserveFlag)
        showResults("insert (reserved)", durs, testSource.size(), true);
    else
        showResults("insert", durs, testSource.size(), true);

    return x;
}

template<class Set>
void benchmarkSet(const TestSource& testSource, const size_t runCount)
{
    cout << "- ";

    if constexpr (has_member(Set, reserve))
        const Set __attribute__((unused)) x = benchmarkSet_insert<Set, true>(testSource, runCount);

    Durs durs(runCount);

    Set x = benchmarkSet_insert<Set, false>(testSource, runCount);

    bool allHit = true;
    for (size_t runIx = 0; runIx != runCount; ++runIx)
    {
        const auto beg = Clock::now();
        for (const auto& e : testSource)
        {
            const auto hit = x.find(e);
            if (hit == x.end()) { allHit = false; }
        }
        durs[runIx] = Clock::now() - beg;
    }
    showResults("find", durs, testSource.size(), allHit);

    bool allErase = true;
    for (size_t runIx = 0; runIx != runCount; ++runIx)
    {
        const auto beg = Clock::now();
        for (const auto& e : testSource)
        {
            const auto count = x.erase(e);
            if (count != 1) { allErase = false; }
        }
        durs[runIx] = Clock::now() - beg;
    }
    showResults("erase", durs, testSource.size(), allErase);

    for (size_t runIx = 0; runIx != runCount; ++runIx)
    {
        const auto beg = Clock::now();
        for (const auto& e : testSource)
            x.insert(e);
        durs[runIx] = Clock::now() - beg;
    }
    showResults("reinsert", durs, testSource.size(), true);

    x.clear();

    showHeader<Set>();
}

template<class Map>
void benchmarkMap(const TestSource& testSource, const size_t runCount)
{
    cout << "- ";
    Map x;
    if constexpr (has_member(Map, reserve))
        x.reserve(testSource.size());

    Durs durs(runCount);

    for (size_t runIx = 0; runIx != runCount; ++runIx)
    {
        const auto beg = Clock::now();
        for (const auto& e : testSource)
            x[e] = e;
        durs[runIx] = Clock::now() - beg;
    }
    showResults("insert", durs, testSource.size(), true);

    bool allHit = true;
    for (size_t runIx = 0; runIx != runCount; ++runIx)
    {
        const auto beg = Clock::now();
        for (const auto& e : testSource)
        {
            const auto hit = x.find(e);
            if (hit == x.end()) { allHit = false; }
        }
        durs[runIx] = Clock::now() - beg;
    }
    showResults("find", durs, testSource.size(), allHit);

    bool allErase = true;
    for (size_t runIx = 0; runIx != runCount; ++runIx)
    {
        const auto beg = Clock::now();
        for (const auto& e : testSource)
        {
            const auto count = x.erase(e);
            if (count != 1) { allErase = false; }
        }
        durs[runIx] = Clock::now() - beg;
    }
    showResults("erase", durs, testSource.size(), allErase);

    for (size_t runIx = 0; runIx != runCount; ++runIx)
    {
        const auto beg = Clock::now();
        for (const auto& e : testSource)
            x[e] = e;
        durs[runIx] = Clock::now() - beg;
    }
    showResults("reinsert", durs, testSource.size(), true);

    x.clear();

    showHeader<Map>();
}

TestSource getSource(size_t elementCount)
{
    std::random_device rd;
    std::mt19937 g(rd());

    TestSource source(elementCount);
    for (size_t i = 0; i < elementCount; ++i)
        source[i] = i;
    std::shuffle(begin(source), end(source), g);
    return source;
}

// See: https://lemire.me/blog/2018/08/15/fast-strongly-universal-64-bit-hashing-everywhere/
// TODO: use
size_t sample_hash(const Sample & x)
{
    // https://en.cppreference.com/w/cpp/numeric/rotr
    const ulong h1 = x * 0xA24BAED4963EE407UL;
    const ulong h2 = std::rotr(x, 32) * 0x9FB21C651E98DF25UL;
    const ulong h = std::rotr(h1 + h2, 32);
    return h;
}

void benchmarkAllUnorderedSets(const TestSource& testSource,
                               const size_t runCount)
{
    /* TODO: benchmarkSet<tsl::robin_set<Sample, decltype(sample_hash)>>(testSource, runCount); */
    benchmarkSet<tsl::robin_set<Sample>>(testSource, runCount);
    benchmarkSet<tsl::robin_set<Sample>>(testSource, runCount);

    benchmarkSet<tsl::robin_pg_set<Sample>>(testSource, runCount);

    benchmarkSet<ska::flat_hash_set<Sample>>(testSource, runCount);
    /* TODO: benchmarkSet<ska::bytell_hash_set<Sample>>(testSource, runCount); */

    benchmarkSet<robin_hood::unordered_flat_set<Sample>>(testSource, runCount);
    benchmarkSet<robin_hood::unordered_node_set<Sample>>(testSource, runCount);
    benchmarkSet<robin_hood::unordered_set<Sample>>(testSource, runCount);

    benchmarkSet<std::unordered_set<Sample>>(testSource, runCount);
    benchmarkSet<std::unordered_multiset<Sample>>(testSource, runCount);
}

int main(__attribute__((unused)) int argc,
         __attribute__((unused)) const char* argv[],
         __attribute__((unused)) const char* envp[])
{
    const size_t elementCount = 400'000; ///< Number of elements.
    const size_t runCount = 5;			 ///< Number of runs per benchmark.

    const auto testSource = getSource(elementCount);

    cout << "# Vector:" << endl;
    benchmarkVector<std::vector<Sample>>(testSource, runCount);

    cout << "# Unordered Sets:" << endl;
    benchmarkAllUnorderedSets(testSource, runCount);

    cout << "# Ordered Sets:" << endl;
    benchmarkSet<std::set<Sample>>(testSource, runCount);
    benchmarkSet<std::multiset<Sample>>(testSource, runCount);

    cout << "# Unordered Maps:" << endl;
    benchmarkMap<tsl::robin_map<Sample, Sample>>(testSource, runCount);
    benchmarkMap<tsl::robin_pg_map<Sample, Sample>>(testSource, runCount);
    benchmarkMap<ska::flat_hash_map<Sample, Sample>>(testSource, runCount);
    /* TODO: benchmarkMap<ska::bytell_hash_map<Sample, Sample>>(testSource, runCount); */
    benchmarkMap<robin_hood::unordered_flat_map<Sample, Sample>>(testSource, runCount);
    benchmarkMap<robin_hood::unordered_node_map<Sample, Sample>>(testSource, runCount);
    benchmarkMap<robin_hood::unordered_map<Sample, Sample>>(testSource, runCount);
    benchmarkMap<std::unordered_map<Sample, Sample>>(testSource, runCount);
    benchmarkMap<std::unordered_map<Sample, std::string>>(testSource, runCount);

    cout << "# Ordered Maps:" << endl;
    benchmarkMap<std::map<Sample, Sample>>(testSource, runCount);

    return 0;
}
