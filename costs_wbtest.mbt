/// Cost model tests. These guard the two mistakes that flatter a backtest:
/// forgetting the stamp duty on sells, and letting the commission floor vanish
/// on small trades.

let cfg : CostConfig = new_cost_config(
  commission_rate=0.001,
  min_commission=5.0,
  stamp_duty_rate=0.0005,
  transfer_rate=0.0,
  slippage_bps=10.0,
)

///|
test "commission is proportional above the floor" {
  assert_eq(commission(cfg, 100000.0), 100.0)
}

///|
test "commission never falls below the floor" {
  assert_eq(commission(cfg, 100.0), 5.0)
}

///|
test "a zero size trade costs nothing" {
  assert_eq(commission(cfg, 0.0), 0.0)
  assert_eq(stamp_duty(cfg, 0.0), 0.0)
  assert_eq(transfer_fee(cfg, 0.0), 0.0)
}

///|
test "buying pays no stamp duty" {
  assert_eq(buy_fees(cfg, 100000.0), 100.0)
}

///|
test "selling pays stamp duty on top of commission" {
  assert_eq(sell_fees(cfg, 100000.0), 150.0)
}

///|
test "the same position costs more to close than to open" {
  assert_eq(sell_fees(cfg, 50000.0) > buy_fees(cfg, 50000.0), true)
}

///|
test "slippage makes buys dearer and sells cheaper" {
  assert_eq(fill_price(cfg, buy_side(), 10.0), 10.01)
  assert_eq(fill_price(cfg, sell_side(), 10.0), 9.99)
}

///|
test "a buy produces a negative cash flow including fees" {
  let flow = cash_out(cfg, 1000, 10.0)
  let expected = -(10.01 * 1000.0 + 10.01)
  assert_eq(flow, expected)
}

///|
test "a sell produces a positive cash flow net of fees" {
  let flow = cash_in(cfg, 1000, 10.0)
  let gross = 9.99 * 1000.0
  // commission 9.99 is above the 5.0 floor, plus 0.05% stamp duty
  let expected = gross - (9.99 + 4.995)
  assert_eq(flow, expected)
}

///|
test "the Beijing defaults charge stamp duty on sells only" {
  let c = bse_default_costs()
  assert_eq(stamp_duty(c, 100000.0), 50.0)
  assert_eq(buy_fees(c, 100000.0), commission(c, 100000.0) + 1.0)
}
