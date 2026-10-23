/// Concentration tests. The one behaviour that really matters is the last
/// thing a naive implementation gets wrong: money removed from an overloaded
/// group must NOT quietly reappear somewhere else.

let pool : Array[String] = ["BJ1", "BJ2", "BJ3", "BJ4"]

// three of the four names sit in the same industry
let labels : Array[String] = ["tech", "tech", "tech", "mining"]

let groups : Array[String] = ["tech", "mining"]

let weights_set : Array[Double] = [0.30, 0.20, 0.15, 0.35]

///|
test "group totals add up per label" {
  assert_eq(group_totals(weights_set, labels, groups), [0.65, 0.35])
}

///|
test "distinct labels keep first-seen order" {
  assert_eq(distinct_labels(labels), ["tech", "mining"])
}

///|
test "the largest group share is the whole point of the check" {
  assert_eq(largest_group_share(weights_set, labels, groups), 0.65)
}

///|
test "an over-cap group is flagged" {
  assert_eq(violated_groups(weights_set, labels, groups, 0.40), [true, false])
}

///|
test "a group exactly on the cap is not flagged" {
  let even : Array[Double] = [0.20, 0.20, 0.20, 0.40]
  assert_eq(violated_groups(even, labels, groups, 0.60), [false, false])
}

///|
test "capping lands the group exactly on the limit" {
  let capped = cap_by_group(weights_set, labels, groups, 0.40)
  let totals = group_totals(capped, labels, groups)
  assert_eq(totals[0] < 0.40 + 0.0000001, true)
  assert_eq(totals[0] > 0.40 - 0.0000001, true)
}

///|
test "scaling is proportional within the group" {
  let capped = cap_by_group(weights_set, labels, groups, 0.40)
  // 0.30 and 0.15 keep their 2:1 relationship after a common haircut
  assert_eq(capped[0] / capped[2], weights_set[0] / weights_set[2])
}

///|
test "an untouched group keeps its weight" {
  let capped = cap_by_group(weights_set, labels, groups, 0.40)
  assert_eq(capped[3], 0.35)
}

///|
test "the released money stays out of the book" {
  let released = released_by_capping(weights_set, labels, groups, 0.40)
  assert_eq(released > 0.0, true)
  let capped = cap_by_group(weights_set, labels, groups, 0.40)
  assert_eq(invested_total(capped), invested_total(weights_set) - released)
}

///|
test "capping never increases any single position" {
  let capped = cap_by_group(weights_set, labels, groups, 0.40)
  for i in 0..<weights_set.length() {
    assert_eq(capped[i] <= weights_set[i], true)
  }
}

///|
test "a book entirely inside one group collapses to the cap" {
  let one_group : Array[String] = ["only"]
  let all_same : Array[String] = ["only", "only", "only", "only"]
  let capped = cap_by_group(weights_set, all_same, one_group, 0.50)
  assert_eq(invested_total(capped) < 0.50 + 0.0000001, true)
  assert_eq(invested_total(capped) > 0.50 - 0.0000001, true)
}

///|
test "a cap nobody violates changes nothing" {
  let capped = cap_by_group(weights_set, labels, groups, 0.90)
  assert_eq(capped[0], weights_set[0])
  assert_eq(released_by_capping(weights_set, labels, groups, 0.90), 0.0)
}

///|
test "an empty book is handled" {
  assert_eq(group_totals([], [], []).length(), 0)
  assert_eq(invested_total([]), 0.0)
}
