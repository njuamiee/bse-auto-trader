/// Selection layer: turn composite scores into a concrete buy list.

/// Absolute value without relying on a math module.
fn abs(x : Double) -> Double {
  if x < 0.0 {
    0.0 - x
  } else {
    x
  }
}

/// Indices of the `n` highest scores, ordered from high to low.
/// Ties keep the earlier index, which makes the result deterministic.
fn argsort_desc(scores : Array[Double], n : Int) -> Array[Int] {
  let len = scores.length()
  let take = if n < len {
    if n < 0 {
      0
    } else {
      n
    }
  } else {
    len
  }
  let out = Array::make(take, 0)
  let used = Array::make(len, false)
  for slot in 0..<take {
    let mut best = -1
    let mut best_score = 0.0
    for i in 0..<len {
      if used[i] == false {
        if best < 0 {
          best = i
          best_score = scores[i]
        } else if scores[i] > best_score {
          best = i
          best_score = scores[i]
        }
      }
    }
    used[best] = true
    out[slot] = best
  }
  out
}

/// Codes of the top `n` stocks by composite score, best first.
/// Returns every code when `n` is larger than the cross-section.
pub fn top_n(
  codes : Array[String],
  scores : Array[Double],
  n : Int
) -> Array[String] {
  let idx = argsort_desc(scores, n)
  let out = Array::make(idx.length(), "")
  for i in 0..<idx.length() {
    out[i] = codes[idx[i]]
  }
  out
}
