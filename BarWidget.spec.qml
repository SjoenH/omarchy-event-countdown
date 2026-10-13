import QtQuick

// Runs against the real BarWidget.qml and Panel.qml through tests/run.sh.
// `h` is the harness (tests/harness/Harness.qml); a test that has to wait is
// a generator and yields the number of milliseconds to wait.
Item {
    id: spec

    property var h: null
    readonly property var june5: new Date(2026, 5, 5, 12, 0, 0)

    function event(name, month, day, year) {
        return {
            "id": "e1",
            "name": name,
            "month": month,
            "day": day,
            "year": year || 0,
            "repeats": !year
        };
    }

    function widgetWith(events, mode, precision) {
        return h.createWidget({
            "mode": mode || "both",
            "precision": precision || "units",
            "events": events
        });
    }

    function dayOf(index) {
        var d = new Date(index * 8.64e+07);
        return d.getUTCFullYear() + "-" + (d.getUTCMonth() + 1) + "-" + d.getUTCDate();
    }

    // --- The configured date survives startup and the panel ----------------

    // Regression: loading the name into the panel fired its onTextChanged
    // while the date editors still held their defaults, which rewrote the
    // event to January 1 as soon as the widget started.
    function* test_startupKeepsTheConfiguredDate() {
        var w = widgetWith([event("Christmas", 12, 24)]);
        yield 50;
        h.compare(w.events[0].month, 12, "month");
        h.compare(w.events[0].day, 24, "day");
        h.compare(h.byName("eventName").text, "Christmas");
        h.compare(h.persisted.length, 0, "starting up writes nothing");
    }

    // Regression: closing an untouched panel committed the corrupted date.
    function* test_openingAndClosingThePanelWritesNothing() {
        var w = widgetWith([event("Christmas", 12, 24)]);
        yield 50;
        w.open();
        yield 50;
        var panel = h.byName("eventCountdownPanel");
        h.compare(panel.edMonth, 12, "month shown in the panel");
        h.compare(panel.edDay, 24, "day shown in the panel");
        w.close();
        yield 50;
        h.compare(h.persisted.length, 0, "nothing persisted");
        h.compare(w.events[0].month + "/" + w.events[0].day, "12/24");
    }

    function* test_settingsPushedLaterReplaceTheEventIntact() {
        var w = widgetWith([event("Christmas", 12, 24)]);
        yield 50;
        w.settings = {
            "mode": "both",
            "precision": "units",
            "events": [event("Midsummer", 6, 24)]
        };
        yield 50;
        h.compare(w.events[0].name, "Midsummer");
        h.compare(w.events[0].month + "/" + w.events[0].day, "6/24");
        // The panel's editors must follow, without the previous event's date
        // leaking into the one that was just loaded.
        var panel = h.byName("eventCountdownPanel");
        h.compare(panel.edName, "Midsummer");
        h.compare(panel.edMonth + "/" + panel.edDay, "6/24");
        h.compare(panel.isDirty(), false);
    }

    function* test_renamingAnEventKeepsItsDate() {
        var w = widgetWith([event("Christmas", 12, 24)]);
        yield 50;
        w.open();
        yield 50;
        var field = h.byName("nameField");
        h.click(field);
        field.selectAll();
        h.type("Xmas");
        yield 20;
        h.compare(h.persisted.length, 0, "typing alone is a preview");
        w.close();
        yield 50;
        var saved = h.lastPersisted().events[0];
        h.compare(saved.name, "Xmas");
        h.compare(saved.month + "/" + saved.day, "12/24");
    }

    function* test_typingReachesTheNameFieldEvenForPanelShortcutKeys() {
        var w = widgetWith([event("A", 1, 1)]);
        yield 50;
        w.open();
        yield 50;
        var field = h.byName("nameField");
        h.click(field);
        field.selectAll();
        h.type("jkl hx");
        h.compare(field.text, "jkl hx");
    }

    function* test_addingAnEventPersistsOnClose() {
        var w = widgetWith([]);
        yield 50;
        h.compare(h.byName("eventName").text, "no events");
        w.open();
        yield 50;
        h.click(h.byName("addEventButton"));
        yield 20;
        h.click(h.byName("nameField"));
        h.type("Launch");
        w.close();
        yield 50;
        h.compare(h.lastPersisted().events[0].name, "Launch");
        h.compare(h.byName("eventName").text, "Launch");
    }

    function* test_clearingTheNameRemovesTheEvent() {
        var w = widgetWith([event("Christmas", 12, 24)]);
        yield 50;
        w.open();
        yield 50;
        var field = h.byName("nameField");
        h.click(field);
        field.selectAll();
        h.key(Qt.Key_Backspace);
        yield 50;
        h.compare(h.lastPersisted().events, []);
        h.compare(w.events.length, 0);
    }

    function* test_changingTheMonthClampsTheDay() {
        var w = widgetWith([event("Payday", 1, 31)]);
        yield 50;
        w.open();
        yield 50;
        h.compare(h.byName("dayField").to, 31);
        h.byName("monthField").changed("4");
        yield 50;
        h.compare(h.byName("dayField").to, 30);
        var saved = h.lastPersisted().events[0];
        h.compare(saved.month + "/" + saved.day, "4/30");
    }

    // --- Rendering ---------------------------------------------------------

    // The name is whatever the user typed; it must never be parsed as markup.
    function* test_eventNameIsRenderedAsPlainText() {
        var w = widgetWith([event("<b>Mom</b> <3", 12, 24)]);
        yield 50;
        var name = h.byName("eventName");
        h.compare(name.text, "<b>Mom</b> <3");
        h.compare(name.textFormat, Text.PlainText);
        h.compare(h.byName("eventCount").textFormat, Text.PlainText);
    }

    function* test_modeDecidesWhetherTheEventIsShown() {
        var past = new Date();
        past.setDate(past.getDate() - 10);
        var w = widgetWith([event("Past", past.getMonth() + 1, past.getDate(), past.getFullYear())], "countdown");
        yield 50;
        h.compare(h.byName("eventName").text, "no events", "a passed one-off has nothing to count down to");
        w.settings = {
            "mode": "countup",
            "precision": "days",
            "events": w.events
        };
        yield 50;
        h.compare(h.byName("eventName").text, "Past");
        h.compare(h.byName("eventCount").text, "10d ago");
    }

    // --- Occurrences -------------------------------------------------------

    function test_recurringEventLaterThisYear() {
        var w = widgetWith([]);
        var o = w.occurrences(event("B", 12, 12), june5);
        h.compare(dayOf(o.next), "2026-12-12");
        h.compare(dayOf(o.prev), "2025-12-12");
        h.compare(o.passed, false);
    }

    function test_recurringEventRollsToNextYearOncePassed() {
        var w = widgetWith([]);
        var o = w.occurrences(event("B", 12, 12), new Date(2026, 11, 20, 9, 0, 0));
        h.compare(dayOf(o.next), "2027-12-12");
        h.compare(dayOf(o.prev), "2026-12-12");
    }

    function test_oneOffEventKnowsWhetherItHasPassed() {
        var w = widgetWith([]);
        h.compare(w.occurrences(event("D", 10, 1, 2026), june5).passed, false);
        h.compare(w.occurrences(event("P", 6, 1, 2026), june5).passed, true);
    }

    // Regression: Feb 31 used to roll over to March 3 while still being
    // labelled "Feb 31", and Feb 29 landed on March 1 outside leap years.
    function test_impossibleDatesStayInTheirOwnMonth() {
        var w = widgetWith([]);
        var january = new Date(2026, 0, 10, 12, 0, 0);
        h.compare(dayOf(w.occurrences(event("X", 2, 31), january).next), "2026-2-28");
        h.compare(dayOf(w.occurrences(event("Leapling", 2, 29), january).next), "2026-2-28");
        h.compare(dayOf(w.occurrences(event("Leapling", 2, 29), new Date(2028, 0, 10)).next), "2028-2-29");
        h.compare(dayOf(w.occurrences(event("X", 4, 31), january).next), "2026-4-30");
    }

    // --- Counting ----------------------------------------------------------

    function test_countsDownInFuzzyUnits() {
        var w = widgetWith([]);
        var c = w.countOf(event("B", 12, 12), june5, "units", "both");
        h.compare(c.text, "in 6mo");
        h.compare(c.upcoming, true);
        h.compare(w.countOf(event("S", 6, 15, 2026), june5, "units", "both").text, "in 1w");
        h.compare(w.countOf(event("F", 7, 5, 2027), june5, "units", "both").text, "in 1y");
    }

    function test_countsDownInExactDays() {
        var w = widgetWith([]);
        h.compare(w.countOf(event("B", 12, 12), june5, "days", "both").text, "in 190d");
    }

    function test_todayAndTomorrow() {
        var w = widgetWith([]);
        h.compare(w.countOf(event("T", 6, 5), june5, "units", "both").text, "today");
        h.compare(w.countOf(event("M", 6, 6), june5, "units", "both").text, "tomorrow");
    }

    function test_passedOneOffCountsUp() {
        var w = widgetWith([]);
        var c = w.countOf(event("P", 6, 1, 2026), june5, "units", "both");
        h.compare(c.text, "4d ago");
        h.compare(c.upcoming, false);
    }

    function test_countUpMeasuresFromTheLastOccurrence() {
        var w = widgetWith([]);
        var c = w.countOf(event("B", 1, 1), june5, "units", "countup");
        h.compare(c.upcoming, false);
        h.compare(c.days, 155);
        h.compare(c.text, "5mo ago");
        h.compare(w.countOf(event("B", 12, 12), june5, "days", "countup").text, "175d ago");
    }

    // Regression: on the anniversary itself count-up measured from last
    // year's occurrence and showed "1y ago".
    function test_countUpOnTheDayItselfReadsToday() {
        var w = widgetWith([]);
        var c = w.countOf(event("T", 6, 5), june5, "units", "countup");
        h.compare(c.text, "today");
        h.compare(c.days, 0);
    }

    function test_dateFormatShowsTheDate() {
        var w = widgetWith([]);
        h.compare(w.countOf(event("B", 12, 12), june5, "date", "both").text, "→ Dec 12");
        h.compare(w.countOf(event("B", 12, 12), june5, "date", "countup").text, "← Dec 12 2025");
        h.compare(w.countOf(event("Soon", 6, 8), june5, "date", "both").text, "in 3d", "within a week it falls back to a count");
    }

    // Regression: the label's year was read in local time from a UTC day
    // index, so west of UTC a January 1 event lost its year.
    function test_dateFormatAddsTheYearWhenItDiffers() {
        var w = widgetWith([]);
        var october = new Date(2026, 9, 13, 10, 0, 0);
        h.compare(w.countOf(event("New Year", 1, 1), october, "date", "both").text, "→ Jan 1 2027");
    }

    // --- Settings parsing --------------------------------------------------

    function test_parseEventsKeepsOnlyTheFirstEvent() {
        var w = widgetWith([]);
        var out = w.parseEvents([event("First", 1, 1), event("Ignored", 3, 15, 2027)]);
        h.compare(out.length, 1);
        h.compare(out[0].name, "First");
        h.compare(out[0].repeats, true);
    }

    function test_parseEventsRejectsDatesThatCannotExist() {
        var w = widgetWith([]);
        h.compare(w.parseEvents([event("No date", "x", "y")]).length, 0);
        h.compare(w.parseEvents([event("Month 13", 13, 1)]).length, 0);
        h.compare(w.parseEvents([event("Day 0", 5, 0)]).length, 0);
        h.compare(w.parseEvents([event("Day 32", 5, 32)]).length, 0);
        h.compare(w.parseEvents("nonsense").length, 0);
    }

}
