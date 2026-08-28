# Event Countdown

Count down (or up) to birthdays, anniversaries, deadlines, and holidays from the Omarchy bar, with a clean progress fill for each event. Click to configure.

## Install

```sh
omarchy plugin add https://github.com/SjoenH/omarchy-event-countdown.git --enable
```

## Usage

The bar shows the most relevant event — its name, a compact progress fill, and the time left since or to it — depending on your **Mode**:

- **Count down** — emphasizes the next upcoming event (`in 14d`)
- **Count up** — emphasizes the most recently passed event (`3d ago`)
- **Both** — shows whichever event is nearest

Click to open the dropdown panel. Each event is a minimalistic row with a filled-in progress box:

- The fill runs from **empty** (just after the event) to **full** (on its next occurrence), resetting each cycle.
- A green dot marks upcoming events; a grey dot marks passed ones.

Each event has a **Name**, a **Month/Day**, and either:

- **Repeats every year** (on) — birthdays, anniversaries; recurs annually
- **One-off date** (off) — deadlines, holidays; requires a **Year**

Use the **Add / Save / Delete** buttons to manage events. Everything persists across restarts via `shell.json`.

## Default

Ships with no events. Add one from the panel to begin.

## Remove

```sh
omarchy plugin remove no.koka.event-countdown
```
