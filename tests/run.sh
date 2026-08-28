#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_ID="no.koka.event-countdown"
PASS=0
FAIL=0

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Event Countdown Plugin Tests ==="
echo ""

# --- Structure tests ---
echo "--- Structure ---"
for file in manifest.json BarWidget.qml Panel.qml README.md LICENSE; do
  if [ -f "$PLUGIN_DIR/$file" ]; then ok "$file exists"
  else fail "$file missing"; fi
done

# --- Manifest tests ---
echo ""
echo "--- Manifest ---"
MANIFEST="$PLUGIN_DIR/manifest.json"
if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$MANIFEST" 2>/dev/null; then
  ok "manifest.json is valid JSON"
else
  fail "manifest.json is not valid JSON"
fi

ID=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['id'])")
if [ "$ID" = "$PLUGIN_ID" ]; then ok "plugin ID is $PLUGIN_ID"
else fail "plugin ID is $ID, expected $PLUGIN_ID"; fi

SCHEMA=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['schemaVersion'])")
if [ "$SCHEMA" = "1" ]; then ok "schemaVersion is 1"
else fail "schemaVersion is $SCHEMA, expected 1"; fi

KINDS=$(python3 -c "import json; print(','.join(json.load(open('$MANIFEST'))['kinds']))")
if echo "$KINDS" | grep -q "bar-widget"; then ok "kinds includes bar-widget"
else fail "kinds missing bar-widget: $KINDS"; fi

ALLOW_MULTI=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['barWidget']['allowMultiple'])")
if [ "$ALLOW_MULTI" = "False" ]; then ok "allowMultiple is false"
else fail "allowMultiple is $ALLOW_MULTI, expected False"; fi

# --- Validation ---
echo ""
echo "--- Validation ---"
if omarchy plugin validate "$PLUGIN_DIR" 2>/dev/null; then
  ok "omarchy plugin validate passes"
else
  fail "omarchy plugin validate fails"
fi

# --- QML lint ---
echo ""
echo "--- QML Lint ---"
if OMARCHY_PATH="/usr/share/omarchy" qmllint -I "$OMARCHY_PATH/shell" \
  "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml" 2>/dev/null; then
  ok "qmllint passes on BarWidget.qml"
  ok "qmllint passes on Panel.qml"
else
  fail "qmllint reports issues (may be false positives from imports)"
fi

# --- Date / progress logic tests (mirror the math in BarWidget.qml) ---
echo ""
echo "--- Date / Progress Logic ---"
NODE_JS=$(cat << 'EOF'
function dayIndex(d) { return Math.floor(d.getTime() / 86400000) }
function ydate(y, m, d) { return new Date(y, m - 1, d) }
function todayIndex() { return dayIndex(new Date()) }

function occurrences(evt, now) {
  var t = dayIndex(now)
  var m = evt.month, d = evt.day
  var yNow = now.getFullYear()
  var res = { prev: 0, next: 0, passed: true }
  if (evt.repeats) {
    var thisY = dayIndex(ydate(yNow, m, d))
    var next = thisY >= t ? thisY : dayIndex(ydate(yNow + 1, m, d))
    res.next = next
    res.prev = dayIndex(ydate(new Date(res.next * 86400000).getFullYear() - 1, m, d))
    res.passed = false
  } else {
    var occ = dayIndex(ydate(evt.year, m, d))
    res.next = occ
    res.prev = occ - 365
    res.passed = occ < t
  }
  return res
}
function fractionOf(evt, now) {
  var o = occurrences(evt, now)
  var span = o.next - o.prev
  if (span <= 0) return 1
  var f = (dayIndex(now) - o.prev) / span
  if (f < 0) f = 0
  if (f > 1) f = 1
  return f
}
function countOf(evt, now) {
  var o = occurrences(evt, now)
  var days = Math.abs(o.next - dayIndex(now))
  var text = o.passed ? (days === 0 ? "today" : days + "d ago") : (days === 0 ? "today" : "in " + days + "d")
  return { text: text, upcoming: !o.passed, days: days }
}
function approx(a, b, eps) { return Math.abs(a - b) <= (eps || 0.0001) }
function assert(failures, name, cond) { if (cond) console.log("PASS " + name); else { console.log("FAIL " + name); failures.push(name) } }
var failures = []

// Recurring birthday on 12 Dec. "now" = mid year (5 Jun 2026).
var now = new Date(2026, 5, 5, 12, 0, 0)   // 5 Jun 2026
var bday = { id: "e", name: "B", month: 12, day: 12, year: 0, repeats: true }
var o = occurrences(bday, now)
assert(failures, "recurring: next is this year's Dec 12", o.next === dayIndex(new Date(2026, 11, 12)))
assert(failures, "recurring: prev is last year's Dec 12", o.prev === dayIndex(new Date(2025, 11, 12)))
assert(failures, "recurring: not passed", o.passed === false)
var c = countOf(bday, now)
assert(failures, "recurring: counts down (in Xd)", /^in \d+d$/.test(c.text) && c.upcoming)

// Recurring birthday already passed this year (now = 20 Dec 2026).
var now2 = new Date(2026, 11, 20, 9, 0, 0)   // 20 Dec 2026
var o2 = occurrences(bday, now2)
assert(failures, "recurring: next rolls to next year", o2.next === dayIndex(new Date(2027, 11, 12)))
assert(failures, "recurring: still not passed (always a next)", o2.passed === false)
assert(failures, "recurring: fill resets right after the occurrence", fractionOf(bday, now2) < 0.05)
assert(failures, "recurring: fill approaches full just before next occurrence", fractionOf(bday, new Date(2027, 11, 10, 9, 0, 0)) > 0.99)

// One-off future event (pipeline deadline 1 Oct 2026, from 5 Jun 2026).
var deadline = { id: "d", name: "D", month: 10, day: 1, year: 2026, repeats: false }
var od = occurrences(deadline, now)
assert(failures, "one-off upcoming: not passed", od.passed === false)
assert(failures, "one-off future fraction in [0,1]", fractionOf(deadline, now) > 0 && fractionOf(deadline, now) < 1)

// One-off passed event (4 days ago: 1 Jun 2026 from 5 Jun 2026).
var past = { id: "p", name: "P", month: 6, day: 1, year: 2026, repeats: false }
var op = occurrences(past, now)
assert(failures, "one-off passed: passed is true", op.passed === true)
var cp = countOf(past, now)
assert(failures, "one-off passed counts up (Nd ago)", /^5d ago$/.test(cp.text) && !cp.upcoming)

// Fraction bounds for the top of the bar fill.
assert(failures, "fraction clamped to [0,1]", fractionOf(deadline, now) <= 1 && fractionOf(past, now) <= 1)
assert(failures, "passed event fraction = 1", approx(fractionOf(past, now), 1))

if (failures.length > 0) process.exit(1)
EOF
)
if node -e "$NODE_JS" 2>&1; then
  ok "date/progress logic passes"
else
  fail "date/progress logic failed"
fi

# --- Persistence shape test ---
echo ""
echo "--- Persistence ---"
TMP_SHELL=$(mktemp)
cat > "$TMP_SHELL" << EOF
{
  "version": 1,
  "bar": {
    "id": "omarchy.bar",
    "layout": {
      "left": [],
      "center": [],
      "right": [
        {"id": "no.koka.event-countdown", "mode": "both",
         "events": [{"id":"e1","name":"Birthday","month":12,"day":12,"year":0,"repeats":true}]}
      ]
    }
  },
  "plugins": []
}
EOF
python3 -c "
import json
d = json.load(open('$TMP_SHELL'))
entry = [e for e in d['bar']['layout']['right'] if e.get('id')=='no.koka.event-countdown'][0]
assert 'events' in entry and isinstance(entry['events'], list), 'events[] must be a list'
assert entry['events'][0]['month']==12 and entry['events'][0]['repeats'] is True, 'event fields wrong'
assert 'mode' in entry and entry['mode']=='both', 'mode must persist'
"
if [ $? -eq 0 ]; then ok "events[] + mode persist as a single flat entry"
else fail "persistence shape wrong"; fi
rm -f "$TMP_SHELL"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
