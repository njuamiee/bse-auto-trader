/// Where a result actually came from.
///
/// Reporting one number answers nothing useful. Two decompositions live here,
/// because "it went down" and "it went down because these three names" lead to
/// completely different decisions.
///
/// First, the worst episode of the curve: when it started, how deep it got,
/// and whether it has recovered. A drawdown that never recovers is a very
/// different thing from one that recovered in a week.
///
/// Second, per-position contribution over a period. Contribution is weight
/// times return, so a small position that collapsed can matter more than a
/// large one that barely moved, which is exactly the mistake the naive reading
/// of a holdings list invites.

///| The deepest peak-to-trough episode of a curve.
pub struct Drawdown {
  peak_day : Int
  trough_day : Int
  depth : Double
  recovery_day : Int
}

///|
pub fn new_drawdown(
  peak_day~ : Int,
  trough_day~ : Int,
  depth~ : Double,
  recovery_day~ : Int
) -> Drawdown {
  {
    peak_day: peak_day,
    trough_day: trough_day,
    depth: depth,
    recovery_day: recovery_day,
  }
}

///|
pub fn peak_day_of(d : Drawdown) -> Int {
  d.peak_day
}

///|
pub fn trough_day_of(d : Drawdown) -> Int {
  d.trough_day
}

///|
pub fn depth_of(d : Drawdown) -> Double {
  d.depth
}

///| Day the curve climbed back to its old peak, or -1 if it never did.
pub fn recovery_day_of(d : Drawdown) -> Int {
  d.recovery_day
}

///| Drawdown at each point of the curve, as a positive fraction.
pub fn drawdown_series(series : Array[Double]) -> Array[Double] {
  let out = Array::make(series.length(), 0.0)
  let mut peak = 0.0
  for i in 0..<series.length() {
    if series[i] > peak {
      peak = series[i]
    }
    if peak > 0.0 {
      out[i] = (peak - series[i]) / peak
    }
  }
  out
}

///| Locate the worst episode and whether it was ever recovered.
pub fn worst_drawdown(series : Array[Double]) -> Drawdown {
  if series.length() == 0 {
    new_drawdown(peak_day=0, trough_day=0, depth=0.0, recovery_day=-1)
  } else {
    let mut peak = series[0]
    let mut peak_day = 0
    let mut best_p = 0
    let mut best_t = 0
    let mut best_depth = 0.0
    let mut i = 0
    while i < series.length() {
      if series[i] > peak {
        peak = series[i]
        peak_day = i
      }
      if peak > 0.0 {
        let dd = (peak - series[i]) / peak
        if dd > best_depth {
          best_depth = dd
          best_t = i
          best_p = peak_day
        }
      }
      i = i + 1
    }
    let target = series[best_p]
    let mut rec = -1
    let mut j = best_t
    while j < series.length() {
      if rec < 0 && series[j] >= target {
        rec = j
      }
      j = j + 1
    }
    new_drawdown(peak_day=best_p, trough_day=best_t, depth=best_depth, recovery_day=rec)
  }
}

///| Each position's contribution over the period: weight times its return.
pub fn contributions(weights : Array[Double], rets : Array[Double]) -> Array[Double] {
  let n = weights.length()
  let out = Array::make(n, 0.0)
  for i in 0..<n {
    let r = if i < rets.length() {
      rets[i]
    } else {
      0.0
    }
    out[i] = weights[i] * r
  }
  out
}

///| Codes with the largest positive contribution, best first.
pub fn top_contributors(
  codes : Array[String],
  weights : Array[Double],
  rets : Array[Double],
  n : Int
) -> Array[String] {
  let c = contributions(weights, rets)
  let order = argsort_desc(c, c.length())
  let take = if n < order.length() {
    n
  } else {
    order.length()
  }
  let out = Array::make(take, "")
  for i in 0..<take {
    out[i] = codes[order[i]]
  }
  out
}

///| The single name that did the most damage in the period.
pub fn worst_contributor(
  codes : Array[String],
  weights : Array[Double],
  rets : Array[Double]
) -> String {
  let c = contributions(weights, rets)
  let order = argsort_desc(c, c.length())
  if order.length() == 0 {
    ""
  } else {
    codes[order[order.length() - 1]]
  }
}

///| Sum of contributions, which should match the period return of the book.
pub fn explained_total(weights : Array[Double], rets : Array[Double]) -> Double {
  let mut total = 0.0
  for i in 0..<weights.length() {
    if i < rets.length() {
      total = total + weights[i] * rets[i]
    }
  }
  total
}
