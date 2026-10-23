/// Split tests. These are the guard against look-ahead leakage, which is the
/// only mistake in this file that would make every reported number wrong.

// 252 train, 63 valid, 21 test, 6 day embargo, rolling by 21
let folds : Array[Fold] = build_folds(600, 252, 63, 21, 6, 21)

///|
test "windows keep the caller's lengths" {
  let f = folds[0]
  assert_eq(train_end_of(f) - train_start_of(f), 252)
  assert_eq(valid_end_of(f) - valid_start_of(f), 63)
  assert_eq(test_end_of(f) - test_start_of(f), 21)
}

///|
test "the embargo separates training from validation" {
  let f = folds[0]
  assert_eq(valid_start_of(f) - train_end_of(f), 6)
}

///|
test "the embargo separates validation from the test window" {
  let f = folds[0]
  assert_eq(test_start_of(f) - valid_end_of(f), 6)
}

///|
test "windows never overlap" {
  let f = folds[0]
  assert_eq(train_end_of(f) <= valid_start_of(f), true)
  assert_eq(valid_end_of(f) <= test_start_of(f), true)
}

///|
test "information cutoff excludes the test window" {
  let f = folds[0]
  assert_eq(information_cutoff(f) < test_start_of(f), true)
}

///|
test "later folds advance by exactly one test window" {
  let a = folds[0]
  let b = folds[1]
  assert_eq(test_start_of(b) - test_start_of(a), 21)
}

///|
test "no fold runs past the available history" {
  let last = folds[folds.length() - 1]
  assert_eq(test_end_of(last) <= 600, true)
}

///|
test "too little history yields no folds rather than a broken one" {
  assert_eq(build_folds(10, 252, 63, 21, 6, 21).length(), 0)
}

///|
test "a zero step rolls by the test length" {
  let auto = build_folds(600, 252, 63, 21, 6, 0)
  assert_eq(auto.length(), folds.length())
}

///|
test "the window helper is half open" {
  assert_eq(in_window(5, 5, 10), true)
  assert_eq(in_window(10, 5, 10), false)
}
