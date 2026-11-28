#!/usr/bin/env python3
"""Style the love.js dist-web output with the Pockimusi celestial dark shell."""
import pathlib
import re
import sys

CSS = r"""
* { box-sizing: border-box; }
html, body {
  margin: 0;
  padding: 0;
  min-height: 100%;
  background: radial-gradient(circle at 50% -10%, #1a1730 0%, #08080b 58%);
  color: #f2f5fc;
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
  -webkit-font-smoothing: antialiased;
}

/* Hide default love.js chrome */
body > center > h1,
body > center > footer,
footer { display: none !important; }

.pm-shell {
  max-width: 980px;
  margin: 0 auto;
  padding: 20px 16px 36px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
}

.pm-header {
  width: 100%;
  max-width: 820px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}

.pm-brand {
  display: flex;
  align-items: center;
  gap: 10px;
}
.pm-star {
  color: #5eead4;
  font-size: 20px;
  text-shadow: 0 0 12px rgba(94, 234, 212, 0.55);
}
.pm-title {
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 0.08em;
  margin: 0;
}
.pm-sub {
  font-size: 12px;
  color: #9a98ae;
  margin-left: 6px;
}

.pm-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}
.pm-btn {
  appearance: none;
  border: 1px solid #2a2a35;
  background: #111116;
  color: #f2f5fc;
  padding: 7px 13px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
  text-decoration: none;
  cursor: pointer;
  transition: border-color 0.15s, background 0.15s;
}
.pm-btn:hover {
  border-color: #5eead4;
  background: #171721;
}
.pm-btn-accent {
  border-color: rgba(94, 234, 212, 0.5);
  background: rgba(94, 234, 212, 0.12);
  color: #5eead4;
}

.pm-bezel {
  width: 100%;
  max-width: 820px;
  background: #0d0d12;
  border: 1px solid #2a2a35;
  border-radius: 16px;
  padding: 12px;
  box-shadow: 0 24px 64px rgba(0, 0, 0, 0.65), 0 0 0 1px rgba(184, 155, 250, 0.08);
  display: flex;
  justify-content: center;
  align-items: center;
}

#canvas, #loadingCanvas {
  display: block;
  width: 100% !important;
  height: auto !important;
  max-width: 796px;
  aspect-ratio: 4 / 3;
  border-radius: 8px;
  background: #08080b;
  image-rendering: pixelated;
  outline: none;
}

.pm-notice {
  width: 100%;
  max-width: 820px;
  background: #111116;
  border: 1px solid #2a2a35;
  border-left: 3px solid #fcd34d;
  border-radius: 10px;
  padding: 10px 14px;
  font-size: 13px;
  line-height: 1.45;
  color: #c8c6d8;
}
.pm-notice strong { color: #fcd34d; }
.pm-notice a { color: #5eead4; text-decoration: none; border-bottom: 1px solid rgba(94, 234, 212, 0.4); }
.pm-notice a:hover { border-bottom-color: #5eead4; }

.pm-card {
  width: 100%;
  max-width: 820px;
  background: #111116;
  border: 1px solid #2a2a35;
  border-radius: 12px;
  padding: 14px 16px;
}
.pm-card-head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
}
.pm-card-title {
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.1em;
  color: #b89bfa;
  text-transform: uppercase;
}
.pm-card-hint {
  font-size: 12px;
  color: #9a98ae;
}
.pm-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 8px 14px;
  font-size: 12px;
}
.pm-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 5px 8px;
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.025);
}
.pm-row span:first-child { color: #9a98ae; }
.pm-kbd {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 11px;
  color: #f2f5fc;
  background: #1b1b24;
  border: 1px solid #2f2f3f;
  border-radius: 5px;
  padding: 2px 6px;
}
"""

SHELL_TOP = r"""
<div class="pm-shell">
  <header class="pm-header">
    <div class="pm-brand">
      <span class="pm-star">✦</span>
      <h1 class="pm-title">POCKIMUSI</h1>
      <span class="pm-sub">Pockimusi · Browser Preview</span>
    </div>
    <div class="pm-actions">
      <button class="pm-btn" type="button" onclick="pmFullscreen()">Fullscreen</button>
      <a class="pm-btn pm-btn-accent" href="https://github.com/nowitstime/pockimusi/releases" target="_blank" rel="noopener">Download Native</a>
      <a class="pm-btn" href="https://github.com/nowitstime/pockimusi" target="_blank" rel="noopener">GitHub</a>
    </div>
  </header>
  <div class="pm-bezel" id="pmBezel">
"""

SHELL_BOTTOM = r"""
  </div>

  <div class="pm-notice">
    <strong>Browser Audio Note:</strong>
    Per-track effects (Tone, HPF, Radio, Chorus, Flange, Ring, Echo, Space, Punch) require native OpenAL EFX and are disabled in WebAudio.
    Click the screen once to wake audio, or
    <a href="https://github.com/nowitstime/pockimusi/releases" target="_blank" rel="noopener">download a native build</a>
    (Windows, Linux / Steam Deck, macOS, PortMaster) for the full engine.
  </div>

  <section class="pm-card">
    <div class="pm-card-head">
      <span class="pm-card-title">Controls (Gamepad Plug-and-Play or Keyboard)</span>
      <span class="pm-card-hint">Click the screen to focus keyboard input</span>
    </div>
    <div class="pm-grid">
      <div class="pm-row"><span>D-Pad</span><span class="pm-kbd">W A S D</span></div>
      <div class="pm-row"><span>Face (B A Y X)</span><span class="pm-kbd">J K U I / Arrows</span></div>
      <div class="pm-row"><span>Shoulders (L1 / R1)</span><span class="pm-kbd">Q / E</span></div>
      <div class="pm-row"><span>Record (L2)</span><span class="pm-kbd">Shift</span></div>
      <div class="pm-row"><span>Live FX / Mutes (R2)</span><span class="pm-kbd">Space</span></div>
      <div class="pm-row"><span>Track / Sound (SELECT)</span><span class="pm-kbd">Tab</span></div>
      <div class="pm-row"><span>Play / Clock (START)</span><span class="pm-kbd">Enter</span></div>
      <div class="pm-row"><span>Mix / Erase</span><span class="pm-kbd">Tab+Space / Shift+Space</span></div>
    </div>
  </section>
</div>

<script>
function pmFullscreen() {
  var el = document.getElementById("canvas") || document.getElementById("pmBezel");
  if (el && el.requestFullscreen) el.requestFullscreen();
}
// Keep Tab, Space, and Arrow keys inside the groovebox instead of scrolling/focusing the browser
window.addEventListener("keydown", function(e) {
  if (["Tab", "Space", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].indexOf(e.code) !== -1) {
    e.preventDefault();
  }
}, { passive: false });
</script>
"""


def main():
    dist = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "dist-web")
    theme_dir = dist / "theme"
    theme_dir.mkdir(parents=True, exist_ok=True)
    (theme_dir / "love.css").write_text(CSS.strip() + "\n", encoding="utf-8")

    index_path = dist / "index.html"
    html = index_path.read_text(encoding="utf-8")

    # Remove love.js's default <h1> and <footer> inside <center>
    html = re.sub(r"<h1[^>]*>.*?</h1>", "", html, flags=re.IGNORECASE | re.DOTALL)
    html = re.sub(r"<footer[^>]*>.*?</footer>", "", html, flags=re.IGNORECASE | re.DOTALL)

    # Wrap the canvases inside our bezel shell
    m_open = re.search(r"<body[^>]*>", html, flags=re.IGNORECASE)
    m_script = re.search(r"<script\b", html[m_open.end():] if m_open else html, flags=re.IGNORECASE)
    if m_open and m_script:
        body_start = m_open.end()
        script_pos = body_start + m_script.start()
        canvas_chunk = html[body_start:script_pos]
        # Strip <center> wrappers around the canvases
        canvas_chunk = re.sub(r"</?center[^>]*>", "", canvas_chunk, flags=re.IGNORECASE)
        canvas_chunk = re.sub(r"<div[^>]*>", "", canvas_chunk, flags=re.IGNORECASE)
        canvas_chunk = re.sub(r"</div>", "", canvas_chunk, flags=re.IGNORECASE)
        html = html[:body_start] + SHELL_TOP + canvas_chunk + SHELL_BOTTOM + html[script_pos:]
    index_path.write_text(html, encoding="utf-8")
    print("Styled", index_path)


if __name__ == "__main__":
    main()
