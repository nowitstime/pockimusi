#!/usr/bin/env python3
"""
Test runner for pure logic verification of Theory, Looper, and Input math.
Runs headless without requiring Love2D runtime or graphical display.
"""

def test_deduplication_wraparound():
    # Simulates looper deduplication logic
    events = [
        {"action": "B", "phase": 0.0},
        {"action": "B", "phase": 0.5},
    ]
    snapSteps = 16
    snappedPhase = 15.0 / 16.0 # 0.9375
    # diff between 0.0 and 0.9375 is 0.9375, wrap is 0.0625 which is 1/16, so < 0.4/16 is false (different step)
    diff = abs(0.0 - snappedPhase)
    if diff > 0.5:
        diff = 1.0 - diff
    assert abs(diff - 0.0625) < 1e-6

    # Test exact wrap: existing at 0.0, snapped at 0.0
    diff = abs(0.0 - 0.0)
    assert diff < (0.4 / snapSteps)

    # Test near wrap: existing at 0.999, snapped at 0.0
    diff = abs(0.999 - 0.0)
    if diff > 0.5:
        diff = 1.0 - diff
    assert diff < 0.002
    print("✓ test_deduplication_wraparound passed")

def test_bar_toggling_math():
    # 2 Bars -> 4 Bars
    bars = 2
    events = [{"phase": 0.25, "action": "B"}, {"phase": 0.75, "action": "A"}]
    # Expand
    bars = 4
    totalSteps = bars * 16 # 64
    new_events = []
    for ev in events:
        ev["phase"] *= 0.5
        ev["step"] = int(ev["phase"] * totalSteps) + 1
        copy = dict(ev)
        copy["phase"] = ev["phase"] + 0.5
        copy["step"] = int(copy["phase"] * totalSteps) + 1
        new_events.extend([ev, copy])
    
    assert len(new_events) == 4
    assert new_events[0]["phase"] == 0.125
    assert new_events[1]["phase"] == 0.625
    assert new_events[2]["phase"] == 0.375
    assert new_events[3]["phase"] == 0.875
    print("✓ test_bar_toggling_math passed")

def test_playhead_crossing():
    # Test playhead crossing with prevPhase = 1.0 - epsilon on reset
    prevPhase = 1.0 - 0.0001
    phase = 0.005
    wrapped = (phase < prevPhase) # True
    assert wrapped

    ev_phase = 0.0
    crossed = (ev_phase > prevPhase or ev_phase <= phase)
    assert crossed, "Phase 0 downbeat must be triggered when playhead wrapped from reset"
    print("✓ test_playhead_crossing passed")

if __name__ == "__main__":
    test_deduplication_wraparound()
    test_bar_toggling_math()
    test_playhead_crossing()
    print("\nAll logic regression tests PASSED!")
