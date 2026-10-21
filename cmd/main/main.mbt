/// End-to-end simulation for the BSE auto-trader engine.
///
/// Factor building, ICIR weighting, selection, risk rules, order generation
/// and daily accounting all run here in MoonBit: no Python, no model files,
/// no external data.
///
/// The 12 days of prices are synthetic. They exist to prove that the whole
/// chain completes and reproduces from a single command. They are not a claim
/// about real returns. Run it with `moon run cmd/main`.

struct Holding {
  code : String
  shares : Int
  entry_price : Double
  entry_day : Int
}

/// Cash plus holdings, threaded through the day loop.
struct Book {
  cash : Double
  holdings : Array[Holding]
}

///|
fn universe() -> Array[String] {
  ["BJ430047", "BJ831726", "BJ873223", "BJ836260", "BJ833819", "BJ873693"]
}

///|
fn open_prices() -> Array[Array[Double]] {
  [
    [10.0, 20.0, 15.0, 8.0, 12.0, 25.0],
    [10.3, 19.6, 15.4, 8.5, 11.9, 25.6],
    [10.0, 20.3, 15.1, 9.0, 11.6, 26.2],
    [10.6, 20.1, 14.9, 9.5, 11.3, 25.6],
    [11.0, 19.4, 14.0, 9.1, 11.9, 24.9],
    [10.1, 18.5, 13.4, 8.6, 12.5, 23.7],
    [9.5, 18.1, 13.1, 8.3, 13.0, 23.0],
    [10.0, 18.9, 13.7, 8.7, 12.5, 23.5],
    [10.5, 19.3, 14.2, 9.1, 12.1, 24.1],
    [10.8, 20.0, 14.7, 9.6, 11.8, 24.9],
    [10.5, 20.5, 15.2, 10.0, 11.7, 25.4],
    [11.0, 20.2, 15.7, 10.5, 12.0, 24.8],
  ]
}

///|
fn close_prices() -> Array[Array[Double]] {
  [
    [10.2, 19.8, 15.3, 8.4, 11.8, 25.5],
    [10.1, 20.2, 15.0, 8.9, 11.5, 26.1],
    [10.5, 20.0, 14.8, 9.4, 11.2, 25.8],
    [10.9, 19.5, 14.2, 9.2, 11.8, 25.0],
    [10.2, 18.6, 13.5, 8.7, 12.4, 23.8],
    [9.6, 18.0, 13.0, 8.2, 12.9, 22.9],
    [9.9, 18.8, 13.6, 8.6, 12.6, 23.4],
    [10.4, 19.2, 14.1, 9.0, 12.2, 24.0],
    [10.7, 19.9, 14.6, 9.5, 11.9, 24.8],
    [10.6, 20.4, 15.1, 9.9, 11.6, 25.3],
    [10.9, 20.1, 15.6, 10.4, 11.9, 24.9],
    [11.2, 20.8, 16.0, 10.8, 12.2, 25.5],
  ]
}

///| Synthetic turnover columns. Real turnover needs share volume, which this
///| price-only dataset does not carry, so these are labelled placeholders.
fn turnover_columns() -> Array[Array[Double]] {
  [
    [0.012, 0.008, 0.021, 0.005, 0.030, 0.014],
    [0.020, 0.011, 0.018, 0.004, 0.026, 0.017],
    [0.028, 0.009, 0.014, 0.007, 0.024, 0.019],
    [0.010, 0.019, 0.013, 0.006, 0.022, 0.011],
    [0.015, 0.024, 0.010, 0.012, 0.018, 0.026],
    [0.022, 0.030, 0.009, 0.016, 0.012, 0.032],
    [0.018, 0.026, 0.012, 0.014, 0.010, 0.028],
    [0.013, 0.021, 0.016, 0.009, 0.014, 0.023],
    [0.011, 0.017, 0.020, 0.007, 0.016, 0.018],
    [0.014, 0.013, 0.024, 0.010, 0.019, 0.015],
    [0.017, 0.015, 0.022, 0.013, 0.021, 0.012],
    [0.019, 0.012, 0.019, 0.015, 0.023, 0.014],
  ]
}

///|
fn breadth_series() -> Array[Double] {
  [0.66, 0.55, 0.48, 0.52, 0.30, 0.22, 0.62, 0.68, 0.72, 0.60, 0.58, 0.70]
}

///|
fn index_of(codes : Array[String], code : String) -> Int {
  let mut found = -1
  for i in 0..<codes.length() {
    if codes[i] == code {
      found = i
    }
  }
  found
}

///|
fn holding_index(hs : Array[Holding], code : String) -> Int {
  let mut found = -1
  for i in 0..<hs.length() {
    if hs[i].code == code {
      found = i
    }
  }
  found
}

///|
fn drop_code(hs : Array[Holding], code : String) -> Array[Holding] {
  let n = hs.length()
  let mut kept = 0
  for i in 0..<n {
    if hs[i].code != code {
      kept = kept + 1
    }
  }
  if kept == n {
    hs
  } else {
    let out = Array::make(kept, hs[0])
    let mut j = 0
    for i in 0..<n {
      if hs[i].code != code {
        out[j] = hs[i]
        j = j + 1
      }
    }
    out
  }
}

///|
fn add_holding(hs : Array[Holding], h : Holding) -> Array[Holding] {
  let n = hs.length()
  let out = Array::make(n + 1, h)
  for i in 0..<n {
    out[i] = hs[i]
  }
  out
}

///|
fn shares_of(hs : Array[Holding], codes : Array[String]) -> Array[Int] {
  let out = Array::make(codes.length(), 0)
  for i in 0..<codes.length() {
    let idx = holding_index(hs, codes[i])
    if idx >= 0 {
      out[i] = hs[idx].shares
    }
  }
  out
}

///|
fn build_days() -> Array[@factors.DaySlice] {
  @factors.build_days(universe(), close_prices(), turnover_columns())
}

///| Fill orders placed the previous evening at today's opening price.
fn settle(
  book : Book,
  orders : Array[@factors.Order],
  opens : Array[Double],
  codes : Array[String],
  day : Int
) -> Book {
  let mut cash = book.cash
  let mut hs = book.holdings
  for i in 0..<orders.length() {
    let o = orders[i]
    let idx = index_of(codes, o.code)
    if idx >= 0 {
      let px = opens[idx]
      if px > 0.0 {
        match o.side {
          Buy => {
            if o.shares > 0 && cash >= o.shares.to_double() * px {
              cash = cash - o.shares.to_double() * px
              hs = add_holding(
                hs,
                { code: o.code, shares: o.shares, entry_price: px, entry_day: day },
              )
            }
          }
          Sell => {
            if holding_index(hs, o.code) >= 0 {
              cash = cash + o.shares.to_double() * px
              hs = drop_code(hs, o.code)
            }
          }
        }
      }
    }
  }
  { cash: cash, holdings: hs }
}

///| Whether a holding should be closed at the next open.
fn should_exit(
  h : Holding,
  targets : Array[String],
  closes : Array[Double],
  codes : Array[String],
  day : Int,
  cfg : @factors.RiskConfig,
  holding_days : Int
) -> Bool {
  let idx = index_of(codes, h.code)
  let last = if idx >= 0 {
    closes[idx]
  } else {
    h.entry_price
  }
  let mut wanted = false
  for t in 0..<targets.length() {
    if targets[t] == h.code {
      wanted = true
    }
  }
  let stopped = @factors.stop_loss_triggered(h.entry_price, last, cfg)
  let matured = day - h.entry_day >= holding_days
  stopped || matured || wanted == false
}

///|
fn plan_sells(
  hs : Array[Holding],
  targets : Array[String],
  closes : Array[Double],
  codes : Array[String],
  day : Int,
  cfg : @factors.RiskConfig,
  holding_days : Int
) -> Array[@factors.Order] {
  let mut count = 0
  for i in 0..<hs.length() {
    if should_exit(hs[i], targets, closes, codes, day, cfg, holding_days) {
      count = count + 1
    }
  }
  let out = Array::make(count, @factors.new_order("", @factors.sell_side(), 0, 0.0))
  let mut j = 0
  for i in 0..<hs.length() {
    if should_exit(hs[i], targets, closes, codes, day, cfg, holding_days) {
      let idx = index_of(codes, hs[i].code)
      let exit_ref = if idx >= 0 {
        closes[idx]
      } else {
        hs[i].entry_price
      }
      out[j] = @factors.new_order(hs[i].code, @factors.sell_side(), hs[i].shares, exit_ref)
      j = j + 1
    }
  }
  out
}

///| One opening order per affordable slot, sized to lots of 100 shares.
fn plan_buys(
  hs : Array[Holding],
  targets : Array[String],
  cash : Double,
  closes : Array[Double],
  codes : Array[String],
  cfg : @factors.RiskConfig,
  cap : Int,
  allowed : Bool
) -> Array[@factors.Order] {
  let free = cap - hs.length()
  let mut wanted = 0
  for t in 0..<targets.length() {
    if holding_index(hs, targets[t]) < 0 {
      wanted = wanted + 1
    }
  }
  let slots = if free < wanted {
    free
  } else {
    wanted
  }
  if allowed == false || slots <= 0 || cash <= 0.0 {
    []
  } else {
    let budget = cash / slots.to_double()
    let mut count = 0
    for t in 0..<targets.length() {
      let code = targets[t]
      if holding_index(hs, code) < 0 {
        let idx = index_of(codes, code)
        let px = if idx >= 0 {
          closes[idx]
        } else {
          0.0
        }
        let lots = @factors.shares_to_buy(budget, cash, px, cfg.max_single_weight, 100)
        if lots > 0 {
          count = count + 1
        }
      }
    }
    let out = Array::make(count, @factors.new_order("", @factors.buy_side(), 0, 0.0))
    let mut j = 0
    for t in 0..<targets.length() {
      let code = targets[t]
      if holding_index(hs, code) < 0 {
        let idx = index_of(codes, code)
        let px = if idx >= 0 {
          closes[idx]
        } else {
          0.0
        }
        let lots = @factors.shares_to_buy(budget, cash, px, cfg.max_single_weight, 100)
        if lots > 0 {
          out[j] = @factors.new_order(code, @factors.buy_side(), lots, px)
          j = j + 1
        }
      }
    }
    out
  }
}

///|
fn concat_orders(
  a : Array[@factors.Order],
  b : Array[@factors.Order]
) -> Array[@factors.Order] {
  let out = Array::make(a.length() + b.length(), @factors.new_order("", @factors.buy_side(), 0, 0.0))
  let mut j = 0
  for i in 0..<a.length() {
    out[j] = a[i]
    j = j + 1
  }
  for i in 0..<b.length() {
    out[j] = b[i]
    j = j + 1
  }
  out
}

///|
fn main {
  let codes = universe()
  let opens = open_prices()
  let closes = close_prices()
  let broadths = breadth_series()
  let days = build_days()
  let features = @factors.all_features()
  let cfg = @factors.new_config(0.08, 0.15, 5, 3, 0.45, 6, 0.25)
  let regime = @factors.regime(1)
  let cap = @factors.position_cap(regime, cfg)

  let mut book : Book = { cash: 1000000.0, holdings: [] }
  let equity_curve = Array::make(closes.length(), 0.0)
  let mut risk = @factors.new_state(1000000.0)
  let mut pending : Array[@factors.Order] = []
  let mut last_file = ""

  println("=== 12-day paper run on synthetic prices ===")
  println("day   equity            holdings   orders")
  for day in 0..<closes.length() {
    book = settle(book, pending, opens[day], codes, day)
    let held = shares_of(book.holdings, codes)
    let eq = @factors.equity(book.cash, held, closes[day])
    equity_curve[day] = eq
    risk = @factors.update_state(risk, day, eq, broadths[day], cfg)

    let scores = @factors.composite(days[day], features, @factors.weights_before(days, day), 3.0)
    let targets = @factors.top_n(codes, scores, cap)

    let sells = plan_sells(book.holdings, targets, closes[day], codes, day, cfg, 5)
    let buying_ok = day >= 1 && @factors.new_buys_allowed(risk, day) && @factors.breadth_ok(
      broadths[day],
      cfg,
    )
    let buys = plan_buys(
      book.holdings,
      targets,
      book.cash,
      closes[day],
      codes,
      cfg,
      cap,
      buying_ok,
    )
    pending = concat_orders(sells, buys)
    last_file = @factors.render_order_file(pending)

    println(
      "\{day}    \{eq}   \{book.holdings.length()}          \{pending.length()}",
    )
  }

  println("")
  println("=== result (synthetic data, not a return claim) ===")
  println("final equity     \{equity_curve[closes.length() - 1]}")
  println("total return     \{@factors.total_return(equity_curve)}")
  println("max drawdown     \{@factors.max_drawdown(equity_curve)}")
  println("days underwater  \{@factors.days_in_drawdown(equity_curve)}")
  println("")
  println("=== instruction file for the next session ===")
  println(last_file)
}
