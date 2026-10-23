/// Benchmarks, computed from the same inputs as the strategy.
///
/// A return quoted without something to compare it to is not a result. Every
/// number here is computed inside the engine from the same price matrix the
/// strategy sees, so a comparison cannot drift because two sides used two
/// different copies of the data.
///
/// The default benchmark is a daily-rebalanced equal-weight basket of every
/// instrument in the pool: it asks nothing about skill, so beating it says
/// something, and losing to it says something else.

///| Equal-weight basket rebalanced every day, starting at `initial`.
pub fn equal_weight_equity(closes : Array[Array[Double]], initial : Double) -> Array[Double] {
  let n = closes.length()
  let out = Array::make(n, initial)
  let mut d = 1
  while d < n {
    let prev = closes[d - 1]
    let cur = closes[d]
    let mut sum = 0.0
    let mut cnt = 0
    let mut i = 0
    while i < cur.length() {
      if i < prev.length() && prev[i] > 0.0 && cur[i] > 0.0 {
        sum = sum + (cur[i] - prev[i]) / prev[i]
        cnt = cnt + 1
      }
      i = i + 1
    }
    let r = if cnt > 0 {
      sum / cnt.to_double()
    } else {
      0.0
    }
    out[d] = out[d - 1] * (1.0 + r)
    d = d + 1
  }
  out
}

///| Per-period active return of a strategy against its benchmark.
pub fn active_returns(strategy : Array[Double], benchmark : Array[Double]) -> Array[Double] {
  let s = step_returns(strategy)
  let b = step_returns(benchmark)
  let m = if s.length() < b.length() {
    s.length()
  } else {
    b.length()
  }
  let out = Array::make(m, 0.0)
  for i in 0..<m {
    out[i] = s[i] - b[i]
  }
  out
}

///| Mean active return per period.
pub fn average_active(strategy : Array[Double], benchmark : Array[Double]) -> Double {
  average_return(active_returns(strategy, benchmark))
}

///| Tracking error: how far the strategy wanders from its benchmark.
pub fn tracking_error(strategy : Array[Double], benchmark : Array[Double]) -> Double {
  let a = active_returns(strategy, benchmark)
  if a.length() < 2 {
    0.0
  } else {
    sample_std(a)
  }
}

///| Information ratio, annualised like Sharpe.
pub fn information_ratio(
  strategy : Array[Double],
  benchmark : Array[Double],
  periods_per_year : Int
) -> Double {
  let te = tracking_error(strategy, benchmark)
  if te <= 0.000000000001 {
    0.0
  } else {
    let scale = periods_per_year.to_double().sqrt()
    average_active(strategy, benchmark) / te * scale
  }
}

///| How many periods the strategy beat its benchmark.
pub fn win_rate_against(strategy : Array[Double], benchmark : Array[Double]) -> Double {
  let a = active_returns(strategy, benchmark)
  if a.length() == 0 {
    0.0
  } else {
    let mut wins = 0
    for i in 0..<a.length() {
      if a[i] > 0.0 {
        wins = wins + 1
      }
    }
    wins.to_double() / a.length().to_double()
  }
}
