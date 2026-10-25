"""Builds the music system study guide: a PDF explaining the game's audio,
opening with a mind-map and with room to write notes.

    python3 docs/music-system/build_guide.py

Built with the explain-pdf skill's library (.claude/skills/explain-pdf).
Writes music-system-guide.pdf beside this script, and a copy named
<project-slug>-music-system-<timestamp>.pdf for the Drive "Books" folder
into the directory given as the first argument, if any.
"""

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / ".claude/skills/explain-pdf/scripts"))

from explainer import *  # noqa: E402,F403

OUT = Path(__file__).with_name("music-system-guide.pdf")


def big_picture():
    w, h = FRAME_W, 300
    d = Drawing(w, h)
    # Autoloads row
    caption(d, 0, h - 10, "AUTOLOADS  (live for the whole game, created in project.godot order)",
            font="Sans-Bold", color=ACCENT)
    names = [
        ("AudioManager", ["buses, loops, tempo,", "MusicTimeSource, LevelMeter"]),
        ("TempoControl", ["↑↓ ±2 bpm, ←→ ±10", "→ AudioManager.set_bpm"]),
        ("Tank", ["the one fluid tank", "acquire()/release()"]),
        ("SaveManager", ["persists bus volume", "and mutes"]),
    ]
    bw = (w - 3 * 8) / 4
    for i, (n, ls) in enumerate(names):
        box(d, i * (bw + 8), h - 60, bw, 42, n, ls)
    # Scene stack
    caption(d, 0, h - 76, "SCENE TREE  (what the player is in after the splash)", font="Sans-Bold",
            color=ACCENT)
    box(d, 0, h - 120, 120, 36, "DemoMenu", ["never freed; Backspace", "close_demo() → stop_loops"],
        fill=FILL_GREY, stroke=MUTED)
    box(d, 135, h - 120, 130, 36, "FluidCarousel", ["swipes between levels,", "owns SharedLayers"],
        fill=FILL_GREY, stroke=MUTED)
    arrow(d, 120, h - 102, 135, h - 102)
    box(d, 280, h - 150, w - 280, 66, "SharedLayers  (the host, outlives levels)", [
        "fluid  ← Tank.acquire(self)",
        "band   = Band.new(); band.start()   ← the music",
        "KeyPrint · KeyScaleButtons · SongShake",
        "stage  ← levels are instanced under here",
    ], fill=FILL_GREEN, stroke=GREEN)
    arrow(d, 265, h - 102, 280, h - 102)
    # Band
    box(d, 0, h - 220, 200, 82, "Band  (core/audio/band.gd)", [
        "StepClock → _on_step(index, bar, step_in_bar)",
        "SongWalker: section/chord per bar",
        "Synths: bass · pads · arp · melody",
        "DrumKit: beat · ghost · shimmer (+fill)",
        "wants_part() latched once per bar",
        "key offset · scale · next_song()",
    ], fill=FILL_GREEN, stroke=GREEN)
    arrow(d, 330, h - 150, 200, h - 175, color=GREEN, label="owns", label_dy=4)
    # Levels
    lw = (w - 220 - 16) / 3
    lv = [
        ("Eye band", ["EyeBand = contacts", "→ set_part_wanted", "every frame"]),
        ("Spout", ["wants every part", "pin + echo Synths", "follows key_changed"]),
        ("Boids", ["boatmen or birds", "3 voice Synths + snare", "own 12-step grid"]),
    ]
    for i, (n, ls) in enumerate(lv):
        box(d, 220 + i * (lw + 8), h - 220, lw, 50, n, ls, fill=FILL_WARM, stroke=WARM)
    caption(d, 220, h - 232, "levels: one at a time (two while sliding, both frozen); their",
            size=6.4)
    caption(d, 220, h - 241, "Synths and players also play on the Music bus", size=6.4)
    arrow(d, 400, h - 150, 400, h - 168, color=GREEN)
    # bottom: audio server
    box(d, 0, 10, w, 46, "AudioServer  (Godot engine, audio thread)", [
        "Music bus [Chorus, Reverb — added by Band]  → Master",
        "SFX bus [AudioManager.play_sfx pool] → Master [Capture → HardLimiter −0.3 dBFS] → driver → device",
    ], fill=FILL_GREY, stroke=MUTED)
    arrow(d, 100, h - 220, 100, 56, color=MUTED, label="AudioStreamPlayers on Music", label_dx=55)
    return d


def bus_graph():
    w, h = FRAME_W, 330
    d = Drawing(w, h)
    sx, sw = 0, 168
    sources = [
        ("Band · Synth ×4", ["bass 4v SAW · pads 16v SQUARE", "arp 4v SINE · melody 2v SQUARE",
                             "each voice = 1 AudioStreamPlayer"], FILL_GREEN, GREEN),
        ("Band · DrumKit", ["8 AudioStreamPlayers, one-shots", "beat −6 dB · ghost −8 · shimmer −9"],
         FILL_GREEN, GREEN),
        ("BoidsLevel", ["3 Synths (sine/square/saw), 12v", "6 players: snare, ghost, kick, crash"],
         FILL_WARM, WARM),
        ("Spout", ["PinField Synth, PinEcho Synth"], FILL_WARM, WARM),
        ("AudioManager", ["MusicPlayer · LoopPlayer", "(LoopPlayer: empty sync stream)"],
         FILL_BLUE, ACCENT),
        ("AudioManager SFX pool", ["SfxPlayer0..7, round robin", "(play_sfx; demos only)"],
         FILL_BLUE, ACCENT),
    ]
    bh, gap = 42, 9
    top = h - 8
    ys = []
    for i, (n, ls, f, s) in enumerate(sources):
        y = top - (i + 1) * bh - i * gap
        box(d, sx, y, sw, bh, n, ls, fill=f, stroke=s)
        ys.append(y + bh / 2)
    # Buses
    mx, mw = 210, 120
    box(d, mx, 170, mw, 110, "Music bus", [
        "volume_db (saved, linear→dB)",
        "mute (saved)",
        "effects added at runtime",
        "by Band._add_space():",
        "  0 Chorus (wet 0.35)",
        "  1 Reverb (room 0.85,",
        "     wet 0.28, dry 0.9)",
    ], fill=FILL_GREY, stroke=INK)
    box(d, mx, 40, mw, 60, "SFX bus", ["volume_db, mute (saved)", "no effects"], fill=FILL_GREY,
        stroke=INK)
    for y in ys[:5]:
        arrow(d, sw, y, mx, 225, color=MUTED, width=0.6)
    arrow(d, sw, ys[5], mx, 70, color=MUTED, width=0.6)
    # Master
    ax, aw = 370, w - 370
    box(d, ax, 120, aw, 110, "Master bus", [
        "effect 0: AudioEffectCapture",
        "   'LevelMeter', 0.5 s buffer",
        "effect 1: AudioEffectHardLimiter",
        "   ceiling −0.3 dBFS",
        "focus loss → mute (if enabled)",
    ], fill=FILL_GREY, stroke=INK)
    arrow(d, mx + mw, 225, ax, 190, label="send", label_dy=5)
    arrow(d, mx + mw, 70, ax, 150, label="send", label_dy=-10)
    # driver/device
    box(d, ax, 20, aw, 70, "Driver → device", [
        "mixed in blocks (~512 frames)",
        "+ output latency (driver buffer)",
        "speakers / headphones /",
        "Bluetooth (adds 100+ ms)",
    ], fill=FILL_WARM, stroke=WARM)
    arrow(d, ax + aw / 2, 120, ax + aw / 2, 90)
    # meter
    box(d, ax, 250, aw, 66, "LevelMeter (child of AM)", [
        "drain_master_peak() each frame",
        "→ ClipWatch groups overs",
        "→ '[level] OVER …' log lines",
        "F8: LevelMeterOverlay",
    ], fill=FILL_BLUE, stroke=ACCENT)
    arrow(d, ax + aw / 2, 230, ax + aw / 2, 250, color=ACCENT, label="reads capture", label_dx=30)
    return d


def lifecycle():
    w, h = FRAME_W, 360
    d = Drawing(w, h)
    steps = [
        ("1 · Engine boot", "Autoloads enter the tree: UiLook, EventBus, GameState, AudioManager,",
         "TempoControl, SaveManager, ComfortSettings, Tank. AudioManager._ready builds its players,"
         " loads saved volumes, finds the Master capture, adds LevelMeter.", FILL_BLUE, ACCENT),
        ("2 · Splash", "main_scene = splash.tscn. Tank.acquire(splash) starts THE tank and prints",
         "the logo into it. No music yet. It hands over to DemoMenu with the carousel open.",
         FILL_GREY, MUTED),
        ("3 · Carousel opens", "DemoMenu.open_demo(carousel) → FluidCarousel._ready → SharedLayers.new().",
         "SharedLayers._ready: Tank.acquire(self); Band.new(); KeyPrint; band.start(); buttons; Stage.",
         FILL_GREEN, GREEN),
        ("4 · Band.start()", "pick song → build Synths + DrumKit → add Chorus+Reverb to Music →",
         "set_tempo(song) → configure_loop_layers([]) → play_loops() (starts WallClockMusicTime) → StepClock.",
         FILL_GREEN, GREEN),
        ("5 · Level arrives", "level scene instanced under stage. _ready: SharedLayers.host_of(self),",
         "take fluid + band, build its own instruments (Boids: 3 Synths + 6 players), set wanted parts.",
         FILL_WARM, WARM),
        ("6 · Each frame", "AudioManager._process (loop layer scheduler) → Band's StepClock fires due steps →",
         "Band._on_step plays notes → level _process (Boids: own sequencer) → SynthVoice envelopes.",
         FILL_WARM, WARM),
        ("7 · Swipe", "next level instanced FROZEN; both slide 1.4 s; outgoing freed (its _exit_tree",
         "releases its synths). Band, clock and tank never stop.", FILL_WARM, WARM),
        ("8 · Back to menu", "Carousel freed → Band._exit_tree: stop_loops (clock stops), release_all,",
         "kit.stop_all, remove bus effects. DemoMenu.close_demo also calls stop_loops. Tank sleeps.",
         FILL_GREY, MUTED),
    ]
    bh, gap = 36, 8
    y = h - bh
    for i, (t, l1, l2, f, s) in enumerate(steps):
        d.add(Rect(0, y, w, bh, rx=3, ry=3, fillColor=f, strokeColor=s, strokeWidth=0.7))
        d.add(String(6, y + bh - 12, t, fontName="Sans-Bold", fontSize=8.2, fillColor=INK))
        ty = y + bh - 12
        for line in wrap_words(l1 + " " + l2, "Sans", 6.9, w - 116):
            d.add(String(110, ty, line, fontName="Sans", fontSize=6.9, fillColor=INK))
            ty -= 9.5
        if i < len(steps) - 1:
            arrow(d, 50, y, 50, y - gap + 1, color=MUTED, width=0.6)
        y -= bh + gap
    return d


def eye_timeline():
    w, h = FRAME_W, 150
    d = Drawing(w, h)
    x0, x1 = 30, w - 10
    bar_w = (x1 - x0) / 3
    yb = 70
    d.add(Line(x0, yb, x1, yb, strokeColor=INK, strokeWidth=1))
    for i in range(4):
        x = x0 + i * bar_w
        d.add(Line(x, yb - 8, x, yb + 8, strokeColor=INK, strokeWidth=1.2))
        caption(d, x, yb - 20, f"bar {i}", anchor="middle", color=INK)
        if i < 3:
            for s in range(1, 16):
                xs = x + s * bar_w / 16
                d.add(Line(xs, yb - 2.5, xs, yb + 2.5, strokeColor=RULE, strokeWidth=0.5))
    # eye touches wall
    xt = x0 + bar_w * 0.72
    arrow(d, xt, yb + 50, xt, yb + 6, color=WARM, label=None)
    caption(d, xt + 4, yb + 54, "eye rim < 10 px from wall → touching=true", color=WARM)
    caption(d, xt + 4, yb + 42, "eye_band_demo mirrors → set_part_wanted(part, false)", size=6.2)
    # part keeps playing until bar 1
    d.add(Rect(x0, yb + 12, bar_w, 8, fillColor=GREEN, strokeColor=None))
    caption(d, x0 + 4, yb + 24, "part plays on: ring red, countdown", size=6.4, color=GREEN)
    xl = x0 + bar_w
    caption(d, xl, yb - 32, "_latch_live_parts(): synth release_all / drums stop reading",
            color=INK, anchor="middle")
    # eye frees
    xf = x0 + bar_w * 1.8
    arrow(d, xf, yb + 50, xf, yb + 6, color=GREEN)
    caption(d, xf + 8, yb + 54, "eye > 40 px from every wall → touching=false", color=GREEN)
    d.add(Rect(x0 + 2 * bar_w, yb + 12, bar_w, 8, fillColor=GREEN, strokeColor=None))
    caption(d, x0 + 2 * bar_w + 4, yb + 24, "part back from bar 2", size=6.4, color=GREEN)
    caption(d, 0, 8, "Worst case wall→silence ≈ one bar: 4 beats × 60/88 bpm ≈ 2.7 s (Glass Tide).",
            color=MUTED)
    return d


def snare_chain():
    w, h = FRAME_W, 140
    d = Drawing(w, h)
    hops = [
        ("Press", ["finger on", "button"], FILL_GREY, MUTED),
        ("Device + OS", ["USB/BT poll,", "Steam Input", "remap"], FILL_WARM, WARM),
        ("Main loop", ["event waits for", "next frame's", "input flush"], FILL_WARM, WARM),
        ("_unhandled_input", ["player.play()", "tap(get_beats())"], FILL_GREEN, GREEN),
        ("Next mix block", ["play() takes", "effect here"], FILL_WARM, WARM),
        ("Driver buffer", ["output latency"], FILL_WARM, WARM),
        ("Ear", ["snare heard"], FILL_GREY, MUTED),
    ]
    n = len(hops)
    bw = (w - (n - 1) * 10) / n
    yb = 84
    for i, (t, ls, f, s) in enumerate(hops):
        x = i * (bw + 10)
        box(d, x, yb, bw, 52, t, ls, fill=f, stroke=s, title_size=7.2)
        if i < n - 1:
            arrow(d, x + bw, yb + 26, x + bw + 10, yb + 26)
    est = ["", "≈1–8 ms", "0–1 frame", "≈0", "0–1 block", "≈15 ms+", ""]
    for i, e in enumerate(est):
        x = i * (bw + 10) + bw / 2
        caption(d, x, yb - 12, e, anchor="middle", color=WARM, font="Sans-Bold", size=7.4)
    caption(d, 0, yb - 30, "1 frame = 16.7 ms @60 Hz (11.1 @90 Hz) · 1 mix block ≈ 10.7–11.6 ms "
            "(512 frames @48/44.1 kHz)", size=6.4)
    caption(d, 0, yb - 39, "Output latency: Godot asks the driver for 15 ms by default; the real "
            "figure is whatever the driver reports.", size=6.4)
    caption(d, 0, yb - 51, "None of these hops is compensated for the live snare — it cannot be: "
            "nobody knows a press is coming. Wired total ≈ 20–50 ms; Bluetooth adds 100–250 ms.",
            size=6.4, color=INK)
    caption(d, 0, yb - 63, "The tap's position is read at the green box, so it is late by the two "
            "hops before it (device + frame wait) — that is what tap_offset_seconds is for.",
            size=6.4, color=INK)
    return d


def scheduled_timeline():
    w, h = FRAME_W, 205
    d = Drawing(w, h)
    x0 = 20
    scale = (w - 40) / 70.0  # 70 ms across

    def X(ms):
        return x0 + ms * scale

    # Rows
    rows = {"frames": 165, "mix": 120, "speaker": 70}
    caption(d, 0, rows["frames"] + 14, "main thread frames (60 Hz)", font="Sans-Bold", color=INK)
    caption(d, 0, rows["mix"] + 14, "audio mix blocks (~11.6 ms)", font="Sans-Bold", color=INK)
    caption(d, 0, rows["speaker"] + 14, "at the speaker (mix + output latency ≈ 15 ms)",
            font="Sans-Bold", color=INK)
    for r in rows.values():
        d.add(Line(X(0), r, X(70), r, strokeColor=RULE, strokeWidth=0.8))
    for k in range(5):
        t = k * 16.7
        d.add(Line(X(t), rows["frames"] - 6, X(t), rows["frames"] + 6, strokeColor=INK, strokeWidth=1))
        caption(d, X(t), rows["frames"] - 15, f"F{k}", anchor="middle")
    for k in range(6):
        t = 3 + k * 11.6
        d.add(Line(X(t), rows["mix"] - 5, X(t), rows["mix"] + 5, strokeColor=MUTED, strokeWidth=0.8))
    # Grid step due at speaker time 44 ms
    due = 44
    d.add(Line(X(due), 30, X(due), rows["frames"] + 10, strokeColor=ACCENT, strokeWidth=0.8,
               strokeDashArray=[3, 2]))
    caption(d, X(due), 22, "grid step due (as heard)", anchor="middle", color=ACCENT,
            font="Sans-Bold")
    # Frame F1 at 16.7: horizon = now + ttnm + outlat. F1: next mix at 17.5ms (3+11.6+... ) compute
    f = 33.4
    next_mix = 37.8
    heard = next_mix + 15
    d.add(Rect(X(f), rows["frames"] - 3, X(next_mix) - X(f), 6, fillColor=FILL_WARM, strokeColor=WARM,
               strokeWidth=0.5))
    arrow(d, X(f), rows["frames"] - 8, X(next_mix), rows["mix"] + 6, color=WARM)
    caption(d, X(16.7) - 10, rows["frames"] + 22, "F1: now + time_to_next_mix + output_latency "
            "= 41 ms < due → wait", color=MUTED, size=6.6)
    caption(d, X(f) + 2, rows["frames"] + 12, "F2: horizon ≥ due → play() now", color=WARM,
            size=6.6)
    arrow(d, X(next_mix), rows["mix"] - 6, X(heard), rows["speaker"] + 6, color=WARM,
          label="output latency", label_dx=-28)
    d.add(Rect(X(heard) - 2, rows["speaker"] - 4, 4, 8, fillColor=WARM, strokeColor=None))
    caption(d, X(heard), rows["speaker"] - 15, "sound", anchor="middle", color=WARM)
    caption(d, X(heard) + 4, rows["speaker"] - 26, "≈ 9 ms late (at most ≈ 1 frame)",
            color=INK, size=6.6)
    caption(d, 0, 4, "The step fires on the first frame whose horizon has passed it, so it is heard "
            "0 … 1 frame late (never early). Synth notes add their own start-up — see below.",
            size=6.6, color=MUTED)
    return d


# ---------------------------------------------------------------- content


def build():
    s = []

    # ------------------------------------------------------------ cover
    s.append(Spacer(1, 22 * mm))
    s.append(P("The music system", ParagraphStyle("t", parent=h1, fontSize=28, leading=34)))
    s.append(P("A study guide to eyeMusic's audio: devices and buses, musical time, the Band and the "
               "Eye Band, how everything is born and torn down, and where latency comes from in the "
               "boids level.", ParagraphStyle("st", parent=body, fontSize=11.5, leading=16,
                                              textColor=MUTED)))
    s.append(Spacer(1, 8 * mm))
    s.append(table([
        ["§", "Section", "You will be able to answer"],
        ["0", "The concept at a glance", "The whole system on one page: a mind-map of the sections."],
        ["1", "The big picture", "Which object owns the music, and which only borrow it?"],
        ["2", "Audio devices and connections", "Which player feeds which bus, what effects sit "
         "where, and what reaches the speakers?"],
        ["3", "Musical time", "Where 'now' comes from, how steps fire, and why tempo changes never jump."],
        ["4", "The Band", "What happens on every sixteenth, and what waits for a bar line."],
        ["5", "The Eye Band", "How an eye touching a wall becomes a part dropping out."],
        ["6", "Lifecycle", "When each piece is created, what keeps running across levels, "
         "what tears it down."],
        ["7", "Latency in the boids level", "Every hop between a press or a grid step and the ear, "
         "what is compensated and what is not."],
        ["8", "File map and glossary", "Where to look next."],
    ], [10 * mm, 48 * mm, FRAME_W - 58 * mm]))
    s.append(Spacer(1, 6 * mm))
    s.append(P("<b>How to use it.</b> Each section ends with a ruled box for your notes; the last pages are "
               "dot grid for sketches. File references are repo-relative paths — open them next to "
               "the guide. Numbers marked <i>measured</i> come from the repo's own READMEs; numbers "
               "marked <i>estimate</i> are typical values to verify on your device.", tip))
    s.append(P("Written from the code on branch <font name='Mono'>main</font> at commit 4d229f4 "
               "(Spout: one level, with bubbles…). Engine: Godot 4.4.", small))
    s.append(Spacer(1, 4 * mm))
    s.append(notes(8, "What I want to understand / questions before I start"))
    s.append(PageBreak())

    # ------------------------------------------------------------ mind-map
    s.append(P("The concept at a glance", h1))
    s.append(P("Everything in this guide hangs off one idea: a single band, kept on a single "
               "clock, that levels borrow. Read the map clockwise from the top; each branch is a "
               "section."))
    s.append(Spacer(1, 4))
    s.append(mind_map("The music system", [
        ("1 · Ownership", ["one Band, owned by SharedLayers", "levels borrow it",
                           "only AudioManager → AudioServer"]),
        ("2 · Devices & buses", ["players → Music / SFX", "Master: capture → limiter",
                                 "driver → speakers"]),
        ("3 · Musical time", ["MusicTimeSource (port)", "beats, not seconds",
                              "StepClock + lookahead"]),
        ("4 · The Band", ["7 parts: Synths + DrumKit", "steps play notes",
                          "parts latch per bar"]),
        ("5 · The Eye Band", ["one eye per part, by size", "wall contact silences",
                              "hysteresis 10 / 40 px"]),
        ("6 · Lifecycle", ["autoloads → splash → carousel", "band outlives levels",
                           "exit_tree tears down"]),
        ("7 · Boids latency", ["live snare: uncompensated", "grid notes: fire early",
                               "frame + start-up residue"]),
        ("8 · Where to look", ["file map", "glossary"]),
    ]))
    s.append(notes(10, "Notes — my own map: what connects to what?"))
    s.append(PageBreak())

    # ------------------------------------------------------------ 1 big picture
    s.append(P("1 · The big picture", h1))
    s.append(P("There is exactly <b>one</b> piece of music playing in the carousel: a "
               f"{C('Band')} owned by {C('SharedLayers')}, the host that every level is a foreground "
               "over. Levels never start a clock, set a tempo or add bus effects; they only "
               "<i>borrow</i> the band — choose which parts they want, move its key, follow its "
               "signals, and play their own notes on top in its key."))
    s.append(Spacer(1, 4))
    s.append(big_picture())
    s.append(P("Three rules that explain most of the design:", h3))
    s.append(B(f"<b>Only {C('AudioManager')} talks to {C('AudioServer')}.</b> Everyone else asks it to play, "
               "set a volume, add an effect, or tell them the time."))
    s.append(B(f"<b>Musical time is a port.</b> Everything rhythmic asks {C('AudioManager.get_music_time_source()')} "
               "for beats. Swap the adapter and the whole game's timing changes in one place."))
    s.append(B("<b>Musical position is beats, not seconds.</b> Tempo only changes how fast beats "
               "accumulate from now on, so a tempo nudge never moves the bar you are in."))
    s.append(notes(7))
    s.append(PageBreak())

    # ------------------------------------------------------------ 2 devices
    s.append(P("2 · Audio devices and connections", h1))
    s.append(P(f"Buses are not built in code. They come from {C('resources/audio/default_bus_layout.tres')}, "
               f"loaded by the project setting {C('audio/buses/default_bus_layout')}. Every sound in the "
               "levels is an <b>AudioStreamPlayer</b> (non-positional) on the <b>Music</b> bus — "
               "including the boids level's snare. SFX is only used by "
               f"{C('AudioManager.play_sfx')} (the audio demo)."))
    s.append(bus_graph())
    s.append(P("The signal path, end to end", h3))
    s.append(table([
        ["Stage", "What it is", "Where", "Notes"],
        ["Voice / hit", "SynthVoice: one AudioStreamPlayer playing an AudioStreamSynchronized of "
         "band-limited wavetable loops; pitch via pitch_scale, envelope via volume_db, set once per frame.",
         "core/audio/synth_voice.gd", "No per-sample script. Pitch/volume change once per mix block."],
        ["", "DrumKit hit: an AudioStreamPlayer playing a cached AudioStreamWAV one-shot "
         "(DrumSynth, rendered once per sample rate).", "core/audio/drum_kit.gd", "Pool of 8, steal oldest."],
        ["Music bus", "Chorus then Reverb, added by Band._add_space() when the band starts, "
         "removed in Band._exit_tree.", "core/audio/band.gd", "Bus volume/mute persisted by SaveManager."],
        ["Master", "Capture ('LevelMeter', 0.5 s) → HardLimiter (−0.3 dBFS).",
         "default_bus_layout.tres", "Limiter is a safety net; capture sees pre-limiter level."],
        ["Mix", "AudioServer mixes all buses on the audio thread, block by block.", "engine",
         "Script play() calls land on the next block."],
        ["Driver", "Platform driver (PulseAudio/PipeWire/ALSA on Linux & Deck, CoreAudio on iOS/macOS, "
         "WASAPI on Windows). Buffers before the DAC.", "engine",
         "Reported by AudioServer.get_output_latency()."],
        ["Device", "Speakers, headphones; Bluetooth adds its own codec buffer the engine cannot see.",
         "hardware", "iOS session category = 3 (Playback) in project.godot."],
    ], [22 * mm, 66 * mm, 40 * mm, FRAME_W - 128 * mm]))
    s.append(P("The AudioManager API you will actually use", h3))
    s.append(code_block(
        "AudioManager.set_bus_volume_linear(AudioManager.MUSIC_BUS, 0.7)  # 0..1, stored as dB\n"
        "AudioManager.set_bus_mute(AudioManager.SFX_BUS, true)\n"
        "var i := AudioManager.add_bus_effect(AudioManager.MUSIC_BUS, AudioEffectReverb.new())\n"
        "AudioManager.get_bus_effect(AudioManager.MUSIC_BUS, i)   # drive it, e.g. via ParameterFader\n"
        "AudioManager.get_music_time_source().get_beats()         # 'what time is it', in beats\n"
        "AudioManager.get_level_meter().set_note(\"level\", name)  # context for OVER logs"))
    s.append(B("<b>Focus mute:</b> losing window focus mutes Master (if "
               f"{C('mute_on_focus_loss')}), and restores exactly what was there before."))
    s.append(B("<b>Metering:</b> bus peak readings only show the latest block, so the meter drains the "
               "Master capture every frame instead. F8 toggles the overlay; "
               f"{C('scripts/deck.sh run NAME --meter')} starts with it on."))
    s.append(B("<b>Headroom:</b> seven parts at once sit about 3 dB under the groove demo's levels "
               f"({C('Band.PART_DB')}, {C('SynthPatch.level')} 0.15 default) so the limiter rarely works."))
    s.append(notes(7))
    s.append(PageBreak())

    # ------------------------------------------------------------ 3 time
    s.append(P("3 · Musical time", h1))
    s.append(P("Everything on the beat — the band's sixteenths, the boids' pulses, the ghost snares, "
               "loop layers switching on a bar — asks one object what time it is."))
    s.append(table([
        ["Piece", "Job", "Pure?"],
        ["MusicTimeSource (port)", "get_beats(), set_tempo_bpm(), get_lookahead(), start()/stop().",
         "interface"],
        ["WallClockMusicTime (adapter, in use)", "Integrates beats from Time.get_ticks_usec(), restarting "
         "the integration at every tempo change. Lookahead = time_to_next_mix + output_latency.", "no"],
        ["ScriptedMusicTime", "Beats moved by hand — tests.", "yes"],
        ["MusicClock", "beats → bar / beat-in-bar / step; seconds ↔ beats at a tempo. Replaced (not "
         "mutated) on every tempo change.", "yes"],
        ["StepSequencer", "Which steps are due by beats + lookahead, each once, in order. After a hitch, "
         "at most 4 overdue steps (MAX_CATCH_UP) — old ones are dropped.", "yes"],
        ["StepClock (Node)", "Calls the sequencer in _process and emits step(index, bar, step_in_bar).",
         "no"],
        ["LoopLayerScheduler", "Holds loop-layer on/off requests until the next bar line.", "yes"],
        ["TempoControl (autoload)", "Arrow keys / d-pad → AudioManager.set_bpm(), clamped 30–180.", "no"],
    ], [52 * mm, FRAME_W - 70 * mm, 18 * mm]))
    s.append(P("How a step fires", h3))
    s.append(code_block(
        "# StepClock.advance(), every frame\n"
        "beats     = source.get_beats()                       # wall clock, in beats\n"
        "lookahead = clock.beats_from_seconds(source.get_lookahead())\n"
        "for index in sequencer.update(beats, lookahead):     # steps with start <= beats+lookahead\n"
        "    step.emit(index, index / per_bar, index % per_bar)"))
    s.append(P("Why not the player's playback position?", h3))
    s.append(P("For a looping stream it wraps at the loop point, so a bar longer than the loop would "
               "never arrive. The wall clock climbs forever. The cost: the clock is not the audio "
               "device's clock, so it cannot be sample-accurate; it is corrected (not locked) with the "
               "lookahead. A sample-accurate adapter would be a new MusicTimeSource, not a rewrite."))
    s.append(P("Tempo changes", h3))
    s.append(P(f"{C('set_tempo_bpm')} snapshots the beats reached so far and restarts integration at the "
               "new rate, so position never jumps. Note-hold lengths are wall seconds computed at "
               "note-on time, so a note already sounding keeps the length it started with."))
    s.append(notes(7))
    s.append(PageBreak())

    # ------------------------------------------------------------ 4 band
    s.append(P("4 · The Band", h1))
    s.append(P(f"{C('core/audio/band.gd')} plays one of {C('EyeBandSongs')}' four songs live. A "
               f"{C('Song')} is data: sections of chord symbols, each listing which sections may follow "
               f"(weighted). {C('SongWalker')} lays the path bar by bar, seeded."))
    s.append(table([
        ["Part", "Instrument", "Patch (wave · attack · release · level · voices)", "Plays"],
        ["beat", "DrumKit", "−6 dB", "song's beat pattern; fill over it on a section's last bar"],
        ["bass", "Synth", "SAW · 5 ms · 80 ms · 0.16 · 4", "bass_line symbols R/O/5/3 on the chord"],
        ["pads", "Synth", "SQUARE · 600 ms · 1.4 s · 0.045 · 16", "close voicing, re-voiced on chord change"],
        ["melody", "Synth", "SQUARE · 80 ms · 500 ms · 0.05 · 2 (glide 60 ms)", "MelodyWriter, per section"],
        ["arp", "Synth", "SINE · 5 ms · 300 ms · 0.07 · 4", "arp_pattern index into chord tones"],
        ["ghost", "DrumKit", "−8 dB", "ghost-note drum pattern"],
        ["shimmer", "DrumKit", "−9 dB", "hats/shimmer pattern"],
    ], [16 * mm, 20 * mm, 70 * mm, FRAME_W - 106 * mm]))
    s.append(Spacer(1, 4))
    s.append(P("What happens on each step — Band._on_step(index, bar, step_in_bar)", h3))
    s.append(code_block(
        "if bar changed:\n"
        "    swap in next_song if one is waiting      # song changes land on a bar line\n"
        "    _latch_live_parts()                      # wants_part(part) → _playing[part]\n"
        "    fill_active = last bar of section and beat is playing\n"
        "chord = walker.chords_at(bar) → chord_in_bar(step) → transposed(key_offset)\n"
        "_play_drums(step)                            # DrumKit.play(hit, velocity, PART_DB)\n"
        "pads on chord change · bass · arp · melody   # Synth.note_on + SceneTreeTimer for note_off\n"
        "stepped.emit(bar, step_in_bar)               # levels follow this"))
    s.append(P("What waits for what", h3))
    s.append(table([
        ["Change", "Takes effect", "Why"],
        ["A part wanted on/off", "next bar line", "_latch_live_parts runs once per bar, so parts enter "
         "and leave together and on the beat."],
        ["Key offset (Q/E, Z/X, corner buttons)", "next step; pads at once", "chords are read every step; "
         "_revoice_pads crossfades so the old key doesn't ride out a bar."],
        ["Scale (scale ▸)", "immediately, for levels", "the levels' palette (flock voices, spout pins), "
         "not the song's chords."],
        ["Next song (shake)", "next bar line", "_swap_song: new walker, patches, drum patterns, set_bpm."],
        ["Tempo (arrows)", "immediately (rate)", "beats integrate at the new rate; hold lengths of "
         "sounding notes stay."],
    ], [48 * mm, 34 * mm, FRAME_W - 82 * mm]))
    s.append(P(f"Signals to follow the band: {C('song_started(title)')}, {C('key_changed(offset)')}, "
               f"{C('scale_changed(name)')}, {C('stepped(bar, step_in_bar)')}.", small))
    s.append(notes(6))
    s.append(PageBreak())

    # ------------------------------------------------------------ 5 eye band
    s.append(P("5 · The Eye Band", h1))
    s.append(P("Seven floaty eyes drift on the tank's fluid. Each plays one part of the band — biggest "
               "eye the beat, then bass, pads, melody, arp, ghost, and the smallest the shimmer — and a "
               "part plays only while its eye keeps clear of the tank walls. The music is the reward "
               "for an arrangement you hold against a drifting medium."))
    s.append(P("Who does what", h3))
    s.append(table([
        ["Object", "Role"],
        ["EyeBand (features/levels/secret_eyes/eye_band.gd)", "extends Band but is <b>never started</b> "
         "in the carousel. Used only for contacts: binds eyes, gives parts by size "
         "(parts_by_size), measures wall clearance every frame with hysteresis, and answers wants_part()."],
        ["eye_band_demo.gd (the level)", "builds eyes, floaters, MotionInput, FluidMotionDriver; every "
         "frame mirrors _contacts.wants_part(part) into the host band's set_part_wanted(); draws rings "
         "(bright = playing, red = touching, faint = silent, countdown arc = pending)."],
        ["Band (the host's)", "actually makes the sound; latches the wants at each bar line."],
        ["KeyShiftInput", "L1/R1 (Q/E) ±4th, L2/R2 (Z/X) ±5th → band.set_key_offset()."],
    ], [62 * mm, FRAME_W - 62 * mm]))
    s.append(P("From touching a wall to silence", h3))
    s.append(eye_timeline())
    s.append(B(f"<b>Hysteresis:</b> touching starts within {C('touch_px')} = 10 px of the rim and ends "
               f"only past {C('release_px')} = 40 px, so an eye bobbing at the edge does not stutter."))
    s.append(B(f"<b>Clearance:</b> {C('wall_clearance(pos, radius, tank)')} = distance to the nearest of "
               "the four walls minus the radius; negative once the rim pokes past."))
    s.append(B(f"<b>Centre pull:</b> {C('CENTRE_PULL')} = 0.1 keeps eyes from random-walking onto walls "
               "within ~10 s — chosen by ear to keep the band playing take some effort."))
    s.append(B("<b>Latency here is musical, by design:</b> up to a bar between the eye touching and the "
               "part dropping. It is the bar latch, not audio latency."))
    s.append(notes(6))
    s.append(PageBreak())

    # ------------------------------------------------------------ 6 lifecycle
    s.append(P("6 · Lifecycle of the components", h1))
    s.append(P("The music outlives levels. It starts when the carousel's host is built, keeps running "
               "through every swipe, and stops only when the carousel leaves the tree."))
    s.append(Spacer(1, 6))
    s.append(lifecycle())
    s.append(Spacer(1, 6))
    s.append(table([
        ["Component", "Created by / when", "Lives until", "Torn down by"],
        ["AudioManager + players, LevelMeter", "autoload, engine boot", "game quits", "—"],
        ["MusicTimeSource (WallClock)", "AudioManager field", "game quits; running only between "
         "play_loops() and stop_loops()", "stop_loops()"],
        ["Tank (fluid)", "first Tank.acquire() — the splash", "game quits; sleeps when nobody holds it",
         "release() / holder leaving tree"],
        ["SharedLayers", "FluidCarousel._ready", "carousel freed", "tree"],
        ["Band, its StepClock, Synths, DrumKit", "SharedLayers._ready → band.start()", "carousel freed",
         "Band._exit_tree: stop_loops, release_all, stop_all, remove effects"],
        ["Music bus Chorus + Reverb", "Band._add_space()", "band exits", "remove_bus_effect (reverse order)"],
        ["A level (eyes / spout / boids)", "carousel instances it under stage", "next swipe completes",
         "_arrive → queue_free; its _exit_tree releases its synths"],
        ["Boids Synths + one-shot players", "BoidsLevel.start() → _build_audio()", "level freed",
         "children of the level"],
        ["EyeBand contacts", "eye_band_demo._ready", "level freed", "child of the level"],
        ["Note-off timers", "every note_on (SceneTreeTimer)", "fires once", "skipped if the voice was "
         "retriggered (started_usec check)"],
    ], [44 * mm, 44 * mm, 44 * mm, FRAME_W - 132 * mm]))
    s.append(P("Per-frame order matters", h3))
    s.append(P("Godot processes nodes in tree order: autoloads first (AudioManager), then the current "
               "scene. Inside SharedLayers the Band (and its StepClock) comes before Stage, so in a frame "
               "the band's steps fire <i>before</i> the level's own _process. SynthVoice envelopes move in "
               "their own _process. Levels sliding in are PROCESS_MODE_DISABLED until they arrive, so a "
               "level's own notes are silent during a slide while the band plays on.", body))
    s.append(notes(6))
    s.append(PageBreak())

    # ------------------------------------------------------------ 7 latency
    s.append(P("7 · Latency in the boids level", h1))
    s.append(P(f"{C('features/levels/boids/boids_level.gd')} has four kinds of sound, and they travel "
               "two different kinds of path:"))
    s.append(table([
        ["Sound", "Triggered by", "Path", "Compensated?"],
        ["Flock pulses (bird voices)", "BoidsLevel._play_due → own StepSequencer on a 12-step grid",
         "Synth.note_on → SynthVoice", "Yes: fires early by mix + output latency"],
        ["Ghost snare", "_play_due when beats + lookahead ≥ ghost", "one-shot AudioStreamPlayer",
         "Yes, same lookahead"],
        ["The band under it", "Band's StepClock (16-step grid)", "Synth / DrumKit", "Yes, same lookahead"],
        ["Live snare", "_unhandled_input on press", "one-shot AudioStreamPlayer", "No — can't be"],
        ["Scatter crash + kick", "ScatterCharge fills in _process", "one-shot", "No (not on the grid)"],
    ], [36 * mm, 56 * mm, 42 * mm, FRAME_W - 134 * mm]))
    s.append(P("A. The live snare: press → ear", h2))
    s.append(snare_chain())
    s.append(P("B. Scheduled sounds: grid step → ear", h2))
    s.append(scheduled_timeline())
    s.append(notes(4, "Notes — snare vs scheduled sounds"))
    s.append(PageBreak())

    s.append(P("The latency budget, hop by hop", h2))
    s.append(table([
        ["#", "Source", "Size", "Hits", "Compensated by", "Where in code"],
        ["1", "Input device + OS (USB/BT poll, Steam Input desktop-layout remap on the Deck)",
         "≈1–8 ms (estimate; BT pads more)", "snare, tap reading", "—", "outside the game"],
        ["2", "Waiting for the next main-loop iteration to deliver the event (input is flushed once per "
         "frame)", "0–1 frame (0–16.7 ms @60 Hz)", "snare, tap reading", "—",
         "engine; _unhandled_input"],
        ["3", "Frame quantisation of scheduled events: a step is noticed on the first frame whose horizon "
         "has passed it", "0–1 frame, always late", "flocks, ghosts, band", "— (lookahead cannot remove it)",
         "StepSequencer.update / _play_due"],
        ["4", "play() only starts at the next mix block", "0–1 block (≈10.7–11.6 ms)", "everything",
         "get_time_to_next_mix() in lookahead (scheduled only)", "WallClockMusicTime.get_lookahead"],
        ["5", "Driver output buffer, mix → DAC", "≈15 ms requested (driver decides)", "everything",
         "get_output_latency() in lookahead (scheduled only)", "use_output_latency_compensation"],
        ["6", "SynthVoice start-up: the envelope holds at silence until a _process frame sees "
         "get_playback_position() > 0, then ramps over the attack (4 ms for birds)",
         "≈0–1 frame + attack (hypothesis — measure)", "bird voices, band synth parts on idle voices",
         "—", "SynthVoice.advance (_awaiting_start)"],
        ["7", "Device/hardware beyond the driver (DAC, Bluetooth codec)", "≈1 ms wired; 100–250 ms BT",
         "everything", "— (engine can't see it)", "outside the game"],
        ["8", "Human: hearing a pulse and pressing", "varies", "tap reading",
         "tap_offset_seconds (0 until measured)", "BoidsLevel._unhandled_input"],
    ], [6 * mm, 52 * mm, 28 * mm, 24 * mm, 32 * mm, FRAME_W - 142 * mm]))
    s.append(P("Reading the table", h3))
    s.append(B("<b>Scheduled sounds</b> (flocks, ghosts, band) cancel hops 4 and 5 by firing early, "
               "leaving hop 3 (0–1 frame late) and, for synth voices, hop 6. Relative to each other "
               "they stay tight, because all three use the same clock and lookahead."))
    s.append(B("<b>The live snare</b> pays hops 1, 2, 4, 5 and 7 in full: roughly 20–50 ms wired "
               "(estimate). It therefore lands audibly behind a perfectly-timed flock pulse that was "
               "compensated."))
    s.append(B("<b>The tap's position</b> is read at hop 2's end via "
               f"{C('get_beats() + tap_offset_seconds / seconds_per_beat')}. Since the flocks are "
               "compensated to be heard on the grid, a tap in time with what you hear registers late by "
               f"hops 1–2. To cancel that, {C('tap_offset_seconds')} would be <b>negative</b> (≈ −(device + "
               "frame wait))."))
    s.append(B("<b>Ghost snares are compensated</b> and use a plain one-shot player, so the ghost is "
               "the tightest sound the player hears about their own playing."))
    s.append(P("Known measurements (core/audio/README.md)", h3))
    s.append(B("Script-triggered sixteenths at 120 bpm: 17.7 ms spread on 512-sample block boundaries; "
               "10.3 ms with time-to-next-mix lookahead (<i>measured</i>)."))
    s.append(B("Live synth notes vs a rendered loop, before output-latency compensation: 16–20 ms "
               "behind, ~10 ms spread (<i>measured</i>). On the Deck this was a steady lag (#78), which led "
               "to adding get_output_latency() to the lookahead — still to be re-measured by ear on the "
               "Deck."))
    s.append(P("<b>Worth checking:</b> hop 6 may account for part of the old 16–20 ms synth lag that "
               "output-latency compensation does not remove — the DrumKit path has no start-up wait, the "
               "SynthVoice path does. Compare a ghost snare against a bird voice on the same pulse: if the "
               "voice lands consistently later, hop 6 is real.", callout))
    s.append(CondPageBreak(80 * mm))
    s.append(P("How to measure on a device", h3))
    s.append(B("Loopback: record the device's output with a mic next to a button press (a click you can "
               "hear and see in the waveform), read press → snare onset. That is the full snare chain."))
    s.append(B("Print AudioServer.get_output_latency() and get_time_to_next_mix() on the Deck; compare "
               "with the requested 15 ms."))
    s.append(B("Tap along to a 4-flock for a minute and log reader.quantise() errors: their mean is "
               "your tap_offset_seconds (with sign)."))
    s.append(B(f"Try {C('Engine.max_fps')} / vsync off, and 90 Hz on an OLED Deck: hops 2, 3 and 6 shrink "
               "with the frame time."))
    s.append(notes(8, "Notes — my latency measurements"))
    s.append(PageBreak())

    # ------------------------------------------------------------ 8 file map
    s.append(P("8 · File map and glossary", h1))
    s.append(table([
        ["File", "What to look for"],
        ["autoload/AudioManager.gd", "players, bus API, loop stack, time source, set_tempo/set_bpm"],
        ["autoload/TempoControl.gd", "live tempo keys"],
        ["resources/audio/default_bus_layout.tres", "Master/Music/SFX, capture + limiter"],
        ["core/audio/time/…", "MusicTimeSource, WallClockMusicTime (lookahead), ScriptedMusicTime"],
        ["core/audio/music_clock.gd, step_sequencer.gd, step_clock.gd", "beats → steps; firing steps"],
        ["core/audio/band.gd", "the band: parts, _on_step, latching, key, scale, next_song"],
        ["core/audio/synth*.gd", "Synth pool, SynthVoice (envelope, start-up wait), wavetables"],
        ["core/audio/drum_kit.gd, drum_synth.gd, step_pattern.gd", "live drums and notation"],
        ["core/audio/song.gd, song_walker.gd, chord.gd, melody_writer.gd", "songs as data"],
        ["core/audio/level_meter.gd, clip_watch.gd", "overs and headroom logs"],
        ["core/audio/rhythm/…", "Rhythm, RhythmTable, TapReader (boids)"],
        ["features/levels/carousel/shared_layers.gd, fluid_carousel.gd", "host and level lifecycle"],
        ["features/levels/secret_eyes/eye_band.gd, eye_band_demo.gd", "the eye band"],
        ["features/levels/boids/boids_level.gd", "flock voices, snare, ghosts, tap reading"],
        ["core/audio/README.md, …/boids/README.md, docs/boids-rhythm-scope.md", "design reasoning"],
    ], [86 * mm, FRAME_W - 86 * mm]))
    s.append(Spacer(1, 6))
    s.append(table([
        ["Term", "Meaning here"],
        ["beat", "Unit of musical position; MusicTimeSource counts these."],
        ["step", "Grid slot: 16 per bar for the band, 12 per bar (LCM of 3, 4, 6, 4) for the boids."],
        ["lookahead", "Seconds a scheduled event fires early: time to next mix + output latency."],
        ["mix block", "Chunk the audio thread mixes at once (~512 frames); script changes land on these."],
        ["output latency", "Driver buffering between a mixed block and the DAC."],
        ["part", "One of beat, bass, pads, melody, arp, ghost, shimmer."],
        ["latch", "Band copying wants into what plays, once per bar."],
        ["host", "SharedLayers: tank + band, outliving levels."],
        ["ghost", "Quiet snare a bar after a tap, on the pulse the tap was read as."],
    ], [30 * mm, FRAME_W - 30 * mm]))
    s.append(notes(5))
    s.append(PageBreak())
    s.append(Dot("Sketches — signal flow"))
    s.append(PageBreak())
    s.append(Dot("Sketches — free notes"))

    build_pdf(s, OUT, "eyeMusic — the music system", "eyeMusic · music system study guide")
    print(f"wrote {OUT}")
    if len(sys.argv) > 1:
        named = Path(sys.argv[1]) / output_name("music system", ROOT)
        shutil.copyfile(OUT, named)
        print(f"wrote {named}")


if __name__ == "__main__":
    build()
