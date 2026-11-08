-- The Select button's two secret uses: held for HOLD_SECONDS it toggles the FPS counter, and pressed
-- TAPS times in quick succession (each within TAP_GAP seconds of the last) it pays CHEAT_COINS.
local selectbutton = {
  HOLD_SECONDS = 2,
  TAPS = 10,
  TAP_GAP = 0.5,
  CHEAT_COINS = 1000,
}

function selectbutton.new()
  return { taps = 0, lastTap = -math.huge, held = 0 }
end

-- Counts a press at `now` (seconds); true on the press that completes the taps.
function selectbutton.tap(tracker, now)
  tracker.taps = now - tracker.lastTap <= selectbutton.TAP_GAP and tracker.taps + 1 or 1
  tracker.lastTap = now
  if tracker.taps < selectbutton.TAPS then return false end
  tracker.taps = 0
  return true
end

-- Advances the hold by `dt` while `down`; true once per hold, when it reaches HOLD_SECONDS.
function selectbutton.hold(tracker, dt, down)
  if not down then
    tracker.held = 0
    return false
  end
  local before = tracker.held
  tracker.held = before + dt
  return before < selectbutton.HOLD_SECONDS and tracker.held >= selectbutton.HOLD_SECONDS
end

return selectbutton
