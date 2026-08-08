import { test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const D = require("../../public/dead_code_session.js");

test("parseState returns empty state on garbage", () => {
  assert.deepEqual(D.parseState(null), D.emptyState());
  assert.deepEqual(D.parseState("{not json"), D.emptyState());
  assert.deepEqual(D.parseState('{"hiddenPaths": "nope"}').hiddenPaths, []);
});

test("parseState keeps valid entries and normalizes marks", () => {
  const s = D.parseState(JSON.stringify({
    hiddenPaths: ["app/", 5, "lib/foo.rb"],
    markedPaths: [{ path: "old/" }, { nope: true }],
    hideRuntimeUsed: true
  }));
  assert.deepEqual(s.hiddenPaths, ["app/", "lib/foo.rb"]);
  assert.deepEqual(s.markedPaths, [{ path: "old/", comment: "", markedAt: "" }]);
  assert.equal(s.hideRuntimeUsed, true);
});

test("pathMatches: folder prefix vs exact file", () => {
  assert.ok(D.pathMatches("app/models/", "app/models/foo.rb"));
  assert.ok(!D.pathMatches("app/models/", "app/models2/foo.rb"));
  assert.ok(D.pathMatches("app/foo.rb", "app/foo.rb"));
  assert.ok(!D.pathMatches("app/foo.rb", "app/foo.rb.bak"));
});

test("isExcluded combines hides, marks, and runtime rule", () => {
  const s = D.emptyState();
  D.addHidden(s, "app/hidden/");
  D.addMark(s, "lib/dead.rb", "bye", "2026-08-07T00:00:00Z");
  assert.ok(D.isExcluded(s, "app/hidden/x.rb", 0));
  assert.ok(D.isExcluded(s, "lib/dead.rb", 0));
  assert.ok(!D.isExcluded(s, "app/live.rb", 12.5));
  s.hideRuntimeUsed = true;
  assert.ok(D.isExcluded(s, "app/live.rb", 12.5));
  assert.ok(!D.isExcluded(s, "app/unused.rb", 0));
  assert.ok(!D.isExcluded(s, "app/unknown.rb", null));
});

test("addHidden dedupes; removeHidden removes; clearHides resets toggle", () => {
  const s = D.emptyState();
  D.addHidden(s, "app/");
  D.addHidden(s, "app/");
  assert.deepEqual(s.hiddenPaths, ["app/"]);
  D.removeHidden(s, "app/");
  assert.deepEqual(s.hiddenPaths, []);
  s.hideRuntimeUsed = true;
  D.addHidden(s, "x.rb");
  D.clearHides(s);
  assert.deepEqual(s.hiddenPaths, []);
  assert.equal(s.hideRuntimeUsed, false);
});

test("addMark replaces same path; updateComment; removeMark; clearMarks", () => {
  const s = D.emptyState();
  D.addMark(s, "a.rb", "one", "t1");
  D.addMark(s, "a.rb", "two", "t2");
  assert.deepEqual(s.markedPaths, [{ path: "a.rb", comment: "two", markedAt: "t2" }]);
  D.updateComment(s, "a.rb", "three");
  assert.equal(s.markedPaths[0].comment, "three");
  D.removeMark(s, "a.rb");
  assert.deepEqual(s.markedPaths, []);
  D.addMark(s, "b.rb", "", "t");
  D.clearMarks(s);
  assert.deepEqual(s.markedPaths, []);
});

test("toCSV escapes per RFC 4180", () => {
  const csv = D.toCSV([
    { path: "app/a.rb", comment: 'has "quotes", commas\nand newline', markedAt: "2026-08-07T01:02:03Z" },
    { path: "lib/", comment: "", markedAt: "" }
  ]);
  assert.equal(csv,
    'path,comment,marked_at\r\n' +
    'app/a.rb,"has ""quotes"", commas\nand newline",2026-08-07T01:02:03Z\r\n' +
    'lib/,,\r\n');
});

test("segmentPrefixes splits path into cumulative prefixes", () => {
  assert.deepEqual(D.segmentPrefixes("app/models/foo.rb"), [
    { label: "app", prefix: "app/", isFile: false },
    { label: "models", prefix: "app/models/", isFile: false },
    { label: "foo.rb", prefix: "app/models/foo.rb", isFile: true }
  ]);
  assert.deepEqual(D.segmentPrefixes("foo.rb"), [{ label: "foo.rb", prefix: "foo.rb", isFile: true }]);
});

test("isExcludedIgnoringMarks applies hides and runtime rule but never marks", () => {
  const s = D.emptyState();
  D.addHidden(s, "app/hidden/");
  D.addMark(s, "lib/dead.rb", "bye", "2026-08-07T00:00:00Z");
  assert.ok(D.isExcludedIgnoringMarks(s, "app/hidden/x.rb", 0));
  assert.ok(!D.isExcludedIgnoringMarks(s, "lib/dead.rb", 0), "marks alone must not exclude");
  s.hideRuntimeUsed = true;
  assert.ok(D.isExcludedIgnoringMarks(s, "app/live.rb", 12.5));
  assert.ok(!D.isExcludedIgnoringMarks(s, "app/unused.rb", 0));
});

test("extractPath pulls the title attribute out of a rendered cell", () => {
  assert.equal(D.extractPath('<a class="src_link" title="app/models/foo.rb">foo.rb</a>'), "app/models/foo.rb");
  assert.equal(D.extractPath("<span>no title here</span>"), "");
  assert.equal(D.extractPath(42), "");
});

test("rowRuntime parses the runtime column, null when not numeric", () => {
  assert.equal(D.rowRuntime(["path", "link", "12.5"]), 12.5);
  assert.equal(D.rowRuntime(["path", "link", "0"]), 0);
  assert.equal(D.rowRuntime(["path", "link", "-"]), null);
  assert.equal(D.rowRuntime(["path", "link", undefined]), null);
});

test("escapeHtml escapes the five HTML-significant characters", () => {
  assert.equal(D.escapeHtml('<b>"Tom" & Jerry</b>'), "&lt;b&gt;&quot;Tom&quot; &amp; Jerry&lt;/b&gt;");
  assert.equal(D.escapeHtml("plain"), "plain");
});

test("csvFilename embeds the ISO date", () => {
  assert.equal(D.csvFilename(new Date("2026-08-07T15:04:05Z")), "coverband-dead-code-2026-08-07.csv");
});
