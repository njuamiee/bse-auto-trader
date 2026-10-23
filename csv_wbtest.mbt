/// Tests for the CSV reader. The rules that matter here are the ones that
/// silently corrupt a backtest: stray CR from Windows files, a trailing line
/// with no newline, and a missing value that must not quietly become 0.

///|
test "csv_lines handles LF and keeps the trailing line" {
  assert_eq(csv_lines("a\nb\nc"), ["a", "b", "c"])
}

///|
test "csv_lines strips CR from CRLF files" {
  assert_eq(csv_lines("a\r\nb\r\n"), ["a", "b"])
}

///|
test "csv_lines on empty input yields no lines" {
  assert_eq(csv_lines("").length(), 0)
}

///|
test "csv_row splits plain fields" {
  assert_eq(csv_row("BJ1,10.5,20.2"), ["BJ1", "10.5", "20.2"])
}

///|
test "csv_row keeps commas inside quotes" {
  assert_eq(csv_row("\"a,b\",c"), ["a,b", "c"])
}

///|
test "csv_row collapses escaped quotes" {
  assert_eq(csv_row("\"say \"\"hi\"\"\",x"), ["say \"hi\"", "x"])
}

///|
test "csv_row preserves empty trailing field" {
  assert_eq(csv_row("a,b,"), ["a", "b", ""])
}

///|
test "is_number rejects non numeric fields" {
  assert_eq(is_number("12.5"), true)
  assert_eq(is_number("-3"), true)
  assert_eq(is_number(""), false)
  assert_eq(is_number("NA"), false)
}

///|
test "csv_floats parses numbers and marks fallback" {
  let row = csv_floats("1.5,2,3.25", fallback=0.0)
  assert_eq(row.length(), 3)
  assert_eq(row[0], 1.5)
  assert_eq(row[2], 3.25)
}

///|
test "missing values are reported, not silently zeroed" {
  let missing = csv_missing("1.5,NA,3")
  assert_eq(missing.length(), 3)
  assert_eq(missing[0], false)
  assert_eq(missing[1], true)
  assert_eq(missing[2], false)
}

///|
test "a missing value never becomes a usable number" {
  let row = csv_floats("1.5,NA", fallback=-999.0)
  assert_eq(row[1], -999.0)
}
