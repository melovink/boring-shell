import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { rank, score, subsequence } = require("./fuzzy.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, msg) { eq(!!cond, true, msg); }

const apps = [
    { id: "spotify.desktop", name: "Spotify", genericName: "Musik", keywords: ["audio", "stream"], noDisplay: false },
    { id: "files.desktop", name: "Files", genericName: "File Manager", keywords: [], noDisplay: false },
    { id: "firefox.desktop", name: "Firefox", genericName: "Web Browser", keywords: ["www", "internet"], noDisplay: false },
    { id: "settings-daemon.desktop", name: "Settings Daemon", genericName: "", keywords: [], noDisplay: true },
    { id: "steam.desktop", name: "Steam", genericName: "Game Launcher", keywords: ["games"], noDisplay: false },
    { id: "firewall.desktop", name: "Firewall", genericName: "Network", keywords: ["net"], noDisplay: false }
];

const names = (q, usage) => rank(apps, q, usage).map((e) => e.name);

ok(subsequence("spt", "spotify"), "subsequence spt in spotify");
ok(!subsequence("xyz", "spotify"), "subsequence xyz not in spotify");

eq(names(""), ["Files", "Firefox", "Firewall", "Spotify", "Steam"], "empty query lists visible apps alphabetically, drops noDisplay");

eq(names("spo")[0], "Spotify", "prefix match ranks first");
eq(names("fi"), ["Files", "Firefox", "Firewall"], "every prefix match is kept, ties alphabetical");

ok(names("musik").indexOf("Spotify") !== -1, "genericName substring matches");
ok(names("internet").indexOf("Firefox") !== -1, "keyword substring matches");

eq(names("gam"), ["Steam"], "keyword substring match (gam -> Steam via games)");

eq(names("zzz"), [], "no match returns empty");

ok(rank(apps, "s").indexOf(apps[3]) === -1, "noDisplay excluded even on match");

eq(names("Spo"), ["Spotify"], "case-insensitive prefix");

// ---- multi-token, AND-per-token ----
eq(names("fire fox"), ["Firefox"], "words split mid-name still match Firefox");
eq(names("net fire"), ["Firefox", "Firewall"], "one token hits a keyword, the other the name");
eq(names("fire net brow"), ["Firefox"], "three tokens, all matched across name+genericName+keywords");
eq(names("spot net"), [], "tokens matching different entries produce nothing");
eq(names("fire"), ["Firefox", "Firewall"], "single token behaves as before");
ok(names("fire fox")[0] === "Firefox", "Firefox outranks Firewall on a two-token query");
eq(names("  fire  "), ["Firefox", "Firewall"], "surrounding whitespace is trimmed");

// ---- tier ordering ----
eq(score(apps[2], "fire"), 0, "prefix is tier 0");
eq(score(apps[2], "fox"), 1, "substring is tier 1");
eq(score(apps[2], "frfx"), 2, "loose subsequence is tier 2");
eq(score(apps[2], "qqqq"), 99, "no match is tier 99");

// ---- usage tiebreak (kept for the frecency path, unused in production) ----
eq(names("", { "steam.desktop": 5, "firefox.desktop": 2 }), ["Steam", "Firefox", "Files", "Firewall", "Spotify"], "empty query orders by usage desc then alphabetical");
eq(names("fire", { "firefox.desktop": 3 }), ["Firefox", "Firewall"], "query results tie-break by usage desc");

// ---- exec fallback tier ----
const withExec = [
    { id: "term.desktop", name: "Terminal", genericName: "", keywords: [], execString: "xterm -e bash" },
    { id: "term2.desktop", name: "Konsole", genericName: "", keywords: [], command: "konsole" },
    { id: "img", name: "Helium", genericName: "", keywords: [], kind: "appimage", path: "/home/melovink/AppImage/helium.AppImage" }
];
const execNames = (q) => rank(withExec, q).map((e) => e.name);

eq(score(withExec[0], "xterm"), 3, "exec substring is tier 3");
eq(score(withExec[0], "xtrm"), 3, "exec subsequence is tier 3");
eq(score(withExec[0], "term"), 0, "name prefix still beats exec");
eq(execNames("xterm"), ["Terminal"], "exec substring surfaces the entry");
eq(execNames("konso"), ["Konsole"], "command field is searched like execString");
eq(execNames("helium.appimage"), ["Helium"], "AppImage path is searchable");
eq(execNames("appimage"), ["Helium"], "AppImage file extension finds the image");
eq(score(withExec[2], "nomatchatall"), 99, "no name, keyword or exec match is tier 99");
eq(rank(withExec, "zzzz"), [], "queries matching nothing still return empty");

// ---- a name match always outranks an exec-only match ----
const mixed = withExec.concat([{ id: "x.desktop", name: "Xtermy", genericName: "", keywords: [], execString: "" }]);
eq(rank(mixed, "xterm").map((e) => e.name), ["Xtermy", "Terminal"], "name prefix ranks above exec-only match");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");