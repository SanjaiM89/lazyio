.pragma library

// Tiny typo-tolerant matcher for instant local results
// (server search stays the source of truth).
function norm(s) {
    return (s || "").toLowerCase().replace(/[^a-z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
}

function tokenScore(qt, text) {
    // 1.0 exact-substring, else best word-level similarity (0..1)
    var t = norm(text);
    if (!t || !qt)
        return 0;
    if (t.indexOf(qt) !== -1)
        return 1.0;
    var words = t.split(" ");
    var best = 0;
    for (var i = 0; i < words.length; i++) {
        var w = words[i];
        if (!w)
            continue;
        var s = similarity(qt, w);
        if (s > best)
            best = s;
    }
    return best * 0.85;
}

function similarity(a, b) {
    // Jaro-Winkler-ish cheap similarity via longest common subsequence ratio
    if (a === b)
        return 1.0;
    var m = a.length, n = b.length;
    if (!m || !n)
        return 0;
    var prev = new Array(n + 1).fill(0);
    for (var i = 1; i <= m; i++) {
        var cur = [i];
        for (var j = 1; j <= n; j++)
            cur[j] = a[i - 1] === b[j - 1] ? prev[j - 1] + 1 : Math.max(prev[j], cur[j - 1]);
        prev = cur;
    }
    var lcs = prev[n] / Math.max(m, n);
    var prefix = 0;
    while (prefix < 4 && prefix < m && prefix < n && a[prefix] === b[prefix])
        prefix++;
    return lcs + prefix * 0.05 * (1 - lcs);
}

function fuzzySongs(songs, query, limit) {
    var q = norm(query);
    if (q.length < 2)
        return [];
    var scored = [];
    for (var i = 0; i < songs.length; i++) {
        var s = songs[i];
        var score = Math.max(
            tokenScore(q, s.title) * 1.0,
            tokenScore(q, s.artist) * 0.7,
            tokenScore(q, s.album) * 0.4
        );
        if (score >= 0.55)
            scored.push({ s: s, score: score });
    }
    scored.sort(function (a, b) { return b.score - a.score; });
    return scored.slice(0, limit || 6).map(function (x) { return x.s; });
}

function mergeSongs(serverSongs, localSongs) {
    var seen = {}, out = [];
    [serverSongs || [], localSongs || []].forEach(function (list) {
        list.forEach(function (s) {
            if (s && s.id && !seen[s.id]) {
                seen[s.id] = true;
                out.push(s);
            }
        });
    });
    return out;
}
