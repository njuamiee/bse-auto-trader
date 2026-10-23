/// Tests for pivoting a long price sheet. Pivoting is where a backtest quietly
/// goes wrong: a misaligned row puts yesterday's price under today's date.

let sheet =
  #|date,code,close
  #|2026-01-02,BJ1,10.0
  #|2026-01-02,BJ2,20.0
  #|2026-01-05,BJ1,11.0
  #|2026-01-05,BJ2,19.5

let gap =
  #|date,code,close
  #|2026-01-02,BJ1,10.0
  #|2026-01-02,BJ2,20.0
  #|2026-01-05,BJ1,11.0

let dup =
  #|date,code,close
  #|2026-01-02,BJ1,10.0
  #|2026-01-02,BJ1,12.0

let bad =
  #|date,code,close
  #|2026-01-02,BJ1,NA

let crlf = "date,code,close\r\n2026-01-02,BJ1,10.0\r\n"

let with_volume =
  #|date,code,close,volume
  #|2026-01-02,BJ1,10.0,12000
  #|2026-01-02,BJ2,20.0,500
  #|2026-01-05,BJ1,11.0,0

///|
test "a fourth column is pivoted into volumes" {
  let t = load_price_csv(with_volume)
  assert_eq(volume_row(t, 0), [12000.0, 500.0])
  assert_eq(volume_row(t, 1), [0.0, 0.0])
}

///|
test "a sheet without volume yields zero volumes rather than failing" {
  let t = load_price_csv(sheet)
  assert_eq(volume_row(t, 0), [0.0, 0.0])
}

///|
test "header row is skipped and shape is detected" {
  let t = load_price_csv(sheet)
  assert_eq(day_count(t), 2)
  assert_eq(code_count(t), 2)
}

///|
test "codes keep first-seen order" {
  let t = load_price_csv(sheet)
  assert_eq(codes_of(t), ["BJ1", "BJ2"])
}

///|
test "dates keep chronological order" {
  let t = load_price_csv(sheet)
  assert_eq(dates_of(t), ["2026-01-02", "2026-01-05"])
}

///|
test "values land in the right day and column" {
  let t = load_price_csv(sheet)
  assert_eq(close_row(t, 0), [10.0, 20.0])
  assert_eq(close_row(t, 1), [11.0, 19.5])
}

///|
test "a gap in coverage is counted as missing, not zero" {
  let t = load_price_csv(gap)
  assert_eq(missing_of(t), 1)
  assert_eq(close_row(t, 1), [11.0, 0.0])
}

///|
test "a duplicate row takes the last value" {
  let t = load_price_csv(dup)
  assert_eq(day_count(t), 1)
  assert_eq(close_row(t, 0)[0], 12.0)
}

///|
test "an unparseable price is treated as absent, not dropped" {
  let t = load_price_csv(bad)
  assert_eq(day_count(t), 1)
  assert_eq(code_count(t), 1)
  assert_eq(missing_of(t), 1)
  assert_eq(close_row(t, 0)[0], 0.0)
}

///|
test "CRLF files load identically" {
  let t = load_price_csv(crlf)
  assert_eq(day_count(t), 1)
  assert_eq(close_row(t, 0)[0], 10.0)
}
