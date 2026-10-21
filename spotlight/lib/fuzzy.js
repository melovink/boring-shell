// Fuzzy ranker for the spotlight launcher.
//
// Tiers per token: 0 = name prefix, 1 = substring in name/keywords,
// 2 = loose subsequence in those fields, 3 = exec only. 99 means "no match".
// A query with several words is AND-per-token, so "fire fox" still finds Firefox;
// the entry's total is the sum of its per-token tiers, which keeps tighter matches
// ahead of looser ones. Exec sits in its own bottom tier so typing a command
// fragment still surfaces an app, without long Exec= strings crowding out real
// name matches.
//
// Adapted from quickshell.other/launcher/lib/fuzzy.js with multi-token support
// added. The frecency/usage tiebreak is kept but currently always fed a null
// usage map, so ties resolve alphabetically.

function haystacks(e) {
    var parts = [];
    if (e.name) parts.push(String(e.name));
    if (e.genericName) parts.push(String(e.genericName));
    if (e.keywords) for (var i = 0; i < e.keywords.length; i++) parts.push(String(e.keywords[i]));
    return parts;
}

function execHay(e) {
    var parts = [];
    if (e.execString) parts.push(String(e.execString));
    if (e.command) parts.push(String(e.command));
    if (e.kind === "appimage" && e.path) parts.push(String(e.path));
    return parts;
}

function subsequence(needle, hay) {
    var j = 0;
    for (var i = 0; i < hay.length && j < needle.length; i++)
        if (hay[i] === needle[j]) j++;
    return j === needle.length;
}

function score(e, q) {
    var name = (e.name || "").toLowerCase();
    if (name.indexOf(q) === 0) return 0;
    var fields = haystacks(e);
    var best = 99;
    for (var i = 0; i < fields.length; i++) {
        var f = fields[i].toLowerCase();
        if (f.indexOf(q) !== -1) { best = Math.min(best, 1); continue; }
        if (subsequence(q, f)) best = Math.min(best, 2);
    }
    // Any hit on a name/keyword field outranks exec entirely.
    if (best <= 2) return best;
    var exec = execHay(e);
    for (var k = 0; k < exec.length; k++) {
        var x = exec[k].toLowerCase();
        if (x.indexOf(q) !== -1 || subsequence(q, x)) return 3;
    }
    return best;
}

function uses(usage, e) {
    if (!usage || !e || !e.id) return 0;
    var c = usage[e.id];
    return typeof c === "number" ? c : 0;
}

function rank(entries, query, usage) {
    usage = usage || {};
    var visible = [];
    for (var i = 0; i < entries.length; i++)
        if (!entries[i].noDisplay) visible.push(entries[i]);

    var q = (query || "").trim().toLowerCase();
    if (q.length === 0)
        return visible.slice().sort(function (a, b) {
            var ua = uses(usage, a);
            var ub = uses(usage, b);
            if (ua !== ub) return ub - ua;
            return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase());
        });

    var tokens = q.split(/\s+/);
    var scored = [];
    for (var k = 0; k < visible.length; k++) {
        var total = 0;
        var matched = true;
        for (var t = 0; t < tokens.length; t++) {
            var s = score(visible[k], tokens[t]);
            if (s > 98) { matched = false; break; }
            total += s;
        }
        if (matched) scored.push({ e: visible[k], s: total });
    }
    scored.sort(function (a, b) {
        if (a.s !== b.s) return a.s - b.s;
        var ua = uses(usage, a.e);
        var ub = uses(usage, b.e);
        if (ua !== ub) return ub - ua;
        return (a.e.name || "").toLowerCase().localeCompare((b.e.name || "").toLowerCase());
    });
    return scored.map(function (x) { return x.e; });
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { rank, score, subsequence };
}