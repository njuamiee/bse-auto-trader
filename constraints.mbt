/// Concentration limits: keep the book from quietly becoming one bet.
///
/// Selection happens one name at a time, so nothing stops three "different"
/// picks from all being the same industry. When that sector turns, they fall
/// together, and the diversification the plan assumed was never there.
///
/// The rule here is a group cap: sum every position belonging to a group, and
/// if that sum exceeds the cap, scale the whole group down to land exactly on
/// it. Two decisions worth stating, because both are choices and not
/// arithmetic:
///
/// - **the excess becomes uninvested, it is not handed to other names**.
///   Redistributing it would silently increase the bet on whatever happened to
///   be under its own cap, which is how a 20 position portfolio becomes a
///   3 position portfolio without anyone agreeing to that
/// - **scaling is proportional within the group**, so relative conviction
///   inside the group survives the haircut
///
/// Assumes a long-only book. Negative weights are left untouched, which is
/// intentional: handling short positions properly is a different job.

///| Whether `a` is genuinely above `b`.
///
/// Needed because adding three weights of 0.20 gives 0.6000000000000001, so
/// an exact comparison would cap a group that is sitting precisely on its
/// limit. Same reasoning as the noise floor in `factors.mbt`.
fn exceeds(a : Double, b : Double) -> Bool {
  let tol = 0.000000001
  a > b + tol
}

///| Sum of the weights belonging to each group, in `groups` order.
pub fn group_totals(
  weights : Array[Double],
  labels : Array[String],
  groups : Array[String]
) -> Array[Double] {
  let out = Array::make(groups.length(), 0.0)
  for g in 0..<groups.length() {
    let mut total = 0.0
    for i in 0..<weights.length() {
      if i < labels.length() && labels[i] == groups[g] && weights[i] > 0.0 {
        total = total + weights[i]
      }
    }
    out[g] = total
  }
  out
}

///| The distinct group labels present, in first-seen order.
pub fn distinct_labels(labels : Array[String]) -> Array[String] {
  let tmp = Array::make(labels.length(), "")
  let mut m = 0
  for i in 0..<labels.length() {
    let mut seen = false
    for j in 0..<m {
      if tmp[j] == labels[i] {
        seen = true
      }
    }
    if !seen {
      tmp[m] = labels[i]
      m = m + 1
    }
  }
  let out = Array::make(m, "")
  for j in 0..<m {
    out[j] = tmp[j]
  }
  out
}

///| Largest share of the book sitting in one group, before any capping.
pub fn largest_group_share(
  weights : Array[Double],
  labels : Array[String],
  groups : Array[String]
) -> Double {
  let mut worst = 0.0
  for g in 0..<groups.length() {
    let mut total = 0.0
    for i in 0..<weights.length() {
      if i < labels.length() && labels[i] == groups[g] && weights[i] > 0.0 {
        total = total + weights[i]
      }
    }
    if total > worst {
      worst = total
    }
  }
  worst
}

///| Which groups are over their cap.
pub fn violated_groups(
  weights : Array[Double],
  labels : Array[String],
  groups : Array[String],
  cap : Double
) -> Array[Bool] {
  let totals = group_totals(weights, labels, groups)
  let out = Array::make(groups.length(), false)
  for g in 0..<groups.length() {
    out[g] = exceeds(totals[g], cap)
  }
  out
}

///| Scale every over-cap group down so it lands exactly on the cap.
/// The uninvested remainder stays uninvested.
pub fn cap_by_group(
  weights : Array[Double],
  labels : Array[String],
  groups : Array[String],
  cap : Double
) -> Array[Double] {
  let out = Array::make(weights.length(), 0.0)
  for i in 0..<weights.length() {
    out[i] = weights[i]
  }
  let totals = group_totals(weights, labels, groups)
  for g in 0..<groups.length() {
    if exceeds(totals[g], cap) && cap >= 0.0 {
      let factor = cap / totals[g]
      for i in 0..<weights.length() {
        if i < labels.length() && labels[i] == groups[g] && weights[i] > 0.0 {
          out[i] = out[i] * factor
        }
      }
    }
  }
  out
}

///| Total amount actually invested after capping.
pub fn invested_total(weights : Array[Double]) -> Double {
  let mut total = 0.0
  for i in 0..<weights.length() {
    total = total + weights[i]
  }
  total
}

///| How much of the book was released back to cash by capping.
pub fn released_by_capping(
  weights : Array[Double],
  labels : Array[String],
  groups : Array[String],
  cap : Double
) -> Double {
  invested_total(weights) - invested_total(cap_by_group(weights, labels, groups, cap))
}
