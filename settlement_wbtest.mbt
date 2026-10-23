/// Settlement tests. These encode the rule that most inflates naive
/// simulations: selling a position on the very day it was bought.

let b1 : Array[Lot] = add_lot(empty_book(), new_lot(code="BJ1", shares=500, buy_day=3))

let b2 : Array[Lot] = add_lot(b1, new_lot(code="BJ1", shares=300, buy_day=5))

let b3 : Array[Lot] = add_lot(b2, new_lot(code="BJ2", shares=200, buy_day=5))

///|
test "total shares ignore the settlement date" {
  assert_eq(total_shares(b3, "BJ1"), 800)
}

///|
test "shares bought today are not sellable today" {
  assert_eq(sellable_shares(b2, "BJ1", 5), 500)
}

///|
test "they become sellable the next day" {
  assert_eq(sellable_shares(b2, "BJ1", 6), 800)
}

///|
test "a requested size is capped by what has settled" {
  assert_eq(sellable_capped(b2, "BJ1", 5, 700), 500)
  assert_eq(sellable_capped(b2, "BJ1", 6, 700), 700)
}

///|
test "reducing a position consumes the oldest lot first" {
  let out = remove_shares(b3, "BJ1", 600)
  assert_eq(total_shares(out, "BJ1"), 200)
  // what remains is the tail of the second lot, bought on day 5
  assert_eq(sellable_shares(out, "BJ1", 5), 0)
  assert_eq(sellable_shares(out, "BJ1", 6), 200)
}

///|
test "other names are untouched by a reduction" {
  let out = remove_shares(b3, "BJ1", 600)
  assert_eq(total_shares(out, "BJ2"), 200)
}

///|
test "closing all lots of a name removes it" {
  let out = remove_shares(b3, "BJ2", 200)
  assert_eq(total_shares(out, "BJ2"), 0)
  assert_eq(position_count(out), 1)
}

///|
test "removing nothing returns the book unchanged" {
  let out = remove_shares(b3, "BJ1", 0)
  assert_eq(total_shares(out, "BJ1"), 800)
}

///|
test "the book counts distinct names held" {
  assert_eq(position_count(b3), 2)
}

///|
test "an empty book sells nothing" {
  assert_eq(total_shares(empty_book(), "BJ1"), 0)
  assert_eq(sellable_shares(empty_book(), "BJ1", 0), 0)
  assert_eq(position_count(empty_book()), 0)
}
