import QtQuick 2.15
import QtTest 1.2

TestCase {
    function _dayIndex(d) {
        return Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 8.64e+07;
    }

    function _ydate(year, month, day) {
        return new Date(year, month - 1, day);
    }

    function _todayIndex() {
        return _dayIndex(new Date());
    }

    function _occurrences(evt, now) {
        var t = _dayIndex(now);
        var m = evt.month, d = evt.day;
        var yNow = now.getFullYear();
        var res = {
            "prev": 0,
            "next": 0,
            "passed": true
        };
        if (evt.repeats) {
            var thisY = _dayIndex(_ydate(yNow, m, d));
            var next = thisY >= t ? thisY : _dayIndex(_ydate(yNow + 1, m, d));
            res.next = next;
            res.prev = _dayIndex(_ydate(new Date(res.next * 8.64e+07).getFullYear() - 1, m, d));
            res.passed = false;
        } else {
            var occ = _dayIndex(_ydate(evt.year, m, d));
            res.next = occ;
            res.prev = occ - 365;
            res.passed = occ < t;
        }
        return res;
    }

    function _parseEvents(arr) {
        if (!arr || typeof arr !== "object" || arr.length === undefined)
            return [];

        var out = [];
        for (var i = 0; i < arr.length && out.length < 1; i++) {
            var e = arr[i];
            if (!e || typeof e !== "object")
                continue;

            var m = parseInt(e.month, 10), d = parseInt(e.day, 10);
            if (isNaN(m) || isNaN(d))
                continue;

            out.push({
                "id": e.id,
                "name": String(e.name || ""),
                "month": m,
                "day": d,
                "year": parseInt(e.year, 10) || 0,
                "repeats": e.repeats === true
            });
        }
        return out;
    }

    function _countOf(evt, now, precision, mode) {
        var o = _occurrences(evt, now);
        var t = _dayIndex(now);
        var m = mode !== undefined ? mode : "both";
        var p = precision !== undefined ? precision : "units";
        var days, upcoming, anchor = o.next;
        if (m === "countup") {
            if (evt.repeats) {
                anchor = o.prev;
                days = t - o.prev;
                upcoming = false;
            } else {
                days = Math.abs(o.next - t);
                upcoming = !o.passed;
                anchor = o.next;
            }
        } else {
            days = Math.abs(o.next - t);
            upcoming = !o.passed;
            anchor = o.next;
        }
        if (days < 0)
            days = 0;

        var text;
        if (p === "date" && days >= 7)
            text = _dateLabel(evt, o, now, upcoming, anchor);
        else
            text = _unitText(days, upcoming, p);

        return {
            "text": text,
            "upcoming": upcoming,
            "days": days
        };
    }

function _dateLabel(evt, o, now, upcoming, anchor) {
        var arrow = upcoming ? "\u2192 " : "\u2190 ";
        var idx = anchor === undefined ? o.next : anchor;
        var y = new Date(idx * 8.64e+07).getFullYear();
        var yNow = now.getFullYear();
        return arrow + _monthDayName(evt) + (y !== yNow ? " " + y : "");
    }

    function _monthDayName(evt) {
        var names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        var mn = names[(evt.month - 1 + 12) % 12] || evt.month;
        return mn + " " + evt.day;
    }

    function _unitText(days, upcoming, precision) {
        if (days === 0)
            return "today";

        if (days === 1)
            return upcoming ? "tomorrow" : "yesterday";

        var prefix = upcoming ? "in " : "";
        var suffix = upcoming ? "" : " ago";
        if ((precision || "units") === "days")
            return prefix + days + "d" + suffix;

        if (days < 7)
            return prefix + days + "d" + suffix;

        if (days < 30)
            return prefix + Math.round(days / 7) + "w" + suffix;

        if (days < 365)
            return prefix + Math.min(11, Math.round(days / 30)) + "mo" + suffix;

        return prefix + Math.round(days / 365) + "y" + suffix;
    }

    function _nearestEvent(events, mode, now) {
        if (!events || events.length === 0)
            return null;

        var e = events[0];
        var c = _countOf(e, now);
        if (mode === "countdown" && !c.upcoming)
            return null;

        if (mode === "countup" && c.upcoming)
            return null;

        return e;
    }

    function test_recurringBirthdayThisYear() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var bday = {
            "id": "e",
            "name": "B",
            "month": 12,
            "day": 12,
            "year": 0,
            "repeats": true
        };
        var o = _occurrences(bday, now);
        verify(o.next === _dayIndex(new Date(2026, 11, 12)));
        verify(o.prev === _dayIndex(new Date(2025, 11, 12)));
        verify(o.passed === false);
    }

    function test_recurringBirthdayRollsToNextYear() {
        var now = new Date(2026, 11, 20, 9, 0, 0);
        var bday = {
            "id": "e",
            "name": "B",
            "month": 12,
            "day": 12,
            "year": 0,
            "repeats": true
        };
        var o = _occurrences(bday, now);
        verify(o.next === _dayIndex(new Date(2027, 11, 12)));
        verify(o.passed === false);
    }

    function test_oneOffUpcomingNotPassed() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var deadline = {
            "id": "d",
            "name": "D",
            "month": 10,
            "day": 1,
            "year": 2026,
            "repeats": false
        };
        var od = _occurrences(deadline, now);
        verify(od.passed === false);
    }

    function test_oneOffPastCountsUp() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var past = {
            "id": "p",
            "name": "P",
            "month": 6,
            "day": 1,
            "year": 2026,
            "repeats": false
        };
        var op = _occurrences(past, now);
        verify(op.passed === true);
        var cp = _countOf(past, now);
        verify(/^4d ago$/.test(cp.text));
        verify(cp.upcoming === false);
    }

    function test_countOfRecurringPastCountsUp() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var bday = {
            "id": "e",
            "name": "B",
            "month": 1,
            "day": 1,
            "year": 0,
            "repeats": true
        };
        var c = _countOf(bday, now, "units", "countup");
        verify(c.upcoming === false);
        var expected = _dayIndex(now) - _dayIndex(new Date(2026, 0, 1));
        verify(c.days === expected);
        verify(/mo ago$/.test(c.text));
    }

    function test_countOfRecurringAlwaysCountsFromLastInCountup() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var bday = {
            "id": "e",
            "name": "B",
            "month": 12,
            "day": 12,
            "year": 0,
            "repeats": true
        };
        var c = _countOf(bday, now, "units", "countup");
        verify(c.upcoming === false);
        var expected = _dayIndex(now) - _dayIndex(new Date(2025, 11, 12));
        verify(c.days === expected);
    }

    function test_countOfRecurringDisplaysInXd() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var bday = {
            "id": "e",
            "name": "B",
            "month": 12,
            "day": 12,
            "year": 0,
            "repeats": true
        };
        var c = _countOf(bday, now, "units");
        verify(c.text === "in 6mo");
        verify(c.upcoming === true);
    }

    function test_precisionExactKeepsDays() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var bday = {
            "id": "e",
            "name": "B",
            "month": 12,
            "day": 12,
            "year": 0,
            "repeats": true
        };
        var c = _countOf(bday, now, "days");
        verify(c.text === "in 190d");
    }

    function test_precisionDateShowsDate() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var bday = {
            "id": "e",
            "name": "B",
            "month": 12,
            "day": 12,
            "year": 0,
            "repeats": true
        };
        var c = _countOf(bday, now, "date");
        verify(c.text === "→ Dec 12");
    }

    function test_precisionUnitsWeeks() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var soon = {
            "id": "s",
            "name": "S",
            "month": 6,
            "day": 15,
            "year": 2026,
            "repeats": false
        };
        var d = _countOf(soon, now, "units");
        verify(d.text === "in 1w");
    }

    function test_precisionUnitsYears() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var far = {
            "id": "f",
            "name": "F",
            "month": 7,
            "day": 5,
            "year": 2027,
            "repeats": false
        };
        var c = _countOf(far, now, "units");
        verify(c.text === "in 1y");
    }

    function test_countOfTodayAndTomorrow() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var today = {
            "id": "t",
            "name": "T",
            "month": 6,
            "day": 5,
            "year": 0,
            "repeats": true
        };
        var tomorrow = {
            "id": "m",
            "name": "M",
            "month": 6,
            "day": 6,
            "year": 0,
            "repeats": true
        };
        verify(_countOf(today, now).text === "today");
        verify(_countOf(tomorrow, now).text === "tomorrow");
    }

    function test_countOfOneOffPassedDisplaysDaysAgo() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var past = {
            "id": "p",
            "name": "P",
            "month": 6,
            "day": 1,
            "year": 2026,
            "repeats": false
        };
        var cp = _countOf(past, now);
        verify(/^4d ago$/.test(cp.text));
        verify(cp.upcoming === false);
    }

    function test_parseEventsKeepsOnlyFirstEvent() {
        var listLike = {
            "length": 2,
            "0": {
                "id": "a",
                "name": "My Birthday",
                "month": 1,
                "day": 1,
                "year": 0,
                "repeats": true
            },
            "1": {
                "id": "b",
                "name": "Ignored",
                "month": 3,
                "day": 15,
                "year": 2027,
                "repeats": false
            }
        };
        verify(Array.isArray(listLike) === false);
        var out = _parseEvents(listLike);
        verify(out.length === 1);
        verify(out[0].name === "My Birthday");
        verify(out[0].repeats === true);
    }

    function test_parseEventsRejectsInvalidSingle() {
        var listLike = {
            "length": 1,
            "0": {
                "id": "bad",
                "name": "No date",
                "month": "x",
                "day": "y",
                "year": 0,
                "repeats": true
            }
        };
        verify(_parseEvents(listLike).length === 0);
    }

    function test_nearestEventSingleEventByMode() {
        var now = new Date(2026, 5, 5, 12, 0, 0);
        var future = [{
            "id": "a",
            "name": "A",
            "month": 6,
            "day": 10,
            "year": 2026,
            "repeats": false
        }];
        var past = [{
            "id": "b",
            "name": "B",
            "month": 6,
            "day": 1,
            "year": 2026,
            "repeats": false
        }];
        verify(_nearestEvent(future, "countdown", now) === future[0]);
        verify(_nearestEvent(past, "countdown", now) === null);
        verify(_nearestEvent(past, "countup", now) === past[0]);
        verify(_nearestEvent(future, "countup", now) === null);
        verify(_nearestEvent(future, "both", now) === future[0]);
        verify(_nearestEvent([], "both", now) === null);
    }

    name: "EventCountdown"
    when: windowShown
}
