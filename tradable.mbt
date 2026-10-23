/// Derive whether a name can actually be traded, from prices and volume.
///
/// `MarketDay` carries a `tradable` flag per name but does not decide it;
/// this module does. Three rules, in order of how often they bite in the
/// Beijing market:
///
/// - **suspension**: no price or no volume means nothing printed, so the name
///   cannot be bought or sold at any price
/// - **limit up**: the day closed at the upper band, so orders to buy would
///   queue behind everyone else and realistically never fill
/// - **limit down**: same from below, and sellers are the ones stuck
///
/// The upper and lower bands are symmetric percentages around the previous
/// close. Beijing names use 30 percent; the mainland boards use 10 or 20, so
/// the ratio is always passed in rather than baked in.
///
/// The band comparison tolerates half of a 0.01 quote tick, because the
/// exchange rounds limit prices to whole cents and an exact float compare
/// would miss almost every real limit day.

///| Tolerance used when comparing against a limit price.
fn within_tick(a : Double, b : Double) -> Bool {
  let d = if a >= b {
    a - b
  } else {
    b - a
  }
  d <= 0.005
}

///| Upper band for the day.
pub fn limit_up_price(prev_close : Double, ratio : Double) -> Double {
  prev_close * (1.0 + ratio)
}

///| Lower band for the day.
pub fn limit_down_price(prev_close : Double, ratio : Double) -> Double {
  prev_close * (1.0 - ratio)
}

///| The 30 percent band used by the Beijing Stock Exchange.
pub fn bse_limit() -> Double {
  0.30
}

///| True when nothing printed for this name today.
pub fn suspended(price : Double, volume : Double) -> Bool {
  price <= 0.0 || volume <= 0.0
}

///| Whether the close sits on the upper band. Needs a usable previous close.
pub fn at_limit_up(price : Double, prev_close : Double, ratio : Double) -> Bool {
  prev_close > 0.0 && within_tick(price, limit_up_price(prev_close, ratio))
}

///| Whether the close sits on the lower band.
pub fn at_limit_down(price : Double, prev_close : Double, ratio : Double) -> Bool {
  prev_close > 0.0 && within_tick(price, limit_down_price(prev_close, ratio))
}

///| Buy side: tradeable unless suspended or locked limit up.
pub fn buyable(
  price : Double,
  prev_close : Double,
  volume : Double,
  ratio : Double
) -> Bool {
  !suspended(price, volume) && !at_limit_up(price, prev_close, ratio)
}

///| Sell side: tradeable unless suspended or locked limit down.
pub fn sellable(
  price : Double,
  prev_close : Double,
  volume : Double,
  ratio : Double
) -> Bool {
  !suspended(price, volume) && !at_limit_down(price, prev_close, ratio)
}

///| Build the whole `tradable` vector for one day.
pub fn build_tradable(
  prices : Array[Double],
  prevs : Array[Double],
  volumes : Array[Double],
  ratio : Double
) -> Array[Bool] {
  let n = prices.length()
  let out = Array::make(n, false)
  for i in 0..<n {
    let prev = if i < prevs.length() {
      prevs[i]
    } else {
      0.0
    }
    let vol = if i < volumes.length() {
      volumes[i]
    } else {
      0.0
    }
    out[i] = buyable(prices[i], prev, vol, ratio)
  }
  out
}

///| How many names in the pool are blocked today.
pub fn blocked_count(flags : Array[Bool]) -> Int {
  let mut c = 0
  for i in 0..<flags.length() {
    if !flags[i] {
      c = c + 1
    }
  }
  c
}
