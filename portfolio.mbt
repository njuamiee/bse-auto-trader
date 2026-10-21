/// Order generation and position sizing.
///
/// Everything here is deterministic: same horizon, same prices and same
/// limits always give the same order file.

///| Buy or sell.
pub enum Side {
  Buy
  Sell
}

///|
pub struct Order {
  code : String
  side : Side
  shares : Int
  limit_price : Double
}

///| Buy side value. Enum constructors are read-only outside this package.
pub fn buy_side() -> Side {
  Buy
}

///| Sell side value.
pub fn sell_side() -> Side {
  Sell
}

///|
pub fn new_order(code : String, side : Side, shares : Int, limit_price : Double) -> Order {
  { code: code, side: side, shares: shares, limit_price: limit_price }
}

///| Smaller of two values.
fn dmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///| Truncate toward zero and round down to a whole number of lots.
/// A negative or non-finite input yields 0 rather than a nonsense order.
pub fn shares_to_buy(
  budget : Double,
  equity : Double,
  price : Double,
  max_weight : Double,
  lot : Int
) -> Int {
  if price <= 0.0 || lot <= 0 || budget <= 0.0 || equity <= 0.0 {
    0
  } else {
    let target_value = dmin(budget, max_weight * equity)
    let raw = target_value / price
    let lots = raw.to_int() / lot
    lots * lot
  }
}

///| Cash left after buying `shares` lots at `price`.
pub fn cash_after(budget : Double, shares : Int, price : Double) -> Double {
  budget - shares.to_double() * price
}

///| Render one line of the instruction file handed to a trader or broker API.
pub fn render_csv(o : Order) -> String {
  let side = match o.side {
    Buy => "BUY"
    Sell => "SELL"
  }
  o.code + "," + side + "," + "\{o.shares}" + "," + "\{o.limit_price}"
}

///| Render a whole instruction file, header included.
pub fn render_order_file(orders : Array[Order]) -> String {
  let mut text = "code,side,shares,limit_price\n"
  for i in 0..<orders.length() {
    text = text + render_csv(orders[i]) + "\n"
  }
  text
}

///| Total cash committed by a set of buy orders.
pub fn committed_cash(orders : Array[Order]) -> Double {
  let mut total = 0.0
  for i in 0..<orders.length() {
    match orders[i].side {
      Buy => total = total + orders[i].shares.to_double() * orders[i].limit_price
      Sell => ()
    }
  }
  total
}
