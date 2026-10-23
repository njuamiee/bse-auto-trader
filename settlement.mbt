/// Position keeping with A-share settlement semantics.
///
/// Two rules decide whether an order is honest, and skipping either one makes
/// a backtest look better than reality:
///
/// - **T+1**: shares bought today cannot be sold today, only from tomorrow on
/// - **first in, first out**: closing part of a position consumes the oldest
///   lots first, which is what a broker does and what the research pipeline
///   assumes when computing holding periods
///
/// Sale proceeds are treated as immediately available for new buys, matching
/// how A-share accounts actually behave; only withdrawal is delayed.

///| One purchase, remembering when it settled.
pub struct Lot {
  code : String
  shares : Int
  buy_day : Int
}

///| Build a lot.
pub fn new_lot(code~ : String, shares~ : Int, buy_day~ : Int) -> Lot {
  { code: code, shares: shares, buy_day: buy_day }
}

///| Instrument a lot belongs to.
pub fn lot_code(l : Lot) -> String {
  l.code
}

///| Size of a lot.
pub fn lot_shares(l : Lot) -> Int {
  l.shares
}

///| Day the lot was bought, used for the T+1 check.
pub fn lot_buy_day(l : Lot) -> Int {
  l.buy_day
}

///| All lots held, grouped implicitly by their code.
pub fn empty_book() -> Array[Lot] {
  []
}

///| Add a purchase to the book.
pub fn add_lot(lots : Array[Lot], lot : Lot) -> Array[Lot] {
  let n = lots.length()
  let out = Array::make(n + 1, lot)
  for i in 0..<n {
    out[i] = lots[i]
  }
  out
}

///| Shares of one name held regardless of settlement.
pub fn total_shares(lots : Array[Lot], code : String) -> Int {
  let mut s = 0
  for i in 0..<lots.length() {
    if lots[i].code == code {
      s = s + lots[i].shares
    }
  }
  s
}

///| Shares available to sell today: everything bought strictly before today.
pub fn sellable_shares(lots : Array[Lot], code : String, today : Int) -> Int {
  let mut s = 0
  for i in 0..<lots.length() {
    let l = lots[i]
    if l.code == code && l.buy_day < today {
      s = s + l.shares
    }
  }
  s
}

///| Largest quantity sellable under T+1, capped by an intended size.
pub fn sellable_capped(
  lots : Array[Lot],
  code : String,
  today : Int,
  wanted : Int
) -> Int {
  let avail = sellable_shares(lots, code, today)
  if wanted <= avail {
    wanted
  } else {
    avail
  }
}

///| Close out the oldest lots first, returning the reduced book.
pub fn remove_shares(lots : Array[Lot], code : String, qty : Int) -> Array[Lot] {
  if lots.length() == 0 || qty <= 0 {
    lots
  } else {
    let mut remaining = qty
    let tmp = Array::make(lots.length(), lots[0])
    let mut k = 0
    for i in 0..<lots.length() {
      let l = lots[i]
      if l.code == code && remaining > 0 {
        let take = if l.shares <= remaining {
          l.shares
        } else {
          remaining
        }
        remaining = remaining - take
        let left = l.shares - take
        if left > 0 {
          tmp[k] = new_lot(code=l.code, shares=left, buy_day=l.buy_day)
          k = k + 1
        }
      } else {
        tmp[k] = l
        k = k + 1
      }
    }
    let out = Array::make(k, lots[0])
    for j in 0..<k {
      out[j] = tmp[j]
    }
    out
  }
}

///| Number of distinct names held.
pub fn position_count(lots : Array[Lot]) -> Int {
  let seen = Array::make(lots.length(), "")
  let mut m = 0
  for i in 0..<lots.length() {
    let c = lots[i].code
    let mut dup = false
    for j in 0..<m {
      if seen[j] == c {
        dup = true
      }
    }
    if !dup && lots[i].shares > 0 {
      seen[m] = c
      m = m + 1
    }
  }
  m
}
