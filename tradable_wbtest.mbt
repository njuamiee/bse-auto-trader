/// Tradability tests. A strategy that assumes every signal can be executed
/// looks far better on paper than it performs, so these cases are the ones
/// that must not slip through.

///|
test "a name with no volume is suspended" {
  assert_eq(suspended(10.0, 0.0), true)
}

///|
test "a name with no usable price is suspended" {
  assert_eq(suspended(0.0, 1000.0), true)
}

///|
test "a normally trading name is not suspended" {
  assert_eq(suspended(10.0, 1000.0), false)
}

///|
test "limit price respects the 30 percent Beijing band" {
  assert_eq(limit_up_price(10.0, bse_limit()), 13.0)
  assert_eq(limit_down_price(10.0, bse_limit()), 7.0)
}

///|
test "a close on the upper band is detected" {
  assert_eq(at_limit_up(13.0, 10.0, 0.30), true)
}

///|
test "a close on the lower band is detected" {
  assert_eq(at_limit_down(7.0, 10.0, 0.30), true)
}

///|
test "the rounding of the exchange does not defeat the comparison" {
  // 10.3 -> the exchange quotes 13.00 exactly, but a different tick pattern
  // could produce 13.004 and that is still the limit
  assert_eq(at_limit_up(13.004, 10.0, 0.30), true)
}

///|
test "an ordinary move is not mistaken for a limit" {
  assert_eq(at_limit_up(12.0, 10.0, 0.30), false)
  assert_eq(at_limit_down(8.5, 10.0, 0.30), false)
}

///|
test "without a previous close no limit can be claimed" {
  assert_eq(at_limit_up(13.0, 0.0, 0.30), false)
  assert_eq(at_limit_down(7.0, 0.0, 0.30), false)
}

///|
test "a limit up name cannot be bought but can still be sold" {
  assert_eq(buyable(13.0, 10.0, 1000.0, 0.30), false)
  assert_eq(sellable(13.0, 10.0, 1000.0, 0.30), true)
}

///|
test "a limit down name cannot be sold but can still be bought" {
  assert_eq(sellable(7.0, 10.0, 1000.0, 0.30), false)
  assert_eq(buyable(7.0, 10.0, 1000.0, 0.30), true)
}

///|
test "a suspended name trades on neither side" {
  assert_eq(buyable(10.0, 9.0, 0.0, 0.30), false)
  assert_eq(sellable(10.0, 9.0, 0.0, 0.30), false)
}

///|
test "build_tradable blocks exactly the blocked names" {
  let flags = build_tradable([13.0, 9.5, 10.0], [10.0, 10.0, 9.0], [100.0, 100.0, 0.0], 0.30)
  assert_eq(flags, [false, true, false])
  assert_eq(blocked_count(flags), 2)
}
