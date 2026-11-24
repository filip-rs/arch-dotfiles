.pragma library

// Matching, ranking and command building for Launcher.qml. No QML in here, so
// it can be tested with node (see the bottom of the file).
//
// Matching is on the app NAME only: every word of the query has to appear in
// the name (case- and accent-insensitive). That rule matters for auto-launch:
// typing one more letter can only remove matches, never add them, so an app
// that is the only match part-way through the name is always the app being
// typed. Searching keywords/Exec as well would make many apps never unique
// (web apps all run librewolf, Steam games all run steam).
//
// When nothing matches by name, the generic name, keywords, binary and id are
// searched instead ("browser" finds LibreWolf). Those results never
// auto-launch. Once the name matches are gone, more typing can't bring them
// back, so this fallback can't turn into a wrong launch either.

function fold(s) {
    s = String(s || "").toLowerCase();
    return typeof s.normalize === "function" ? s.normalize("NFD").replace(/[̀-ͯ]/g, "") : s;
}

function toArray(list) {
    let out = [];
    if (!list) return out;
    for (let i = 0; i < list.length; i++) out.push(String(list[i]));
    return out;
}

// Folded offsets where a word starts: the beginning, after a separator, and
// camelCase humps ("PrismLauncher", "qBittorrent").
function wordStarts(name) {
    let starts = [0];
    for (let i = 1; i < name.length; i++) {
        const prev = name[i - 1], cur = name[i];
        const prevAlnum = /[0-9A-Za-zÀ-ɏ]/.test(prev);
        const curAlnum = /[0-9A-Za-zÀ-ɏ]/.test(cur);
        if (curAlnum && (!prevAlnum || (prev === prev.toLowerCase() && cur !== cur.toLowerCase())))
            starts.push(i);
    }
    return starts;
}

// One record per visible entry. `entries` are Quickshell DesktopEntry objects
// (or plain objects with the same fields, for tests).
function buildIndex(entries, hiddenNames) {
    let out = [], seen = {};
    for (let i = 0; i < entries.length; i++) {
        const e = entries[i];
        if (!e || e.noDisplay) continue;
        const name = String(e.name || "").trim();
        if (name === "") continue;
        if ((hiddenNames || []).some(re => re.test(name))) continue;

        const command = toArray(e.command);
        // The same app installed twice (native + Flatpak, or a copied .desktop
        // file) would otherwise never become a unique match.
        const key = name + "\u0000" + command.join(" ");
        if (seen[key]) continue;
        seen[key] = true;

        const exe = command.length > 0 ? command[0].split("/").pop() : "";
        out.push({
            entry: e,
            id: String(e.id || name),
            name: name,
            nameKey: fold(name),
            starts: wordStarts(name),
            extraKey: fold([e.genericName || "", toArray(e.keywords).join(" "), exe, e.id || ""].join(" ")),
            icon: String(e.icon || "")
        });
    }
    return out;
}

function tokenize(query) {
    const q = fold(query).trim();
    return q === "" ? [] : q.split(/\s+/);
}

// Lower is better.
function nameTier(rec, q) {
    if (rec.nameKey === q) return 0;
    if (rec.nameKey.startsWith(q)) return 1;
    if (rec.starts.some(i => rec.nameKey.startsWith(q, i))) return 2;
    if (rec.nameKey.indexOf(q) !== -1) return 3;
    return 4; // words matched separately
}

// Launch count that fades with time, so last month's binge doesn't win forever.
function frecency(usage, id, now) {
    const u = usage ? usage[id] : null;
    if (!u || !u.n) return 0;
    const days = Math.max(0, (now - (u.t || 0)) / 86400000);
    return u.n / (1 + days / 14);
}

// Returns { results: [record], fallback: bool }.
function search(index, query, usage, now) {
    const tokens = tokenize(query);
    let hits = [];

    if (tokens.length === 0) {
        for (const rec of index) hits.push({ rec: rec, tier: 0, f: frecency(usage, rec.id, now) });
    } else {
        const q = tokens.join(" ");
        for (const rec of index) {
            if (tokens.every(t => rec.nameKey.indexOf(t) !== -1))
                hits.push({ rec: rec, tier: nameTier(rec, q), f: frecency(usage, rec.id, now) });
        }
    }

    const fallback = hits.length === 0 && tokens.length > 0;
    if (fallback) {
        for (const rec of index) {
            const hay = rec.nameKey + " " + rec.extraKey;
            if (tokens.every(t => hay.indexOf(t) !== -1))
                hits.push({ rec: rec, tier: 0, f: frecency(usage, rec.id, now) });
        }
    }

    // Shorter names first among equals ("Steam" before "Steam Link"), but not
    // for the empty query, where the list is just alphabetical.
    const byLength = tokens.length > 0;
    hits.sort((a, b) => (a.tier - b.tier) || (b.f - a.f)
                     || (byLength ? a.rec.name.length - b.rec.name.length : 0)
                     || a.rec.name.localeCompare(b.rec.name));
    return { results: hits.map(h => h.rec), fallback: fallback };
}

function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Name as StyledText with the matched parts wrapped in <b>.
function highlight(rec, query, color) {
    const tokens = tokenize(query);
    const name = rec.name;
    // Folding can change the length for a few odd characters; skip the
    // highlight rather than mark the wrong letters.
    if (tokens.length === 0 || rec.nameKey.length !== name.length) return escapeHtml(name);

    let marked = new Array(name.length).fill(false);
    for (const t of tokens) {
        // Prefer a word start, like the ranking does.
        let at = rec.starts.find(i => rec.nameKey.startsWith(t, i));
        if (at === undefined) at = rec.nameKey.indexOf(t);
        if (at < 0) continue;
        for (let i = at; i < at + t.length; i++) marked[i] = true;
    }

    let out = "", open = false;
    for (let i = 0; i < name.length; i++) {
        if (marked[i] && !open) { out += "<b><font color=\"" + color + "\">"; open = true; }
        if (!marked[i] && open) { out += "</font></b>"; open = false; }
        out += escapeHtml(name[i]);
    }
    if (open) out += "</font></b>";
    return out;
}

function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

// Shell command for Hyprland's exec_cmd. Field codes are already stripped
// from DesktopEntry.command by Quickshell.
function shellCommand(entry) {
    const argv = toArray(entry.command);
    if (argv.length === 0) return "";
    let cmd = argv.map(shellQuote).join(" ");
    if (entry.runInTerminal) cmd = "\"${TERMINAL:-alacritty}\" -e " + cmd;
    if (entry.workingDirectory) cmd = "cd " + shellQuote(entry.workingDirectory) + " && " + cmd;
    return cmd;
}

// A Lua long string ([==[...]==]) that can hold `s` verbatim, no escaping.
function luaString(s) {
    let eq = "";
    while (s.indexOf("]" + eq + "]") !== -1) eq += "=";
    return "[" + eq + "[" + s + "]" + eq + "]";
}

// Tests: sed '1d' search.js > /tmp/s.js && node /tmp/s.js
if (typeof process !== "undefined" && typeof require !== "undefined" && require.main === module) {
    const assert = require("assert");
    const E = (name, extra) => Object.assign({ id: name.toLowerCase(), name: name, command: [name.toLowerCase()] }, extra || {});
    const idx = buildIndex([
        E("Prism Launcher", { command: ["prismlauncher"] }),
        E("Print Settings"), E("LibreWolf", { genericName: "Web Browser" }), E("Librewolf - Skole"),
        E("Steam"), E("Steam Linux Runtime 3.0 (sniper)"), E("Proton Experimental"), E("ProtonUp-Qt"),
        E("qBittorrent"), E("Files", { command: ["nautilus", "--new-window"] }), E("Hidden", { noDisplay: true }),
        E("Café"), E("Steam")
    ], [/^Steam Linux Runtime/, /^Proton (Experimental|Hotfix|[0-9])/]);
    const names = (q, u) => search(idx, q, u || {}, 0).results.map(r => r.name);

    assert.deepStrictEqual(names("pris"), ["Prism Launcher"]);
    assert.deepStrictEqual(names("pri").sort(), ["Print Settings", "Prism Launcher"]);
    assert.deepStrictEqual(names("steam"), ["Steam"], "runtimes hidden, duplicate merged");
    assert.deepStrictEqual(names("librewolf"), ["LibreWolf", "Librewolf - Skole"], "exact name first");
    assert.deepStrictEqual(names("bit"), ["qBittorrent"], "camelCase hump");
    assert.deepStrictEqual(names("launcher pr"), ["Prism Launcher"]);
    assert.deepStrictEqual(names("cafe"), ["Café"]);
    assert.ok(!names("").includes("Hidden"));
    assert.deepStrictEqual(names("").slice(0, 3), ["Café", "Files", "LibreWolf"], "empty query is alphabetical");
    let r = search(idx, "browser", {}, 0);
    assert.ok(r.fallback && r.results[0].name === "LibreWolf");
    r = search(idx, "nautilus", {}, 0);
    assert.ok(r.fallback && r.results[0].name === "Files");
    assert.deepStrictEqual(names("li", { "librewolf - skole": { n: 5, t: 0 } }).slice(0, 2), ["Librewolf - Skole", "LibreWolf"], "usage breaks ties");

    // Every app reached by typing its own name must never auto-launch another app.
    for (const rec of idx) {
        for (let n = 1; n <= rec.nameKey.length; n++) {
            const res = search(idx, rec.nameKey.slice(0, n), {}, 0);
            if (!res.fallback && res.results.length === 1) { assert.strictEqual(res.results[0], rec); break; }
        }
    }

    assert.strictEqual(highlight(idx[0], "lau", "#fff"), "Prism <b><font color=\"#fff\">Lau</font></b>ncher");
    assert.strictEqual(shellCommand({ command: ["sh", "-c", "echo 'hi'"] }), "'sh' '-c' 'echo '\\''hi'\\'''");
    assert.strictEqual(shellCommand({ command: ["btop"], runInTerminal: true }), "\"${TERMINAL:-alacritty}\" -e 'btop'");
    assert.strictEqual(luaString("a]]b]=]c"), "[==[a]]b]=]c]==]");
    console.log("search.js: all tests passed");
}
