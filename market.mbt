/// Market data for one trading day, used by the simulation.
/// Kept separate from `DaySlice` so factor code never touches execution prices:
/// scoring uses only information available at the previous close.

///|
pub struct MarketDay {
  codes : Array[String]
  /// Opening prices used to fill orders generated the previous evening.
  open_prices : Array[Double]
  close_prices : Array[Double]
  /// False for suspended names and for limit-down/limit-up names we cannot hit.
  tradable : Array[Bool]
  /// Share of advancing names in the whole pool, 0.0 to 1.0.
  breadth : Double
}

///|
pub fn new_market_day(
  codes : Array[String],
  open_prices : Array[Double],
  close_prices : Array[Double],
  tradable : Array[Bool],
  breadth : Double
) -> MarketDay {
  {
    codes: codes,
    open_prices: open_prices,
    close_prices: close_prices,
    tradable: tradable,
    breadth: breadth,
  }
}

///| Price of one code in a parallel price array. Returns 0.0 when absent,
///| which callers reject through `can_trade`.
pub fn price_of(codes : Array[String], prices : Array[Double], code : String) -> Double {
  let mut out = 0.0
  for i in 0..<codes.length() {
    if codes[i] == code {
      out = prices[i]
    }
  }
  out
}

///| Whether a name can be traded today.
pub fn can_trade(d : MarketDay, code : String) -> Bool {
  let mut ok = false
  for i in 0..<d.codes.length() {
    if d.codes[i] == code {
      ok = d.tradable[i]
    }
  }
  ok
}
