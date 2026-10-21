/// Unit tests for the market, risk, portfolio and accounting modules.
/// Run everything with `moon test`.

///|
fn close_to(a : Double, b : Double, tol : Double) -> Bool {
  let d = a - b
  if d < 0.0 {
    0.0 - d <= tol
  } else {
    d <= tol
  }
}

///|
fn eps() -> Double {
  0.000000000001
}

///| Shared configuration used by the risk tests.
fn test_config() -> RiskConfig {
  new_config(0.08, 0.15, 5, 3, 0.45, 6, 0.25)
}

test "stop loss fires below the threshold" {
  let cfg = test_config()
  assert_eq(stop_loss_triggered(10.0, 9.1, cfg), true)
  assert_eq(stop_loss_triggered(10.0, 9.5, cfg), false)
  assert_eq(stop_loss_triggered(10.0, 10.0, cfg), false)
}

test "a zero entry price never triggers a stop" {
  assert_eq(stop_loss_triggered(0.0, 0.0, test_config()), false)
}

test "account drawdown fires at the boundary" {
  let cfg = test_config()
  assert_eq(account_drawdown_triggered(850.0, 1000.0, cfg), true)
  assert_eq(account_drawdown_triggered(860.0, 1000.0, cfg), false)
  assert_eq(account_drawdown_triggered(1000.0, 1000.0, cfg), false)
}

test "breadth switch compares against the floor" {
  let cfg = test_config()
  assert_eq(breadth_ok(0.45, cfg), true)
  assert_eq(breadth_ok(0.44, cfg), false)
}

test "regime caps the number of holdings" {
  let cfg = test_config()
  assert_eq(position_cap(regime(0), cfg), 6)
  assert_eq(position_cap(regime(1), cfg), 4)
  assert_eq(position_cap(regime(2), cfg), 2)
}

test "a drawdown breach pauses new buying" {
  let cfg = test_config()
  let hit = update_state(new_state(1000.0), 3, 800.0, 0.20, cfg)
  assert_eq(new_buys_allowed(hit, 3), false)
  assert_eq(new_buys_allowed(hit, 7), false)
  assert_eq(new_buys_allowed(hit, 8), true)
}

test "buying stays blocked while the account is still deep underwater" {
  let cfg = test_config()
  let mut s = update_state(new_state(1000.0), 0, 800.0, 0.20, cfg)
  s = update_state(s, 1, 810.0, 0.20, cfg)
  s = update_state(s, 2, 820.0, 0.20, cfg)
  s = update_state(s, 3, 830.0, 0.20, cfg)
  assert_eq(new_buys_allowed(s, 4), false)
}

test "once equity recovers, healthy breadth lifts the pause early" {
  let cfg = test_config()
  let mut s = update_state(new_state(1000.0), 0, 800.0, 0.20, cfg)
  s = update_state(s, 1, 900.0, 0.60, cfg)
  s = update_state(s, 2, 910.0, 0.60, cfg)
  s = update_state(s, 3, 920.0, 0.60, cfg)
  assert_eq(new_buys_allowed(s, 4), true)
}

test "bad breadth during the pause resets the counter" {
  let cfg = new_config(0.08, 0.15, 10, 3, 0.45, 6, 0.25)
  let mut s = update_state(new_state(1000.0), 0, 800.0, 0.20, cfg)
  s = update_state(s, 1, 900.0, 0.60, cfg)
  s = update_state(s, 2, 905.0, 0.20, cfg)
  s = update_state(s, 3, 910.0, 0.60, cfg)
  s = update_state(s, 4, 915.0, 0.60, cfg)
  assert_eq(new_buys_allowed(s, 5), false)
  let mut clean = update_state(new_state(1000.0), 0, 800.0, 0.20, cfg)
  clean = update_state(clean, 1, 900.0, 0.60, cfg)
  clean = update_state(clean, 2, 910.0, 0.60, cfg)
  clean = update_state(clean, 3, 920.0, 0.60, cfg)
  assert_eq(new_buys_allowed(clean, 4), true)
}

test "an untouched account never pauses" {
  let cfg = test_config()
  let mut s = new_state(1000.0)
  for d in 0..<10 {
    s = update_state(s, d, 1000.0 + d.to_double(), 0.5, cfg)
  }
  assert_eq(new_buys_allowed(s, 10), true)
}

test "position size rounds down to whole lots" {
  assert_eq(shares_to_buy(100000.0, 1000000.0, 10.0, 0.25, 100), 10000)
  assert_eq(shares_to_buy(5000.0, 1000000.0, 33.0, 0.25, 100), 100)
  assert_eq(shares_to_buy(1000.0, 1000000.0, 12.0, 0.25, 100), 0)
}

test "the single-name weight cap overrides the budget" {
  assert_eq(shares_to_buy(500000.0, 100000.0, 10.0, 0.10, 100), 1000)
}

test "degenerate inputs produce no order" {
  assert_eq(shares_to_buy(1000.0, 1000.0, 0.0, 0.25, 100), 0)
  assert_eq(shares_to_buy(-1.0, 1000.0, 10.0, 0.25, 100), 0)
  assert_eq(shares_to_buy(1000.0, 1000.0, 10.0, 0.25, 0), 0)
}

test "cash spent matches the shares bought" {
  assert_eq(close_to(cash_after(10000.0, 300, 20.0), 4000.0, eps()), true)
}

test "an order line round-trips through csv" {
  let line = render_csv(new_order("BJ430047", buy_side(), 500, 12.35))
  assert_eq(line, "BJ430047,BUY,500,12.35")
}

test "the instruction file carries a header row" {
  let text = render_order_file([
    new_order("BJ430047", buy_side(), 500, 12.0),
    new_order("BJ831726", sell_side(), 300, 20.0),
  ])
  let nonzero = text.length() > 0
  assert_eq(nonzero, true)
  assert_eq(render_csv(new_order("BJ831726", sell_side(), 300, 20.0)), "BJ831726,SELL,300,20")
}

test "committed cash counts buys only" {
  let orders = [
    new_order("a", buy_side(), 100, 10.0),
    new_order("b", sell_side(), 100, 10.0),
  ]
  assert_eq(close_to(committed_cash(orders), 1000.0, eps()), true)
}

test "position value multiplies shares by price" {
  assert_eq(close_to(position_value([100, 200], [10.0, 20.0]), 5000.0, eps()), true)
}

test "ragged price arrays do not panic" {
  assert_eq(close_to(position_value([100, 200], [10.0]), 1000.0, eps()), true)
}

test "equity is cash plus holdings" {
  assert_eq(close_to(equity(500.0, [100], [10.0]), 1500.0, eps()), true)
}

test "max drawdown is measured from the peak" {
  assert_eq(close_to(max_drawdown([100.0, 120.0, 90.0, 100.0]), 0.25, eps()), true)
  assert_eq(max_drawdown([100.0, 110.0, 120.0]), 0.0)
  assert_eq(max_drawdown([]), 0.0)
}

test "total return reads the two ends" {
  assert_eq(close_to(total_return([100.0, 110.0]), 0.1, eps()), true)
  assert_eq(total_return([100.0]), 0.0)
  assert_eq(total_return([]), 0.0)
}

test "days underwater counts every day below the peak" {
  assert_eq(days_in_drawdown([100.0, 110.0, 105.0, 120.0]), 1)
  assert_eq(days_in_drawdown([100.0, 110.0, 120.0]), 0)
}

test "price lookup finds the right slot" {
  let d = new_market_day(["a", "b"], [1.0, 2.0], [1.5, 2.5], [true, false], 0.5)
  assert_eq(close_to(price_of(d.codes, d.close_prices, "b"), 2.5, eps()), true)
  assert_eq(can_trade(d, "a"), true)
  assert_eq(can_trade(d, "b"), false)
}
