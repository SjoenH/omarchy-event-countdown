// Calendar grid math for DatePicker.qml. Weekday indices match JS Date.getDay()
// and QML's Locale.Sunday..Locale.Saturday, so a locale's firstDayOfWeek can be
// passed straight in. Mirrors the kit clock's Model.js monthGrid/weekdayOrder
// helpers without the week-number gutter the clock panel draws.
var WEEKDAY_NAMES = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

function pad2(n) {
    return n < 10 ? "0" + n : String(n)
}

// Stable "yyyy-MM-dd" identity for a day.
function dateKey(year, month, day) {
    return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day)
}

function coerceWeekStart(value) {
    if (value === undefined || value === null)
        return null
    if (typeof value === "number")
        return isFinite(value) ? ((Math.round(value) % 7) + 7) % 7 : null

    var text = String(value).replace(/^\s+|\s+$/g, "").toLowerCase()
    if (text === "")
        return null

    for (var i = 0; i < WEEKDAY_NAMES.length; i++)
        if (WEEKDAY_NAMES[i] === text || WEEKDAY_NAMES[i].substr(0, 3) === text)
            return i

    var parsed = parseInt(text, 10)
    return isFinite(parsed) ? ((parsed % 7) + 7) % 7 : null
}

function normalizedWeekStart(value, fallback) {
    var configured = coerceWeekStart(value)
    if (configured !== null)
        return configured
    var fallbackStart = coerceWeekStart(fallback)
    return fallbackStart === null ? 1 : fallbackStart
}

// Weekday indices [0..6] in display order for the grid header.
function weekdayOrder(weekStart) {
    var start = normalizedWeekStart(weekStart, 1)
    var out = []
    for (var i = 0; i < 7; i++)
        out.push((start + i) % 7)
    return out
}

// Always six rows of seven days. A fixed grid keeps the picker exactly the
// same height in every month, so stepping through the year never changes the
// popup's size. leading pad from the week start; trailing cells bleed into
// the next month and carry inMonth:false.
function monthGrid(year, month, weekStart, todayKey) {
    var start = normalizedWeekStart(weekStart, 1)
    var leading = (new Date(year, month, 1).getDay() - start + 7) % 7
    var cursor = new Date(year, month, 1 - leading)
    var today = String(todayKey || "")
    var weeks = []

    for (var w = 0; w < 6; w++) {
        var days = []
        for (var d = 0; d < 7; d++) {
            var cellYear = cursor.getFullYear()
            var cellMonth = cursor.getMonth()
            var cellDay = cursor.getDate()
            days.push({
                year: cellYear,
                month: cellMonth,
                day: cellDay,
                weekday: cursor.getDay(),
                inMonth: cellMonth === month && cellYear === year,
                weekend: cursor.getDay() === 0 || cursor.getDay() === 6,
                today: dateKey(cellYear, cellMonth, cellDay) === today
            })
            cursor.setDate(cursor.getDate() + 1)
        }

        weeks.push(days)
    }

    return weeks
}

function stepMonth(year, month, delta) {
    var target = new Date(year, Number(month) + Number(delta), 1)
    return {
        "year": target.getFullYear(),
        "month": target.getMonth()
    }
}

// Clamp a day-of-month into the length of its month, e.g. Jan 31 -> Feb 28.
function clampDay(year, month, day) {
    return Math.max(1, Math.min(day, new Date(year, Number(month) + 1, 0).getDate()))
}

if (typeof module !== "undefined") {
    module.exports = {
        dateKey: dateKey,
        normalizedWeekStart: normalizedWeekStart,
        weekdayOrder: weekdayOrder,
        monthGrid: monthGrid,
        stepMonth: stepMonth,
        clampDay: clampDay
    }
}