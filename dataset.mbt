/// Turn a long-format price sheet into the matrix the engine scores.
///
/// Input is one row per instrument per day, with at least three columns:
///
/// ```csv
/// date,code,close
/// 2026-01-02,BJ430047,10.5
/// ```
///
/// Rows are pivoted into `(day, instrument)` matrices. Two decisions worth
/// stating plainly, because they change backtest numbers:
/// - a price that cannot be parsed is treated as **absent**, not as zero;
///   absent cells are counted in `missing_cells` so they cannot pass unnoticed
/// - if the same instrument appears twice on one day, the **last** row wins
///   rather than raising, so a dirty sheet still loads

///| A pivoted price matrix plus the instruments and dates it covers.
pub struct PriceTable {
  dates : Array[String]
  codes : Array[String]
  closes : Array[Array[Double]]
  volumes : Array[Array[Double]]
  missing_cells : Int
}

///| Build a price table. Exposed so callers outside the package can build one.
pub fn new_price_table(
  dates~ : Array[String],
  codes~ : Array[String],
  closes~ : Array[Array[Double]],
  volumes~ : Array[Array[Double]],
  missing_cells~ : Int
) -> PriceTable {
  {
    dates: dates,
    codes: codes,
    closes: closes,
    volumes: volumes,
    missing_cells: missing_cells,
  }
}

///| First-day-first ordering of the dates covered.
pub fn dates_of(t : PriceTable) -> Array[String] {
  t.dates
}

///| First-seen ordering of the instruments covered.
pub fn codes_of(t : PriceTable) -> Array[String] {
  t.codes
}

///| Row `day` of close prices, aligned with `codes_of`.
pub fn close_row(t : PriceTable, day : Int) -> Array[Double] {
  t.closes[day]
}

///| Row `day` of traded volumes, aligned with `codes_of`. Zero wherever the
/// sheet carried no usable volume, which downstream reads as "cannot tell".
pub fn volume_row(t : PriceTable, day : Int) -> Array[Double] {
  t.volumes[day]
}

///| How many `(day, instrument)` cells ended up without a usable price.
pub fn missing_of(t : PriceTable) -> Int {
  t.missing_cells
}

///| Number of trading days loaded.
pub fn day_count(t : PriceTable) -> Int {
  t.dates.length()
}

///| Number of instruments loaded.
pub fn code_count(t : PriceTable) -> Int {
  t.codes.length()
}

///| Keep first occurrences only, preserving encounter order.
fn uniques(vals : Array[String]) -> Array[String] {
  let tmp = Array::make(vals.length(), "")
  let mut m = 0
  for i in 0..<vals.length() {
    let mut seen = false
    let mut j = 0
    while j < m && !seen {
      if tmp[j] == vals[i] {
        seen = true
      }
      j = j + 1
    }
    if !seen {
      tmp[m] = vals[i]
      m = m + 1
    }
  }
  let out = Array::make(m, "")
  for j in 0..<m {
    out[j] = tmp[j]
  }
  out
}

///| Position of `s` in `arr`, or -1.
fn index_of(arr : Array[String], s : String) -> Int {
  let mut r = -1
  for i in 0..<arr.length() {
    if arr[i] == s {
      r = i
    }
  }
  r
}

///| Parse a long-format CSV into a pivoted price table.
///
/// The first line is treated as a header when its third field is not a
/// number. Every following line with at least three fields becomes a row:
/// an unusable price still registers the date and the instrument, it just
/// leaves that cell absent, because knowing that a stock traded that day is
/// worth keeping even when its price did not arrive intact.
pub fn load_price_csv(text : String) -> PriceTable {
  let lines = csv_lines(text)
  let mut start = 0
  if lines.length() > 0 {
    let first = csv_row(lines[0])
    if first.length() < 3 || !is_number(first[2]) {
      start = 1
    }
  }
  let mut nrow = 0
  let mut l = start
  while l < lines.length() {
    let fields = csv_row(lines[l])
    if fields.length() >= 3 {
      nrow = nrow + 1
    }
    l = l + 1
  }
  let dates_raw = Array::make(nrow, "")
  let codes_raw = Array::make(nrow, "")
  let vals = Array::make(nrow, 0.0)
  let vols = Array::make(nrow, 0.0)
  let mut k = 0
  let mut i = start
  while i < lines.length() {
    let fields = csv_row(lines[i])
    if fields.length() >= 3 {
      dates_raw[k] = fields[0]
      codes_raw[k] = fields[1]
      vals[k] = try {
        @string.parse_double(fields[2])
      } catch {
        _ => 0.0
      }
      vols[k] = if fields.length() >= 4 {
        try {
          @string.parse_double(fields[3])
        } catch {
          _ => 0.0
        }
      } else {
        0.0
      }
      k = k + 1
    }
    i = i + 1
  }
  let dates = uniques(dates_raw)
  let codes = uniques(codes_raw)
  let closes = Array::make(dates.length(), Array::make(0, 0.0))
  let mut d = 0
  while d < dates.length() {
    closes[d] = Array::make(codes.length(), 0.0)
    d = d + 1
  }
  let mut r = 0
  while r < nrow {
    let di = index_of(dates, dates_raw[r])
    let ci = index_of(codes, codes_raw[r])
    if di >= 0 && ci >= 0 {
      closes[di][ci] = vals[r]
    }
    r = r + 1
  }
  let volumes = Array::make(dates.length(), Array::make(0, 0.0))
  let mut vd = 0
  while vd < dates.length() {
    volumes[vd] = Array::make(codes.length(), 0.0)
    vd = vd + 1
  }
  let mut rr = 0
  while rr < nrow {
    let di = index_of(dates, dates_raw[rr])
    let ci = index_of(codes, codes_raw[rr])
    if di >= 0 && ci >= 0 {
      volumes[di][ci] = vols[rr]
    }
    rr = rr + 1
  }
  let mut missing = 0
  let mut dd = 0
  while dd < dates.length() {
    let mut cc = 0
    while cc < codes.length() {
      if closes[dd][cc] <= 0.0 {
        missing = missing + 1
      }
      cc = cc + 1
    }
    dd = dd + 1
  }
  new_price_table(
    dates=dates,
    codes=codes,
    closes=closes,
    volumes=volumes,
    missing_cells=missing,
  )
}
