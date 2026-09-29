# Steam Deck controls in Desktop Mode

How the game should read the Deck's controller, and what it actually receives
depending on how the game was launched.

## Two ways the game can see the controller

**Launched through Steam** (Game Mode, or a non-Steam game entry started from
the Steam client in Desktop Mode): Steam Input hands the game a gamepad. The
Deck's buttons arrive as `InputEventJoypadButton`s from Steam's virtual pad,
which is usually **not device 0**, so every gamepad binding must listen to all
devices (`InputActions.ensure` does).

**Run outside Steam** (from the file manager, a terminal, or
`scripts/deck.sh run` over SSH) while the Steam client is running: Steam keeps
the controller in its **desktop layout**, and the game sees no gamepad at all.
Every control arrives as a keyboard key or a mouse event.

The desktop builds are run the second way, so every action a player needs
on the Deck must also be bound to what the desktop layout sends.

## The default desktop layout

From Steam → Settings → Controller → Desktop Configuration, as shipped.

| Deck control | Sends | Confidence |
| --- | --- | --- |
| A | Return | Several sources agree |
| B | Escape | Several sources agree |
| X | Opens the on-screen keyboard (no key) | Several sources agree |
| Y | Space | Several sources agree |
| D-pad | Arrow keys | Several sources agree |
| R2 | Left click | Several sources agree |
| L2 | Right click | Several sources agree |
| Right trackpad | Moves the pointer (press: left click) | Several sources agree |
| Left trackpad | Press: right click | One source |
| View (Select) | Tab | One source — check on a Deck |
| Menu (Start) | Escape | One source — check on a Deck |
| L1 / R1 | Left Ctrl / Left Alt | One source — check on a Deck |
| Sticks, back grips | Not established | — |

The confirmed rows are constants in
[`DeckDesktopLayout`](../core/input/deck_desktop_layout.gd), with View
(flagged there as unconfirmed). One source also says a long press of
Menu/Start toggles the desktop layout to a plain gamepad, which would be
another way to get joypad events without going through Steam; unchecked.

Anyone can change their own desktop layout, so treat this as the default, not
a guarantee. The birds level's HUD shows *last input*: exactly what the game
received for the last press, named after the Deck control that sends it. That
is the quickest way to check a row on real hardware.

## What each action gets

| Action | Gamepad (through Steam) | Desktop layout (outside Steam) | Status |
| --- | --- | --- | --- |
| Snare (birds) | B | B → Esc; also Y → Space, R2/L2 → clicks | ✅ Works both ways |
| Tempo ±2 / ±10 (every scene) | D-pad | D-pad → arrows | ✅ Works both ways |
| Leave a demo (menu) | View/Select | View → Tab (unconfirmed) | ✅ If View sends Tab |
| Quit from the menu (PR picker launch) | View/Select | — | ⚠️ Tab is not bound here: at the menu it moves focus |
| Menu navigation | D-pad, A | Arrows, Return | ✅ Godot's built-in `ui_*` actions |
| Stir (tank levels) | — | R2 → left click (drag with the right trackpad) | ✅ |
| Jog (tank levels) | — | A → Return, Y → Space (`ui_accept`) | ✅ |
| Tilt (tank levels) | — | WASD on a keyboard only | ⚠️ Nothing on the Deck sends WASD |
| Look (panorama) | Right stick | Right trackpad → mouse | ✅ |
| Key shift (eye band) | L1/R1, L2/R2 | L2/R2 → clicks; L1/R1 unconfirmed | ❌ Not reachable; R2's click stirs |
| Refresh (PR picker) | Y | Y → Space | ⚠️ Space also presses the focused PR's button |

The ⚠️ and ❌ rows need an answer on a Deck before they are bound; binding
a guess could leave a control that does something else.

## Sources

- [PCWorld: The Steam Deck's button mapper is the best feature you're not using](https://www.pcworld.com/article/1364387/the-steam-decks-button-mapper-is-the-best-feature-youre-not-using.html)
- [How-To Geek: Steam Deck shortcuts, the ultimate guide](https://www.howtogeek.com/882130/steam-deck-shortcuts-the-ultimate-guide/)
- [PCGamesN: How to right click on Steam Deck in Desktop mode](https://www.pcgamesn.com/steam-deck/right-click)
- [Steam Deck Explained: Desktop Mode left click, right click and scroll](https://steamdeckexplained.com/steam-deck-desktop-mode-right-click/)
- [Android Authority: Steam Deck Desktop Mode](https://androidauthority.com/steam-deck-desktop-mode-3346398)
- [Steam Community: Steam Deck discussion on the desktop configuration](https://steamcommunity.com/app/1675200/discussions/0/3541546590711303821)
