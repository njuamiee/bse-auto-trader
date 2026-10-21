/// Weighting layer: per-day information coefficient (IC) and its
/// risk-adjusted form ICIR, used to blend multiple factors into one score.

/// A factor the engine knows how to read from a day slice.
pub enum Feature {
  Momentum
  Turnover
  Volatility
}

/// One trading day's cross-section: parallel arrays, one entry per stock.
/// All arrays must have the same length as `codes`.
pub struct DaySlice {
  codes : Array[String]
  momentum : Array[Double]
  turnover : Array[Double]
  volatility : Array[Double]
  /// Forward return used only for scoring the signal, never for trading.
  forward : Array[Double]
}

/// Build a day slice. Struct types are read-only outside their own package,
/// so this constructor is the supported way to create one.
pub fn new_day(
  codes : Array[String],
  momentum : Array[Double],
  turnover : Array[Double],
  volatility : Array[Double],
  forward : Array[Double]
) -> DaySlice {
  { codes: codes, momentum: momentum, turnover: turnover, volatility: volatility, forward: forward }
}

/// The three features in their canonical order.
/// Struct and enum values are read-only outside this package, so callers use
/// this helper to build a feature set.
pub fn all_features() -> Array[Feature] {
  [Momentum, Turnover, Volatility]
}

/// Read one feature column out of a day slice.
pub fn column(d : DaySlice, f : Feature) -> Array[Double] {
  match f {
    Momentum => d.momentum
    Turnover => d.turnover
    Volatility => d.volatility
  }
}

/// Rank IC of a single feature on a single day.
pub fn ic(d : DaySlice, f : Feature) -> Double {
  spearman(column(d, f), d.forward)
}

/// Rank IC of one feature across every day given.
pub fn ic_vector(days : Array[DaySlice], f : Feature) -> Array[Double] {
  let out = Array::make(days.length(), 0.0)
  for i in 0..<days.length() {
    out[i] = ic(days[i], f)
  }
  out
}

/// ICIR = mean(IC) / std(IC). Higher means a steadier signal.
/// Spread below the noise floor returns 0 instead of a huge fake ratio.
pub fn icir(ics : Array[Double]) -> Double {
  let sd = sample_std(ics)
  if sd <= 0.000000000001 {
    0.0
  } else {
    mean(ics) / sd
  }
}

/// Raw ICIR per feature, in the same order as `fs`.
pub fn icir_weights(days : Array[DaySlice], fs : Array[Feature]) -> Array[Double] {
  let out = Array::make(fs.length(), 0.0)
  for i in 0..<fs.length() {
    out[i] = icir(ic_vector(days, fs[i]))
  }
  out
}

/// Rescale weights so the absolute amounts add up to 1.
/// Negative-weight features keep their sign (they act as reverse signals).
pub fn normalize_weights(ws : Array[Double]) -> Array[Double] {
  let mut total = 0.0
  for i in 0..<ws.length() {
    total = total + abs(ws[i])
  }
  let out = Array::make(ws.length(), 0.0)
  if total == 0.0 {
    out
  } else {
    for i in 0..<ws.length() {
      out[i] = ws[i] / total
    }
    out
  }
}

/// Blend several features into one composite score per stock.
/// Each column is winsorized and z-scored before blending.
pub fn composite(
  d : DaySlice,
  fs : Array[Feature],
  weights : Array[Double],
  k : Double
) -> Array[Double] {
  let n = d.codes.length()
  let out = Array::make(n, 0.0)
  for col in 0..<fs.length() {
    let z = winsorize_zscore(column(d, fs[col]), k)
    for i in 0..<n {
      out[i] = out[i] + weights[col] * z[i]
    }
  }
  out
}
