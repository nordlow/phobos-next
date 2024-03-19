Key takeaway is that `lemireHash64` has very good collision statistics (with an
`averageProbeCount` of 1) in the test in `app.d` and very close to
`identityHash64` having minimal overhead.
