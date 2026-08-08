// Pure logic for the dead-code review session. Loaded in the browser as
// window.CoverbandDeadCode and in Node (tests) via require.
(function (root, factory) {
  if (typeof module === "object" && module.exports) {
    module.exports = factory();
  } else {
    root.CoverbandDeadCode = factory();
  }
})(typeof self !== "undefined" ? self : this, function () {
  function emptyState() {
    return { hiddenPaths: [], markedPaths: [], hideRuntimeUsed: false, startedAt: null };
  }

  function parseState(json) {
    var raw;
    try { raw = JSON.parse(json); } catch (e) { raw = null; }
    var state = emptyState();
    if (!raw || typeof raw !== "object") return state;
    if (Object.prototype.toString.call(raw.hiddenPaths) === "[object Array]") {
      state.hiddenPaths = raw.hiddenPaths.filter(function (p) {
        return typeof p === "string" && p.length > 0;
      });
    }
    if (Object.prototype.toString.call(raw.markedPaths) === "[object Array]") {
      state.markedPaths = raw.markedPaths.filter(function (m) {
        return m && typeof m.path === "string" && m.path.length > 0;
      }).map(function (m) {
        return {
          path: m.path,
          comment: typeof m.comment === "string" ? m.comment : "",
          markedAt: typeof m.markedAt === "string" ? m.markedAt : ""
        };
      });
    }
    state.hideRuntimeUsed = raw.hideRuntimeUsed === true;
    state.startedAt = typeof raw.startedAt === "string" ? raw.startedAt : null;
    return state;
  }

  function pathMatches(entry, path) {
    if (entry.charAt(entry.length - 1) === "/") return path.indexOf(entry) === 0;
    return path === entry;
  }

  function matchesAny(entries, path) {
    for (var i = 0; i < entries.length; i++) {
      if (pathMatches(entries[i], path)) return true;
    }
    return false;
  }

  function isMarked(state, path) {
    for (var i = 0; i < state.markedPaths.length; i++) {
      if (pathMatches(state.markedPaths[i].path, path)) return true;
    }
    return false;
  }

  function isExcludedIgnoringMarks(state, path, runtimePercent) {
    if (matchesAny(state.hiddenPaths, path)) return true;
    if (state.hideRuntimeUsed && typeof runtimePercent === "number" && runtimePercent > 0) return true;
    return false;
  }

  function isExcluded(state, path, runtimePercent) {
    return isExcludedIgnoringMarks(state, path, runtimePercent) || isMarked(state, path);
  }

  function addHidden(state, entry) {
    if (state.hiddenPaths.indexOf(entry) === -1) state.hiddenPaths.push(entry);
  }

  function removeHidden(state, entry) {
    var i = state.hiddenPaths.indexOf(entry);
    if (i !== -1) state.hiddenPaths.splice(i, 1);
  }

  function clearHides(state) {
    state.hiddenPaths = [];
    state.hideRuntimeUsed = false;
  }

  function addMark(state, path, comment, markedAt) {
    removeMark(state, path);
    state.markedPaths.push({ path: path, comment: comment || "", markedAt: markedAt || "" });
  }

  function removeMark(state, path) {
    for (var i = state.markedPaths.length - 1; i >= 0; i--) {
      if (state.markedPaths[i].path === path) state.markedPaths.splice(i, 1);
    }
  }

  function updateComment(state, path, comment) {
    for (var i = 0; i < state.markedPaths.length; i++) {
      if (state.markedPaths[i].path === path) state.markedPaths[i].comment = comment;
    }
  }

  function clearMarks(state) {
    state.markedPaths = [];
  }

  function csvField(value) {
    var s = String(value == null ? "" : value);
    if (/[",\n\r]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
    return s;
  }

  function toCSV(markedPaths) {
    var lines = ["path,comment,marked_at"];
    for (var i = 0; i < markedPaths.length; i++) {
      var m = markedPaths[i];
      lines.push([csvField(m.path), csvField(m.comment), csvField(m.markedAt)].join(","));
    }
    return lines.join("\r\n") + "\r\n";
  }

  function segmentPrefixes(path) {
    var parts = path.split("/");
    var out = [];
    var prefix = "";
    for (var i = 0; i < parts.length; i++) {
      var isFile = i === parts.length - 1;
      prefix += parts[i] + (isFile ? "" : "/");
      out.push({ label: parts[i], prefix: prefix, isFile: isFile });
    }
    return out;
  }

  // Extracts the full path from a DataTables cell's rendered HTML (the
  // title attribute on the source link), e.g. '<a title="app/foo.rb">foo.rb</a>'.
  function extractPath(cellHtml) {
    var m = String(cellHtml).match(/title="([^"]*)"/);
    return m ? m[1] : "";
  }

  // Parses the runtime % column (aData[2]) of a report row into a number,
  // or null when it isn't numeric (e.g. "-" for untracked files).
  function rowRuntime(aData) {
    var n = parseFloat(String(aData[2]));
    return isNaN(n) ? null : n;
  }

  function escapeHtml(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function csvFilename(date) {
    return "coverband-dead-code-" + date.toISOString().slice(0, 10) + ".csv";
  }

  return {
    emptyState: emptyState,
    parseState: parseState,
    pathMatches: pathMatches,
    isExcluded: isExcluded,
    isExcludedIgnoringMarks: isExcludedIgnoringMarks,
    addHidden: addHidden,
    removeHidden: removeHidden,
    clearHides: clearHides,
    addMark: addMark,
    removeMark: removeMark,
    updateComment: updateComment,
    clearMarks: clearMarks,
    toCSV: toCSV,
    segmentPrefixes: segmentPrefixes,
    extractPath: extractPath,
    rowRuntime: rowRuntime,
    escapeHtml: escapeHtml,
    csvFilename: csvFilename
  };
});
