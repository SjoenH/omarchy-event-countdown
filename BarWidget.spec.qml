import QtQuick 2.15
import QtTest 1.2

TestCase {
    name: "EventCountdown"
    when: windowShown

    function _dayIndex(d) { return Math.floor(d.getTime() / 86400000) }
    function _ydate(year, month, day) { return new Date(year, month - 1, day) }
    function _todayIndex() { return _dayIndex(new Date()) }

    function _occurrences(evt, now) {
        var t = _dayIndex(now)
        var m = evt.month, d = evt.day
        var yNow = now.getFullYear()
        var res = { prev: 0, next: 0, passed: true }
        if (evt.repeats) {
            var thisY = _dayIndex(_ydate(yNow, m, d))
            var next = thisY >= t ? thisY : _dayIndex(_ydate(yNow + 1, m, d))
            res.next = next
            res.prev = _dayIndex(_ydate(new Date(res.next * 86400000).getFullYear() - 1, m, d))
            res.passed = false
        } else {
            var occ = _dayIndex(_ydate(evt.year, m, d))
            res.next = occ
            res.prev = occ - 365
            res.passed = occ < t
        }
        return res
    }

    function _fractionOf(evt, now) {
        var o = _occurrences(evt, now)
        var span = o.next - o.prev
        if (span <= 0) return 1
        var f = (_dayIndex(now) - o.prev) / span
        if (f < 0) f = 0
        if (f > 1) f = 1
        return f
    }

    function _countOf(evt, now) {
        var o = _occurrences(evt, now)
        var days = Math.abs(o.next - _dayIndex(now))
        var text = o.passed ? (days === 0 ? "today" : days + "d ago") : (days === 0 ? "today" : "in " + days + "d")
        return { text: text, upcoming: !o.passed, days: days }
    }

    function _approx(a, b, eps) { return Math.abs(a - b) <= (eps || 0.0001) }

    function test_recurringBirthdayThisYear() {
        var now = new Date(2026, 5, 5, 12, 0, 0)
        var bday = { id: "e", name: "B", month: 12, day: 12, year: 0, repeats: true }
        var o = _occurrences(bday, now)
        verify(o.next === _dayIndex(new Date(2026, 11, 12)))
        verify(o.prev === _dayIndex(new Date(2025, 11, 12)))
        verify(o.passed === false)
    }

    function test_recurringBirthdayRollsToNextYear() {
        var now = new Date(2026, 11, 20, 9, 0, 0)
        var bday = { id: "e", name: "B", month: 12, day: 12, year: 0, repeats: true }
        var o = _occurrences(bday, now)
        verify(o.next === _dayIndex(new Date(2027, 11, 12)))
        verify(o.passed === false)
    }

    function test_recurringFillResetsAfterOccurrence() {
        var now = new Date(2026, 11, 20, 9, 0, 0)
        var bday = { id: "e", name: "B", month: 12, day: 12, year: 0, repeats: true }
        verify(_fractionOf(bday, now) < 0.05)
    }

    function test_recurringFillApproachesFullBeforeNext() {
        var now = new Date(2027, 11, 10, 9, 0, 0)
        var bday = { id: "e", name: "B", month: 12, day: 12, year: 0, repeats: true }
        verify(_fractionOf(bday, now) > 0.99)
    }

    function test_oneOffUpcomingNotPassed() {
        var now = new Date(2026, 5, 5, 12, 0, 0)
        var deadline = { id: "d", name: "D", month: 10, day: 1, year: 2026, repeats: false }
        var od = _occurrences(deadline, now)
        verify(od.passed === false)
    }

    function test_oneOffFutureFractionInBounds() {
        var now = new Date(2026, 5, 5, 12, 0, 0)
        var deadline = { id: "d", name: "D", month: 10, day: 1, year: 2026, repeats: false }
        verify(_fractionOf(deadline, now) > 0 && _fractionOf(deadline, now) < 1)
    }

    function test_oneOffPastCountsUp() {
        var now = new Date(2026, 5, 5, 12, 0, 0)
        var past = { id: "p", name: "P", month: 6, day: 1, year: 2026, repeats: false }
        var op = _occurrences(past, now)
        verify(op.passed === true)
        var cp = _countOf(past, now)
        verify(/^5d ago$/.test(cp.text))
        verify(cp.upcoming === false)
    }

    function test_countOfRecurringDisplaysInXd() {
        var now = new Date(2026, 5, 5, 12, 0, 0)
        var bday = { id: "e", name: "B", month: 12, day: 12, year: 0, repeats: true }
        var c = _countOf(bday, now)
        verify(/in \d+d$/.test(c.text))
        verify(c.upcoming === true)
    }

    function test_countOfOneOffPassedDisplaysDaysAgo() {
        var now = new Date(2026, 5, 5, 12, 0, 0)
        var past = { id: "p", name: "P", month: 6, day: 1, year: 2026, repeats: false }
        var cp = _countOf(past, now)
        verify(/^5d ago$/.test(cp.text))
        verify(cp.upcoming === false)
    }

    function test_fractionClampedToZeroOne() {
        var now = new Date(2026, 5, 5, 12, 0, 0)
        var deadline = { id: "d", name: "D", month: 10, day: 1, year: 2026, repeats: false }
        var past = { id: "p", name: "P", month: 6, day: 1, year: 2026, repeats: false }
        verify(_fractionOf(deadline, now) <= 1)
        verify(_fractionOf(past, now) <= 1)
    }

    function test_passedEventFractionEqualsOne() {
        var now = new Date(2026, 5, 5, 12, 0, 0)
        var past = { id: "p", name: "P", month: 6, day: 1, year: 2026, repeats: false }
        verify(_approx(_fractionOf(past, now), 1))
    }

    function test_nearestEventBothModes() {
        var now = new Date(2026, 5, 5, 12, 0, 0)
        var events = [
            { id: "a", name: "A", month: 6, day: 10, year: 0, repeats: true },
            { id: "b", name: "B", month: 6, day: 1, year: 2026, repeats: false }
        ]
        var t = _dayIndex(now)
        var best = null, bestAbs = 1e9
        for (var i = 0; i < events.length; i++) {
            var e = events[i]
            var o = _occurrences(e, now)
            var days = Math.abs(o.next - t)
            if (days < bestAbs) { bestAbs = days; best = e }
        }
        verify(best !== null)
    }
}
