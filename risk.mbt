/// Risk rules: per-stock stop loss, account-level drawdown pause, market
/// breadth switch and regime-based position caps.
///
/// Every rule is a pure function of observable inputs plus a small carried
/// state, so a given history always produces the same decisions.

///| Regime produced upstream by a hidden Markov model.
pub enum Regime {
  Calm
  Choppy
  Downtrend
}

///| Risk limits. Written down explicitly so a replay is reproducible.
pub struct RiskConfig {
  stop_loss : Double
  account_drawdown : Double
  pause_days : Int
  recovery_days : Int
  breadth_floor : Double
  max_positions : Int
  max_single_weight : Double
}

///| Build a regime value. 0 = calm, 1 = choppy, 2 = downtrend.
pub fn regime(id : Int) -> Regime {
  match id {
    0 => Calm
    1 => Choppy
    _ => Downtrend
  }
}

///| Build a risk configuration.
pub fn new_config(
  stop_loss : Double,
  account_drawdown : Double,
  pause_days : Int,
  recovery_days : Int,
  breadth_floor : Double,
  max_positions : Int,
  max_single_weight : Double
) -> RiskConfig {
  {
    stop_loss: stop_loss,
    account_drawdown: account_drawdown,
    pause_days: pause_days,
    recovery_days: recovery_days,
    breadth_floor: breadth_floor,
    max_positions: max_positions,
    max_single_weight: max_single_weight,
  }
}

///| Risk state carried from one day to the next.
pub struct RiskState {
  peak_equity : Double
  /// New buys are blocked until this day index.
  pause_until_day : Int
  /// Consecutive healthy days observed while paused.
  recovery_streak : Int
  breadth : Double
}

///|
pub fn new_state(opening_equity : Double) -> RiskState {
  { peak_equity: opening_equity, pause_until_day: 0, recovery_streak: 0, breadth: 1.0 }
}

///| Per-stock hard stop against the entry price.
pub fn stop_loss_triggered(
  entry_price : Double,
  current_price : Double,
  cfg : RiskConfig
) -> Bool {
  if entry_price <= 0.0 {
    false
  } else {
    current_price <= entry_price * (1.0 - cfg.stop_loss)
  }
}

///| Account-level drawdown measured from the running equity peak.
pub fn account_drawdown_triggered(
  equity : Double,
  peak_equity : Double,
  cfg : RiskConfig
) -> Bool {
  if peak_equity <= 0.0 {
    false
  } else {
    equity <= peak_equity * (1.0 - cfg.account_drawdown)
  }
}

///| Market breadth above the floor means new risk is acceptable.
pub fn breadth_ok(breadth : Double, cfg : RiskConfig) -> Bool {
  breadth >= cfg.breadth_floor
}

///| Maximum concurrent holdings allowed under a regime.
pub fn position_cap(regime : Regime, cfg : RiskConfig) -> Int {
  match regime {
    Calm => cfg.max_positions
    Choppy => cfg.max_positions * 2 / 3
    Downtrend => cfg.max_positions / 3
  }
}

///| Whether new positions may be opened on this day.
pub fn new_buys_allowed(state : RiskState, day : Int) -> Bool {
  day >= state.pause_until_day
}

///| Move the risk state forward one day.
///
/// A drawdown breach pauses new buying immediately. While paused, healthy
/// breadth has to repeat for `recovery_days` in a row before buying resumes,
/// so one lucky green day during a slide does not turn the engine back on.
pub fn update_state(
  state : RiskState,
  day : Int,
  equity : Double,
  breadth : Double,
  cfg : RiskConfig
) -> RiskState {
  let peak = if equity > state.peak_equity {
    equity
  } else {
    state.peak_equity
  }
  let breach = account_drawdown_triggered(equity, peak, cfg)
  let mut pause_until = state.pause_until_day
  let mut streak = state.recovery_streak
  if breach {
    pause_until = day + cfg.pause_days
    streak = 0
  } else if pause_until > day {
    if breadth_ok(breadth, cfg) {
      streak = streak + 1
    } else {
      streak = 0
    }
    if streak >= cfg.recovery_days {
      pause_until = day
      streak = 0
    }
  }
  { peak_equity: peak, pause_until_day: pause_until, recovery_streak: streak, breadth: breadth }
}
