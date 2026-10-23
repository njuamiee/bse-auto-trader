/// End-to-end run over a price sheet rather than hard-coded arrays.
///
/// The sheet is generated deterministically and then handed to the loader as
/// CSV text, so every downstream stage sees exactly what it would see with a
/// real export: the parser, the pivot, and everything after it cannot tell the
/// difference.
///
/// What this demonstrates, in order: load a sheet, build factors, fit weights
/// on days strictly before today, rank and pick, refuse names that cannot be
/// traded, obey T+1, pay real fees, mark to market, then report against an
/// equal-weight benchmark and break the result down to names.
///
/// Limitation stated plainly: the bundled MoonBit core in this toolchain has
/// no filesystem package, so the sheet arrives as text already in hand.
/// Swapping these few lines for a file reader is the whole change needed once
/// one exists.

///| Two-digit padding for the synthetic date column.
fn pad2(v : Int) -> String {
  if v < 10 {
    "0" + v.to_string()
  } else {
    v.to_string()
  }
}

///| Deterministic pseudo-random step centred on zero, in [-0.1, +0.1].
///
/// The centring is the point. A generator with even a small positive drift
/// turns a random walk into year-on-year compounding, and a report built on
/// top of it flatters every strategy for no reason.
fn step_from(state : Int) -> Double {
  let q = if state < 0 {
    -state
  } else {
    state
  }
  (q % 2001).to_double() / 10000.0 - 0.1
}

///| Advance a small linear congruential generator.
///
/// The multiplier is deliberately small: MoonBit `Int` is 32-bit here, and the
/// textbook 1103515245 silently overflows, which is exactly the kind of bug
/// that quietly corrupts a synthetic dataset.
fn advance(state : Int) -> Int {
  let next = (state * 1103 + 123) % 100003
  if next < 0 {
    -next
  } else {
    next
  }
}

///| Build a synthetic sheet in long CSV form. Same seed, same sheet, always.
fn build_sheet(codes : Array[String], ndays : Int, seed : Int) -> String {
  let n = codes.length()
  let prices = Array::make(n, 0.0)
  for i in 0..<n {
    prices[i] = 12.0 + i.to_double() * 3.5
  }
  let mut s = seed
  let mut text = "date,code,close,volume\r\n"
  let mut d = 0
  while d < ndays {
    for i in 0..<n {
      s = advance(s)
      let moved = prices[i] * (1.0 + step_from(s))
      prices[i] = (moved * 100.0).to_int().to_double() / 100.0
      let volume = 20000 + s % 80000
      let line = pad2(d + 1) + "," + codes[i] + "," + prices[i].to_string() + "," +
        volume.to_string()
      text = text + line + "\r\n"
    }
    d = d + 1
  }
  text
}

///| Zero turnover matrix: the synthetic sheet carries no turnover column, so
/// only momentum and volatility are used as factors.
fn zero_matrix(rows : Int, cols : Int) -> Array[Array[Double]] {
  let out = Array::make(rows, Array::make(0, 0.0))
  let mut r = 0
  while r < rows {
    out[r] = Array::make(cols, 0.0)
    r = r + 1
  }
  out
}

///| Market value of every lot at today's prices.
fn value_lots(codes : Array[String], lots : Array[@factors.Lot], prices : Array[Double]) -> Double {
  let mut total = 0.0
  for i in 0..<codes.length() {
    total = total + @factors.total_shares(lots, codes[i]).to_double() * prices[i]
  }
  total
}

///| Index of a code, or -1.
fn index_of_code(codes : Array[String], code : String) -> Int {
  let mut r = -1
  for i in 0..<codes.length() {
    if codes[i] == code {
      r = i
    }
  }
  r
}

///|
fn main {
  let codes : Array[String] = [
    "BJ430047",
    "BJ833819",
    "BJ836260",
    "BJ871981",
    "BJ873693",
    "BJ920002",
  ]
  let sheet = build_sheet(codes, 40, 20261023)
  let table = @factors.load_price_csv(sheet)
  let ndays = @factors.day_count(table)
  let turnover = zero_matrix(ndays, codes.length())
  let days = @factors.build_days(codes, table.closes, turnover)
  let features : Array[@factors.Feature] = [@factors.feature(0), @factors.feature(2)]

  let initial = 1000000.0
  let costs = @factors.bse_default_costs()
  let max_positions = 3
  let max_weight = 0.35
  let lot = 100

  let equity_series = Array::make(ndays, initial)
  let mut cash = initial
  let mut lots : Array[@factors.Lot] = @factors.empty_book()
  let mut filled = 0
  let mut blocked = 0

  let mut day = 0
  while day < ndays {
    let prices = @factors.close_row(table, day)
    let volumes = @factors.volume_row(table, day)
    let prev = if day > 0 {
      @factors.close_row(table, day - 1)
    } else {
      @factors.close_row(table, day)
    }
    let flags = @factors.build_tradable(prices, prev, volumes, @factors.bse_limit())

    if day >= 2 {
      let w = @factors.normalize_weights(@factors.icir_weights(@factors.take_days(days, day), features))
      let scores = @factors.composite(days[day - 1], features, w, 2.0)
      let picks = @factors.top_n(codes, scores, max_positions)

      // close anything that dropped out of the target list, honouring T+1
      for i in 0..<codes.length() {
        let code = codes[i]
        let held = @factors.total_shares(lots, code)
        if held > 0 && index_of_code(picks, code) < 0 {
          let px = prices[i]
          let qty = @factors.sellable_capped(lots, code, day, held)
          if qty >= lot {
            cash = cash + @factors.cash_in(costs, qty, px)
            lots = @factors.remove_shares(lots, code, qty)
            filled = filled + 1
          }
        }
      }

      // open what is affordable and actually tradeable
      for j in 0..<picks.length() {
        let idx = index_of_code(codes, picks[j])
        if idx >= 0 && flags[idx] {
          let px = prices[idx]
          let equity_now = cash + value_lots(codes, lots, prices)
          let qty = @factors.shares_to_buy(cash, equity_now, px, max_weight, lot)
          if qty >= lot {
            cash = cash + @factors.cash_out(costs, qty, px)
            lots = @factors.add_lot(lots, @factors.new_lot(code=picks[j], shares=qty, buy_day=day))
            filled = filled + 1
          }
        } else {
          blocked = blocked + 1
        }
      }
    }

    equity_series[day] = cash + value_lots(codes, lots, prices)
    day = day + 1
  }

  let benchmark = @factors.equal_weight_equity(table.closes, initial)
  let summary = @factors.summarize(equity_series, 252)
  let episode = @factors.worst_drawdown(equity_series)

  // break the final period down to names, weighing by value held
  let last = @factors.close_row(table, ndays - 1)
  let before = @factors.close_row(table, ndays - 2)
  let code_rets = Array::make(codes.length(), 0.0)
  let held_value = Array::make(codes.length(), 0.0)
  let mut total_val = 0.0
  for i in 0..<codes.length() {
    let v = @factors.total_shares(lots, codes[i]).to_double() * last[i]
    held_value[i] = v
    total_val = total_val + v
    if before[i] > 0.0 {
      code_rets[i] = (last[i] - before[i]) / before[i]
    }
  }
  let held_weights = Array::make(codes.length(), 0.0)
  if total_val > 0.0 {
    for i in 0..<codes.length() {
      held_weights[i] = held_value[i] / total_val
    }
  }

  println("=== ingest ===")
  println("loaded days    " + ndays.to_string())
  println("instruments    " + @factors.code_count(table).to_string())
  println("missing cells  " + @factors.missing_of(table).to_string())
  println("")
  println("=== result (synthetic sheet, not a return claim) ===")
  println("final equity   " + equity_series[ndays - 1].to_string())
  println("total return   " + summary[0].to_string())
  println("annualised     " + summary[1].to_string())
  println("volatility     " + summary[2].to_string())
  println("max drawdown   " + summary[3].to_string())
  println("sharpe         " + summary[4].to_string())
  println("calmar         " + summary[5].to_string())
  println("win rate       " + summary[6].to_string())
  println("note: annualising a short sample extrapolates noise, not expectation")
  println("")
  println("=== against an equal-weight basket ===")
  println("benchmark return " + @factors.total_return(benchmark).to_string())
  println("average active   " + @factors.average_active(equity_series, benchmark).to_string())
  println("tracking error   " + @factors.tracking_error(equity_series, benchmark).to_string())
  println("")
  println("=== execution ===")
  println("orders filled  " + filled.to_string())
  println("blocked buys   " + blocked.to_string())
  println("names held     " + @factors.position_count(lots).to_string())
  println("")
  println("=== attribution ===")
  println(
    "worst drawdown day " + @factors.peak_day_of(episode).to_string() + " to day " +
    @factors.trough_day_of(episode).to_string(),
  )
  println(
    "recovered on day " + @factors.recovery_day_of(episode).to_string() +
    " (-1 means it never did)",
  )
  println("worst holding now " + @factors.worst_contributor(codes, held_weights, code_rets))
}
