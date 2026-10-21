/// Factor pipeline: turn raw price history and turnover into the day slices
/// the scoring layer consumes.
///
/// These helpers live in the library, not in the demo, so the end-to-end run
/// and the cross-check command drive exactly the same code.

///| Five-day momentum where the history allows it, one-day otherwise.
pub fn momentum_column(closes : Array[Array[Double]], day : Int, n : Int) -> Array[Double] {
  let out = Array::make(n, 0.0)
  let back = if day >= 5 {
    5
  } else if day > 0 {
    1
  } else {
    0
  }
  if back > 0 {
    for i in 0..<n {
      let past = closes[day - back][i]
      if past > 0.0 {
        out[i] = (closes[day][i] - past) / past
      }
    }
  }
  out
}

///| Realised volatility: spread of the most recent daily returns.
pub fn volatility_column(closes : Array[Array[Double]], day : Int, n : Int) -> Array[Double] {
  let out = Array::make(n, 0.0)
  if day >= 3 {
    let back = if day < 5 {
      day
    } else {
      5
    }
    for i in 0..<n {
      let window = Array::make(back, 0.0)
      for k in 0..<back {
        let prev = closes[day - back + k][i]
        if prev > 0.0 {
          window[k] = (closes[day - back + k + 1][i] - prev) / prev
        }
      }
      out[i] = sample_std(window)
    }
  }
  out
}

///| Forward return of the next trading day, used only to score signals.
pub fn forward_column(closes : Array[Array[Double]], day : Int, n : Int) -> Array[Double] {
  let out = Array::make(n, 0.0)
  if day + 1 < closes.length() {
    for i in 0..<n {
      let now = closes[day][i]
      if now > 0.0 {
        out[i] = (closes[day + 1][i] - now) / now
      }
    }
  }
  out
}

///| Build one day slice per row of closes.
pub fn build_days(
  codes : Array[String],
  closes : Array[Array[Double]],
  turnover : Array[Array[Double]]
) -> Array[DaySlice] {
  let n = codes.length()
  let out = Array::make(closes.length(), new_day(codes, [], [], [], []))
  for d in 0..<closes.length() {
    let turn = if d < turnover.length() {
      turnover[d]
    } else {
      []
    }
    out[d] = new_day(
      codes,
      momentum_column(closes, d, n),
      turn,
      volatility_column(closes, d, n),
      forward_column(closes, d, n),
    )
  }
  out
}

///| First `upto` day slices, used for expanding-window weight fitting.
pub fn take_days(days : Array[DaySlice], upto : Int) -> Array[DaySlice] {
  let out = Array::make(upto, days[0])
  for d in 0..<upto {
    out[d] = days[d]
  }
  out
}

///| Weights fitted on an expanding window ending just before `day`.
pub fn weights_before(days : Array[DaySlice], day : Int) -> Array[Double] {
  if day == 0 {
    [0.0, 0.0, 0.0]
  } else {
    normalize_weights(icir_weights(take_days(days, day), all_features()))
  }
}
