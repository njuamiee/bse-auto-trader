/// Expanding and rolling time-series splits.
///
/// The split is built before any model sees data, because a slide tuned on the
/// same days it is later judged on has already answered tomorrow's question.
/// Three windows are produced per fold, always in this order and never
/// overlapping:
///
/// ```text
/// [ train ][ gap ][ valid ][ gap ][ test ]
/// ```
///
/// The gap is an embargo, not decoration: features computed on day `t` use
/// returns up to a horizon ahead, so training must stop that far before the
/// window it will be judged on. Its width comes from the caller because only
/// the caller knows the forecast horizon.

///| One split. Ends are exclusive, as everywhere else in this engine.
pub struct Fold {
  train_start : Int
  train_end : Int
  valid_start : Int
  valid_end : Int
  test_start : Int
  test_end : Int
}

///|
pub fn new_fold(
  train_start~ : Int,
  train_end~ : Int,
  valid_start~ : Int,
  valid_end~ : Int,
  test_start~ : Int,
  test_end~ : Int
) -> Fold {
  {
    train_start: train_start,
    train_end: train_end,
    valid_start: valid_start,
    valid_end: valid_end,
    test_start: test_start,
    test_end: test_end,
  }
}

///|
pub fn train_start_of(f : Fold) -> Int {
  f.train_start
}

///|
pub fn train_end_of(f : Fold) -> Int {
  f.train_end
}

///|
pub fn valid_start_of(f : Fold) -> Int {
  f.valid_start
}

///|
pub fn valid_end_of(f : Fold) -> Int {
  f.valid_end
}

///|
pub fn test_start_of(f : Fold) -> Int {
  f.test_start
}

///|
pub fn test_end_of(f : Fold) -> Int {
  f.test_end
}

///| Last index available before the test window opens. Nothing past this may
/// be consulted once the fold is being scored.
pub fn information_cutoff(f : Fold) -> Int {
  f.test_start - 1
}

///| Build rolling folds. `step` defaults to the test length when not given,
/// which advances exactly one test window at a time.
pub fn build_folds(
  total : Int,
  train_len : Int,
  valid_len : Int,
  test_len : Int,
  gap : Int,
  step : Int
) -> Array[Fold] {
  let advance = if step <= 0 {
    test_len
  } else {
    step
  }
  let span = train_len + gap + valid_len + gap + test_len
  if total < span || advance <= 0 {
    []
  } else {
    let last_start = total - span
    let n = last_start / advance + 1
    let seed = new_fold(train_start=0, train_end=0, valid_start=0, valid_end=0, test_start=0, test_end=0)
    let out = Array::make(n, seed)
    for k in 0..<n {
      let s = k * advance
      let ts_train = s
      let te_train = s + train_len
      let vs = te_train + gap
      let ve = vs + valid_len
      let ts = ve + gap
      let te = ts + test_len
      out[k] = new_fold(
        train_start=ts_train,
        train_end=te_train,
        valid_start=vs,
        valid_end=ve,
        test_start=ts,
        test_end=te,
      )
    }
    out
  }
}

///| Whether `i` lies inside `[start, end)`.
pub fn in_window(i : Int, start : Int, end : Int) -> Bool {
  i >= start && i < end
}
