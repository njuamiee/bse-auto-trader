/// Cross-sectional statistics for the BSE auto-trader engine.

/// Every function in this file is pure: given the same input it always
/// returns the same output, so results can be replayed and audited.

/// Arithmetic mean. Returns 0.0 for an empty array so callers stay total.
pub fn mean(xs : Array[Double]) -> Double {
  let n = xs.length()
  if n == 0 {
    0.0
  } else {
    let mut sum = 0.0
    for i in 0..<n {
      sum = sum + xs[i]
    }
    sum / n.to_double()
  }
}

/// Sample standard deviation with an (n - 1) denominator.
/// Returns 0.0 when there are fewer than two observations.
pub fn sample_std(xs : Array[Double]) -> Double {
  let n = xs.length()
  if n < 2 {
    0.0
  } else {
    let m = mean(xs)
    let mut sq = 0.0
    for i in 0..<n {
      let d = xs[i] - m
      sq = sq + d * d
    }
    (sq / (n - 1).to_double()).sqrt()
  }
}

/// Winsorize at mean +/- k standard deviations.
/// Keeps extreme factor values from dominating the cross-section.
pub fn winsorize_std(xs : Array[Double], k : Double) -> Array[Double] {
  let m = mean(xs)
  let sd = sample_std(xs)
  let lo = m - k * sd
  let hi = m + k * sd
  let out = Array::make(xs.length(), 0.0)
  for i in 0..<xs.length() {
    let v = xs[i]
    if v < lo {
      out[i] = lo
    }
    if v > hi {
      out[i] = hi
    }
    if v >= lo && v <= hi {
      out[i] = v
    }
  }
  out
}

/// Spread below this level is floating-point noise, not signal.
/// Without it, a column of identical values can still give a standard
/// deviation around 1e-17 and blow up every downstream division.
fn noise_floor() -> Double {
  0.000000000001
}

/// Cross-sectional z-score. A constant column maps to all zeros.
pub fn zscore(xs : Array[Double]) -> Array[Double] {
  let m = mean(xs)
  let sd = sample_std(xs)
  let out = Array::make(xs.length(), 0.0)
  if sd <= noise_floor() {
    out
  } else {
    for i in 0..<xs.length() {
      out[i] = (xs[i] - m) / sd
    }
    out
  }
}

/// Winsorize then z-score, the standard order used by the Python pipeline.
pub fn winsorize_zscore(xs : Array[Double], k : Double) -> Array[Double] {
  zscore(winsorize_std(xs, k))
}

/// Pearson correlation. Returns 0.0 when inputs are too short or constant.
pub fn pearson(xs : Array[Double], ys : Array[Double]) -> Double {
  let n = xs.length()
  if n != ys.length() {
    0.0
  } else if n < 2 {
    0.0
  } else {
    let mx = mean(xs)
    let my = mean(ys)
    let mut num = 0.0
    let mut dx2 = 0.0
    let mut dy2 = 0.0
    for i in 0..<n {
      let dx = xs[i] - mx
      let dy = ys[i] - my
      num = num + dx * dy
      dx2 = dx2 + dx * dx
      dy2 = dy2 + dy * dy
    }
    let den = (dx2 * dy2).sqrt()
    if den == 0.0 {
      0.0
    } else {
      num / den
    }
  }
}

/// Average ranks (1-based) with ties sharing the average rank.
/// Used for Spearman IC, which is far more robust than Pearson IC
/// on factor values with heavy tails.
pub fn rank_average(xs : Array[Double]) -> Array[Double] {
  let n = xs.length()
  let out = Array::make(n, 0.0)
  for i in 0..<n {
    let mut less = 0
    let mut equal = 0
    for j in 0..<n {
      if xs[j] < xs[i] {
        less = less + 1
      }
      if xs[j] == xs[i] {
        equal = equal + 1
      }
    }
    out[i] = less.to_double() + (equal - 1).to_double() / 2.0 + 1.0
  }
  out
}

/// Spearman rank correlation.
pub fn spearman(xs : Array[Double], ys : Array[Double]) -> Double {
  pearson(rank_average(xs), rank_average(ys))
}
