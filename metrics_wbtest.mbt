/// Metric tests. The point is not the formula, it is that a meaningless curve
/// cannot produce an impressive number: a flat line must never earn a high
/// Sharpe, and a curve that never draws down must not earn a huge Calmar.

let flat = [100.0, 100.0, 100.0, 100.0]

let rising = [100.0, 101.0, 102.0, 103.0]

let bumpy = [100.0, 110.0, 95.0, 105.0]

///|
test "step returns measure period to period change" {
  let r = step_returns(rising)
  assert_eq(r.length(), 3)
  assert_eq(r[0], 0.01)
}

///|
test "a single point has no returns" {
  assert_eq(step_returns([100.0]).length(), 0)
  assert_eq(step_returns([]).length(), 0)
}

///|
test "a flat curve has zero volatility" {
  assert_eq(annualized_vol(flat, 252), 0.0)
}

///|
test "a flat curve does not earn a sharpe ratio" {
  assert_eq(sharpe(flat, 252, 0.0), 0.0)
}

///|
test "volatility scales up with more periods per year" {
  let monthly = annualized_vol(bumpy, 12)
  let daily = annualized_vol(bumpy, 252)
  assert_eq(daily > monthly, true)
}

///|
test "a drawn down curve reports a positive drawdown" {
  assert_eq(max_drawdown(bumpy) > 0.0, true)
}

///|
test "a monotonic curve never draws down, so calmar stays zero not infinite" {
  assert_eq(max_drawdown(rising), 0.0)
  assert_eq(calmar(rising, 252), 0.0)
  assert_eq(calmar(flat, 252), 0.0)
}

///|
test "calmar is return divided by drawdown once there is a drawdown" {
  let c = calmar(bumpy, 252)
  let expected = annualized_return(bumpy, 252) / max_drawdown(bumpy)
  assert_eq(c, expected)
}

///|
test "win rate counts non negative periods" {
  let r = win_rate(bumpy)
  assert_eq(r, 2.0 / 3.0)
}

///|
test "a monotonically rising curve wins every period" {
  assert_eq(win_rate(rising), 1.0)
}

///|
test "worst period finds the deepest single loss" {
  let w = worst_period(bumpy)
  assert_eq(w < 0.0, true)
}

///|
test "the summary keeps a fixed field order" {
  let s = summarize(bumpy, 252)
  assert_eq(s.length(), 7)
  assert_eq(s[0] == total_return(bumpy), true)
  assert_eq(s[3] == max_drawdown(bumpy), true)
}
