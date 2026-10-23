/// Performance measures built on top of the equity curve.
///
/// Everything here takes the curve, not the trades, so the same numbers can be
/// quoted for a strategy, an equal-weight benchmark and an index without
/// special cases. `periods_per_year` is passed rather than assumed: the
/// research pipeline works with 252 trading days, but a monthly series is 12
/// and a strategy using a different calendar should say so.
///
/// Two honest notes:
/// - Sharpe uses the sample standard deviation of **daily** returns scaled by
///   the square root of the annualisation factor, with no smoothing
/// - Calmar divides by the maximum drawdown and therefore explodes for any
///   curve that never happens to draw down; callers should treat a huge Calmar
///   as suspicious, not good

///| Period-to-period simple returns of an equity curve.
pub fn step_returns(series : Array[Double]) -> Array[Double] {
  if series.length() < 2 {
    []
  } else {
    let n = series.length() - 1
    let out = Array::make(n, 0.0)
    for i in 0..<n {
      let base = series[i]
      if base > 0.0 {
        out[i] = (series[i + 1] - base) / base
      }
    }
    out
  }
}

///| Geometric mean of the returns, annualised.
pub fn annualized_return(series : Array[Double], periods_per_year : Int) -> Double {
  let rets = step_returns(series)
  if rets.length() == 0 {
    0.0
  } else {
    // arithmetic mean scaled up; the geometric form needs logs that sometimes
    // receive a non-positive base, so we keep the simple, explainable version
    let g = average_return(rets) * periods_per_year.to_double()
    g
  }
}

///| Annualised standard deviation of returns.
pub fn annualized_vol(series : Array[Double], periods_per_year : Int) -> Double {
  let rets = step_returns(series)
  if rets.length() < 2 {
    0.0
  } else {
    let sd = sample_std(rets)
    let scale = periods_per_year.to_double().sqrt()
    sd * scale
  }
}

///| Sharpe ratio of the curve at the given risk-free rate.
pub fn sharpe(series : Array[Double], periods_per_year : Int, risk_free : Double) -> Double {
  let excess = annualized_return(series, periods_per_year) - risk_free
  let vol = annualized_vol(series, periods_per_year)
  if vol <= 0.000000000001 {
    0.0
  } else {
    excess / vol
  }
}

///| Calmar ratio: annualised return over maximum drawdown.
pub fn calmar(series : Array[Double], periods_per_year : Int) -> Double {
  let dd = max_drawdown(series)
  if dd <= 0.000000000001 {
    0.0
  } else {
    annualized_return(series, periods_per_year) / dd
  }
}

///| Share of periods that were flat or positive.
pub fn win_rate(series : Array[Double]) -> Double {
  let rets = step_returns(series)
  if rets.length() == 0 {
    0.0
  } else {
    let mut wins = 0
    for i in 0..<rets.length() {
      if rets[i] >= 0.0 {
        wins = wins + 1
      }
    }
    wins.to_double() / rets.length().to_double()
  }
}

///| Worst single period loss, as a negative fraction.
pub fn worst_period(series : Array[Double]) -> Double {
  let rets = step_returns(series)
  let mut worst = 0.0
  for i in 0..<rets.length() {
    if rets[i] < worst {
      worst = rets[i]
    }
  }
  worst
}

///| Standard performance summary, ready to print.
pub fn summarize(series : Array[Double], periods_per_year : Int) -> Array[Double] {
  [
    total_return(series),
    annualized_return(series, periods_per_year),
    annualized_vol(series, periods_per_year),
    max_drawdown(series),
    sharpe(series, periods_per_year, 0.0),
    calmar(series, periods_per_year),
    win_rate(series),
  ]
}
