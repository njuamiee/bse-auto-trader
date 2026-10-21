/// Cross-check harness.
///
/// Prints every intermediate number of the pipeline in a machine-readable
/// form so an independent implementation can be diffed against it value by
/// value:
///
///   SCALAR <name> <value>
///   SERIES <name> <index> <value>
///   CODE   <name> <index> <code>
///
/// Run with `moon run cmd/verify`. The Python side lives in the research
/// repository under tools/bse_crosscheck/ and mirrors this dataset exactly.
///
/// The dataset is synthetic and fixed, so both sides can hardcode the same
/// numbers and still exercise the whole chain.

///|
fn codes() -> Array[String] {
  ["BJ430047", "BJ831726", "BJ873223", "BJ836260", "BJ833819", "BJ873693"]
}

///|
fn closes() -> Array[Array[Double]] {
  [
    [10.2, 19.8, 15.3, 8.4, 11.8, 25.5],
    [10.1, 20.2, 15.0, 8.9, 11.5, 26.1],
    [10.5, 20.0, 14.8, 9.4, 11.2, 25.8],
    [10.9, 19.5, 14.2, 9.2, 11.8, 25.0],
    [10.2, 18.6, 13.5, 8.7, 12.4, 23.8],
    [9.6, 18.0, 13.0, 8.2, 12.9, 22.9],
  ]
}

///|
fn turnover() -> Array[Array[Double]] {
  [
    [0.012, 0.008, 0.021, 0.005, 0.030, 0.014],
    [0.020, 0.011, 0.018, 0.004, 0.026, 0.017],
    [0.028, 0.009, 0.014, 0.007, 0.024, 0.019],
    [0.010, 0.019, 0.013, 0.006, 0.022, 0.011],
    [0.015, 0.024, 0.010, 0.012, 0.018, 0.026],
    [0.022, 0.030, 0.009, 0.016, 0.012, 0.032],
  ]
}

///|
fn print_series(name : String, xs : Array[Double]) -> Unit {
  for i in 0..<xs.length() {
    println("SERIES " + name + " " + "\{i}" + " " + "\{xs[i]}")
  }
}

///|
fn print_scalar(name : String, v : Double) -> Unit {
  println("SCALAR " + name + " " + "\{v}")
}

///|
fn print_flag(name : String, v : Bool) -> Unit {
  if v {
    println("SCALAR " + name + " 1")
  } else {
    println("SCALAR " + name + " 0")
  }
}

///|
fn main {
  let codes = codes()
  let closes = closes()
  let days = @factors.build_days(codes, closes, turnover())
  let features = @factors.all_features()
  let last = days.length() - 1

  print_series("momentum_d5", @factors.column(days[last], @factors.feature(0)))
  print_series("turnover_d5", @factors.column(days[last], @factors.feature(1)))
  print_series("volatility_d5", @factors.column(days[last], @factors.feature(2)))
  print_series("forward_d4", @factors.forward_column(closes, 4, codes.length()))

  let momentum = @factors.column(days[last], @factors.feature(0))
  print_scalar("mean_momentum_d5", @factors.mean(momentum))
  print_scalar("std_momentum_d5", @factors.sample_std(momentum))
  print_series("winsor_momentum_d5", @factors.winsorize_std(momentum, 3.0))
  print_series("zscore_momentum_d5", @factors.zscore(momentum))
  print_series("rank_momentum_d5", @factors.rank_average(momentum))
  print_scalar(
    "pearson_momentum_fwd_d5",
    @factors.pearson(momentum, days[last].forward),
  )

  let ics = @factors.ic_vector(days, @factors.feature(0))
  print_series("ic_momentum", ics)
  print_scalar("icir_momentum", @factors.icir(ics))
  let turn_ics = @factors.ic_vector(days, @factors.feature(1))
  print_series("ic_turnover", turn_ics)
  print_scalar("icir_turnover", @factors.icir(turn_ics))

  let weights = @factors.weights_before(days, last)
  print_series("weights", weights)
  let scores = @factors.composite(days[last], features, weights, 3.0)
  print_series("composite", scores)

  let picks = @factors.top_n(codes, scores, 3)
  for i in 0..<picks.length() {
    println("CODE pick " + "\{i}" + " " + picks[i])
  }

  print_scalar(
    "shares_to_buy",
    @factors.shares_to_buy(100000.0, 1000000.0, 10.0, 0.25, 100).to_double(),
  )
  print_scalar(
    "shares_to_buy_capped",
    @factors.shares_to_buy(500000.0, 100000.0, 10.0, 0.10, 100).to_double(),
  )

  let cfg = @factors.new_config(0.08, 0.15, 5, 3, 0.45, 6, 0.25)
  print_flag("stop_loss_hit", @factors.stop_loss_triggered(10.0, 9.1, cfg))
  print_flag("stop_loss_safe", @factors.stop_loss_triggered(10.0, 9.5, cfg))
  print_flag(
    "account_breach",
    @factors.account_drawdown_triggered(850.0, 1000.0, cfg),
  )
  print_scalar("position_cap_choppy", @factors.position_cap(@factors.regime(1), cfg).to_double())
  print_scalar("position_cap_downtrend", @factors.position_cap(@factors.regime(2), cfg).to_double())

  let curve = [1000000.0, 1020000.0, 990000.0, 1010000.0]
  print_scalar("max_drawdown", @factors.max_drawdown(curve))
  print_scalar("total_return", @factors.total_return(curve))
  print_scalar(
    "days_underwater",
    @factors.days_in_drawdown(curve).to_double(),
  )
}
