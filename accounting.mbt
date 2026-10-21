/// Daily accounting: mark to market, equity curve and the headline numbers
/// used to judge whether a configuration is worth trading.

///| Market value of held share counts at the given prices.
pub fn position_value(shares : Array[Int], prices : Array[Double]) -> Double {
  let mut total = 0.0
  for i in 0..<shares.length() {
    if i < prices.length() {
      total = total + shares[i].to_double() * prices[i]
    }
  }
  total
}

///| Total account value: cash plus market value of holdings.
pub fn equity(cash : Double, shares : Array[Int], prices : Array[Double]) -> Double {
  cash + position_value(shares, prices)
}

///| Largest peak-to-trough drop of an equity curve, as a positive fraction.
/// Returns 0.0 for an empty curve.
pub fn max_drawdown(series : Array[Double]) -> Double {
  let mut peak = 0.0
  let mut worst = 0.0
  for i in 0..<series.length() {
    if i == 0 {
      peak = series[i]
    }
    if series[i] > peak {
      peak = series[i]
    }
    if peak > 0.0 {
      let dd = (peak - series[i]) / peak
      if dd > worst {
        worst = dd
      }
    }
  }
  worst
}

///| Return over the whole curve, as a fraction.
pub fn total_return(series : Array[Double]) -> Double {
  if series.length() < 2 {
    0.0
  } else {
    let first = series[0]
    let last = series[series.length() - 1]
    if first <= 0.0 {
      0.0
    } else {
      (last - first) / first
    }
  }
}

///| Mean of a series. Used for reporting average IC-style diagnostics.
pub fn average_return(series : Array[Double]) -> Double {
  let n = series.length()
  if n == 0 {
    0.0
  } else {
    let mut total = 0.0
    for i in 0..<n {
      total = total + series[i]
    }
    total / n.to_double()
  }
}

///| Number of days the curve spent below the stop-out trigger level.
/// Zero is not automatically good; a curve that never moves is also flat.
pub fn days_in_drawdown(series : Array[Double]) -> Int {
  let mut peak = 0.0
  let mut count = 0
  for i in 0..<series.length() {
    if i == 0 {
      peak = series[i]
    }
    if series[i] > peak {
      peak = series[i]
    } else if series[i] < peak {
      count = count + 1
    }
  }
  count
}
