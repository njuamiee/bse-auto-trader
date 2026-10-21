/// Unit tests for the engine core. Run with `moon test`.

/// Float values can differ in the last bits, so compare within a tolerance.
fn nearly(a : Double, b : Double, tol : Double) -> Bool {
  let d = a - b
  if d < 0.0 {
    0.0 - d <= tol
  } else {
    d <= tol
  }
}

///|
fn tol() -> Double {
  0.000000000001
}

test "mean of a simple column" {
  assert_eq(nearly(mean([1.0, 2.0, 3.0, 4.0]), 2.5, tol()), true)
}

test "mean of an empty column is zero" {
  assert_eq(mean([]), 0.0)
}

test "sample standard deviation matches the textbook value" {
  let xs = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
  assert_eq(nearly(sample_std(xs), 2.13808993529939, 0.000000001), true)
}

test "a constant column has zero spread" {
  assert_eq(sample_std([3.0, 3.0, 3.0]), 0.0)
}

test "z-score is centred with unit spread" {
  let z = zscore([1.0, 2.0, 3.0, 4.0, 5.0])
  assert_eq(nearly(mean(z), 0.0, tol()), true)
  assert_eq(nearly(sample_std(z), 1.0, tol()), true)
}

test "z-score of a constant column is all zeros" {
  let z = zscore([7.0, 7.0, 7.0])
  assert_eq(mean(z), 0.0)
  assert_eq(z[0], 0.0)
  assert_eq(z[2], 0.0)
}

test "winsorize pulls the outlier back inside the band" {
  let xs = [1.0, 2.0, 3.0, 4.0, 100.0]
  let w = winsorize_std(xs, 1.5)
  let hi = mean(xs) + 1.5 * sample_std(xs)
  assert_eq(w[4] <= hi + tol(), true)
  assert_eq(w[4] < 100.0, true)
  assert_eq(w[0], 1.0)
}

test "pearson detects perfect positive dependence" {
  assert_eq(nearly(pearson([1.0, 2.0, 3.0], [2.0, 4.0, 6.0]), 1.0, tol()), true)
}

test "pearson detects perfect negative dependence" {
  assert_eq(
    nearly(pearson([1.0, 2.0, 3.0], [6.0, 4.0, 2.0]), -1.0, tol()),
    true,
  )
}

test "pearson returns zero for mismatched lengths" {
  assert_eq(pearson([1.0, 2.0], [1.0, 2.0, 3.0]), 0.0)
}

test "average ranks handle ties" {
  let r = rank_average([10.0, 20.0, 20.0, 30.0])
  assert_eq(nearly(r[0], 1.0, tol()), true)
  assert_eq(nearly(r[1], 2.5, tol()), true)
  assert_eq(nearly(r[2], 2.5, tol()), true)
  assert_eq(nearly(r[3], 4.0, tol()), true)
}

test "spearman is one for any monotone series" {
  assert_eq(nearly(spearman([1.0, 2.0, 3.0], [5.0, 50.0, 500.0]), 1.0, tol()), true)
}

test "ic is computed on ranks, not raw values" {
  let d = new_day(
    ["a", "b", "c"],
    [0.01, 0.02, 0.03],
    [0.03, 0.02, 0.01],
    [0.1, 0.2, 0.3],
    [0.05, 0.02, 0.09],
  )
  assert_eq(nearly(ic(d, Momentum), 0.5, tol()), true)
  assert_eq(nearly(ic(d, Turnover), -0.5, tol()), true)
}

test "icir is mean over spread" {
  assert_eq(nearly(icir([0.1, 0.2, 0.3]), 2.0, tol()), true)
}

test "icir of a flat series is zero" {
  assert_eq(icir([0.2, 0.2, 0.2]), 0.0)
}

test "ic vector has one entry per day" {
  let days = [
    new_day(["a", "b", "c"], [1.0, 2.0, 3.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.1, 0.2, 0.3]),
    new_day(["a", "b", "c"], [3.0, 2.0, 1.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.3, 0.2, 0.1]),
  ]
  let ics = ic_vector(days, Momentum)
  assert_eq(ics.length(), 2)
  assert_eq(nearly(ics[0], 1.0, tol()), true)
  assert_eq(nearly(ics[1], 1.0, tol()), true)
}

test "normalize weights keeps the sign and scales to one" {
  let ws = normalize_weights([2.0, -2.0])
  assert_eq(nearly(ws[0], 0.5, tol()), true)
  assert_eq(nearly(ws[1], -0.5, tol()), true)
}

test "weights that are all zero stay zero" {
  let ws = normalize_weights([0.0, 0.0])
  assert_eq(ws[0], 0.0)
  assert_eq(ws[1], 0.0)
}

test "composite blends columns with the given weights" {
  let d = new_day(
    ["a", "b"],
    [1.0, 2.0],
    [2.0, 1.0],
    [0.0, 0.0],
    [0.0, 0.0],
  )
  let scores = composite(d, all_features(), [1.0, 1.0, 0.0], 3.0)
  assert_eq(nearly(scores[0], scores[1], tol()), true)
}

test "top-n returns the best first" {
  let picks = top_n(["a", "b", "c", "d"], [0.1, 0.9, 0.5, 0.2], 2)
  assert_eq(picks.length(), 2)
  assert_eq(picks[0], "b")
  assert_eq(picks[1], "c")
}

test "asking for more than the universe returns everything" {
  let picks = top_n(["a", "b"], [0.1, 0.2], 10)
  assert_eq(picks.length(), 2)
}

test "asking for none returns nothing" {
  let picks = top_n(["a", "b"], [0.1, 0.2], 0)
  assert_eq(picks.length(), 0)
}
