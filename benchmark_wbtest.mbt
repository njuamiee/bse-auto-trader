/// Benchmark tests. Note what is deliberately absent: no claim that beating
/// this basket means a strategy is good. Beating a daily-rebalanced basket is
/// a low bar, and a loss to it is a strong signal.

/// A tolerance helper, because 100 * 1.1 is 110.00000000000001 and that is
/// not a bug in the engine.

fn close(a : Double, b : Double) -> Bool {
  let d = if a >= b {
    a - b
  } else {
    b - a
  }
  d < 0.000001
}

let closes : Array[Array[Double]] = [
  [10.0, 20.0, 30.0],
  [11.0, 19.0, 30.0],
  [11.0, 21.0, 33.0],
]

let bench : Array[Double] = equal_weight_equity(closes, 1000000.0)

///|
test "the benchmark starts at the initial capital" {
  assert_eq(bench[0], 1000000.0)
}

///|
test "the benchmark has one point per day" {
  assert_eq(bench.length(), 3)
}

///|
test "an unchanged basket leaves capital unchanged" {
  assert_eq(equal_weight_equity([[10.0], [10.0]], 500.0), [500.0, 500.0])
}

///|
test "a basket that rises lifts the benchmark" {
  assert_eq(bench[2] > bench[1], true)
}

///|
test "missing prices are excluded rather than treated as zero" {
  let gappy : Array[Array[Double]] = [[10.0, 20.0], [11.0, 0.0]]
  let eq = equal_weight_equity(gappy, 100.0)
  // only the surviving name contributes its 10 percent gain; had the missing
  // cell been treated as a 100 percent loss the basket would have halved
  assert_eq(close(eq[1], 110.0), true)
}

///|
test "a strategy matching the benchmark has zero active return" {
  assert_eq(average_active(bench, bench), 0.0)
}

///|
test "tracking error of itself is zero" {
  assert_eq(tracking_error(bench, bench), 0.0)
}

///|
test "the information ratio stays finite without dispersion" {
  assert_eq(information_ratio(bench, bench, 252), 0.0)
}

///|
test "a strategy ahead of a falling basket wins every period" {
  let falling : Array[Double] = [100.0, 98.0, 96.0]
  let better = [100.0, 110.0, 115.0]
  assert_eq(win_rate_against(better, falling), 1.0)
}

///|
test "outrunning the basket overall is not the same as every period" {
  // 'better' ends higher than 'bench' yet loses one of the two periods
  let better = [100.0, 110.0, 115.0]
  assert_eq(win_rate_against(better, bench), 0.5)
  // compare returns, not levels: the basket starts at one million
  assert_eq(total_return(better) > total_return(bench), true)
}

///|
test "a strategy behind a rising basket never wins" {
  let rising : Array[Double] = [100.0, 102.0, 104.0]
  let worse = [100.0, 90.0, 85.0]
  assert_eq(win_rate_against(worse, rising), 0.0)
}

///|
test "active returns are aligned period by period" {
  let better = [100.0, 110.0, 115.0]
  let a = active_returns(better, bench)
  assert_eq(a.length(), 2)
  assert_eq(a[0] > 0.0, true)
}
