/// Attribution tests. The useful property here is that contributions add up to
/// the total, and that the biggest damage is not always the biggest position.

let curve : Array[Double] = [100.0, 120.0, 90.0, 95.0, 130.0]

let recovered : Drawdown = worst_drawdown(curve)

let permanent : Array[Double] = [100.0, 120.0, 90.0, 95.0]

let unrecovered : Drawdown = worst_drawdown(permanent)

let codes : Array[String] = ["BJ1", "BJ2", "BJ3"]

// BJ3 is small but collapses; BJ1 is large and barely moves
let weights : Array[Double] = [0.80, 0.15, 0.05]

let rets : Array[Double] = [-0.01, -0.20, -0.60]

///|
test "the drawdown series tracks the running peak" {
  let dd = drawdown_series(curve)
  assert_eq(dd[1], 0.0)
  assert_eq(dd[2] > 0.0, true)
}

///|
test "the worst episode is located correctly" {
  assert_eq(peak_day_of(recovered), 1)
  assert_eq(trough_day_of(recovered), 2)
}

///|
test "its depth matches the headline maximum drawdown" {
  assert_eq(depth_of(recovered), max_drawdown(curve))
}

///|
test "a recovery back above the old peak is dated" {
  assert_eq(recovery_day_of(recovered), 4)
}

///|
test "an unrecovered curve reports no recovery day" {
  assert_eq(recovery_day_of(unrecovered), -1)
}

///|
test "an empty curve reports an empty episode" {
  let d : Drawdown = worst_drawdown([])
  assert_eq(depth_of(d), 0.0)
  assert_eq(recovery_day_of(d), -1)
}

///|
test "contributions are weight times return" {
  let c = contributions(weights, rets)
  assert_eq(c.length(), 3)
  assert_eq(c[0] < 0.0, true)
}

///|
test "the total is explained by the sum of contributions" {
  let total = explained_total(weights, rets)
  let manual = 0.80 * -0.01 + 0.15 * -0.20 + 0.05 * -0.60
  assert_eq(total, manual)
}

///|
test "the smallest position can do the most damage" {
  assert_eq(worst_contributor(codes, weights, rets), "BJ3")
}

///|
test "top contributors are ordered by effect, not by size" {
  let winners = top_contributors(codes, weights, rets, 3)
  assert_eq(winners, ["BJ1", "BJ2", "BJ3"])
}

///|
test "asking for more names than exist is not an error" {
  assert_eq(top_contributors(codes, weights, rets, 10).length(), 3)
}

///|
test "attribution over an empty book returns nothing" {
  assert_eq(worst_contributor([], [], []), "")
}
