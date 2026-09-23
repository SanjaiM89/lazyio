.pragma library

// Promise wrapper around the C++ ApiBridge (callback -> Promise).
// Mirrors FrontEnd/src/api.js endpoint-for-endpoint.

function _call(fn) {
    return new Promise(function (resolve, reject) {
        try {
            fn(function (res) {
                if (res && res.ok)
                    resolve(res.data);
                else
                    reject({ status: res ? res.status : -1, error: res ? res.error : "no response" });
            });
        } catch (e) {
            reject({ status: -1, error: String(e) });
        }
    });
}

function get(path, params) {
    return _call(function (cb) { Api.get(path, params || {}, cb); });
}
function post(path, params, body) {
    return _call(function (cb) { Api.post(path, params || {}, body || {}, cb); });
}
function del(path, params) {
    return _call(function (cb) { Api.del(path, params || {}, cb); });
}

function streamUrl(id) { return Api.streamUrl(id); }
function videoStreamUrl(id) { return Api.videoStreamUrl(id); }
function wsUrl() { return Api.wsUrl(); }

// ---- songs ----
function songsPaginated(page, limit) { return get("/songs/paginated", { page: page, limit: limit }); }
function deleteSong(id) { return del("/songs/" + id, {}); }
function recordPlay(id) { return post("/songs/" + id + "/play", {}, {}); }
function getLyrics(id, refresh) { return get("/songs/" + id + "/lyrics", refresh ? { refresh: true } : {}); }
// ---- library ----
function albums(page, limit) { return get("/albums", { page: page, limit: limit }); }
function album(id) { return get("/albums/" + id, {}); }
function artists(page, limit, query) { return get("/artists", { page: page, limit: limit, query: query || "" }); }
function artist(name) { return get("/artists/" + encodeURIComponent(name), {}); }
// ---- search ----
function search(q, songLimit, albumLimit, artistLimit, songOffset) {
    return get("/search", { q: q, song_limit: songLimit || 20, album_limit: albumLimit || 8, artist_limit: artistLimit || 8, song_offset: songOffset || 0 });
}
function suggest(q, limit) { return get("/search/suggest", { q: q, limit: limit || 6 }); }
// ---- playlists ----
function playlists(page, limit) { return get("/playlists", { page: page, limit: limit || 20 }); }
function playlist(id) { return get("/playlists/" + id, {}); }
function createPlaylist(name, songs) { return post("/playlists", {}, { name: name, songs: songs || [] }); }
function deletePlaylist(id) { return del("/playlists/" + id, {}); }
function addToPlaylist(pid, sid) { return post("/playlists/" + pid + "/songs", { song_id: sid }, {}); }
function removeFromPlaylist(pid, sid) { return del("/playlists/" + pid + "/songs/" + sid, {}); }
// ---- home / recommend ----
function homepage() { return get("/home", {}); }
function refreshHomepage() { return post("/home/refresh", {}, {}); }
function similar(id, limit) { return get("/recommend/similar/" + id, { limit: limit || 6 }); }
// ---- telegram ----
function scanChannel(force) { return post("/telegram/scan", { force: !!force }, {}); }
function scanStatus() { return get("/telegram/scan/status", {}); }
