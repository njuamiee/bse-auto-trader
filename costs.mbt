/// Trading costs, modelled explicitly rather than assumed away.
///
/// A backtest that ignores costs is not a strategy evaluation, it is a CFD
/// fantasy. Everything here is single-sided and driven by one config, so a
/// different venue is a different config rather than a different code path.
///
/// The defaults mirror the Beijing Stock Exchange conventions used by the
/// Python research pipeline: commission charged on both sides with a floor,
/// stamp duty charged on sells only, a transfer fee on both sides, and a
/// symmetric slippage applied to the execution price.

///| Every cost knob in one place.
pub struct CostConfig {
  commission_rate : Double
  min_commission : Double
  stamp_duty_rate : Double
  transfer_rate : Double
  slippage_bps : Double
}

///| Build a cost configuration.
pub fn new_cost_config(
  commission_rate~ : Double,
  min_commission~ : Double,
  stamp_duty_rate~ : Double,
  transfer_rate~ : Double,
  slippage_bps~ : Double
) -> CostConfig {
  {
    commission_rate: commission_rate,
    min_commission: min_commission,
    stamp_duty_rate: stamp_duty_rate,
    transfer_rate: transfer_rate,
    slippage_bps: slippage_bps,
  }
}

///| Beijing Stock Exchange style defaults used by the research pipeline.
pub fn bse_default_costs() -> CostConfig {
  new_cost_config(
    commission_rate=0.00025,
    min_commission=5.0,
    stamp_duty_rate=0.0005,
    transfer_rate=0.00001,
    slippage_bps=5.0,
  )
}

///| Commission rate actually applied.
pub fn commission_rate_of(c : CostConfig) -> Double {
  c.commission_rate
}

///| Commission on a trade of `amount`, never below the floor.
pub fn commission(c : CostConfig, amount : Double) -> Double {
  if amount <= 0.0 {
    0.0
  } else {
    let raw = c.commission_rate * amount
    if raw < c.min_commission {
      c.min_commission
    } else {
      raw
    }
  }
}

///| Stamp duty, charged on sells only.
pub fn stamp_duty(c : CostConfig, amount : Double) -> Double {
  if amount <= 0.0 {
    0.0
  } else {
    c.stamp_duty_rate * amount
  }
}

///| Transfer fee, charged on both sides.
pub fn transfer_fee(c : CostConfig, amount : Double) -> Double {
  if amount <= 0.0 {
    0.0
  } else {
    c.transfer_rate * amount
  }
}

///| Total fees paid to buy `amount` of stock: no stamp duty.
pub fn buy_fees(c : CostConfig, amount : Double) -> Double {
  commission(c, amount) + transfer_fee(c, amount)
}

///| Total fees paid to sell `amount` of stock: includes stamp duty.
pub fn sell_fees(c : CostConfig, amount : Double) -> Double {
  commission(c, amount) + stamp_duty(c, amount) + transfer_fee(c, amount)
}

///| Fees for either side.
pub fn fees_for(c : CostConfig, side : Side, amount : Double) -> Double {
  match side {
    Buy => buy_fees(c, amount)
    Sell => sell_fees(c, amount)
  }
}

///| Price actually paid after slippage: buys fill higher, sells fill lower.
pub fn fill_price(c : CostConfig, side : Side, price : Double) -> Double {
  let slip = c.slippage_bps / 10000.0 * price
  match side {
    Buy => price + slip
    Sell => price - slip
  }
}

///| Cash moving on a buy, including fees: a negative flow.
pub fn cash_out(c : CostConfig, shares : Int, price : Double) -> Double {
  let px = fill_price(c, buy_side(), price)
  let gross = px * shares.to_double()
  -(gross + buy_fees(c, gross))
}

///| Cash moving on a sell, net of fees: a positive flow.
pub fn cash_in(c : CostConfig, shares : Int, price : Double) -> Double {
  let px = fill_price(c, sell_side(), price)
  let gross = px * shares.to_double()
  gross - sell_fees(c, gross)
}
