$(document).ready(function () {
  // remove the url params like notice=message so they don't stick around
  window.history.replaceState(
    "object or string",
    "Coverband",
    window.location.href.replace(/notice=.*/, "")
  );
  $(".notice")
    .delay(3000)
    .fadeOut("slow");

  $(".del").click(function () {
    if (!confirm("Do you want to delete")) {
      return false;
    }
  });

  // Configuration for fancy sortable tables for source file groups
  var tableOptions = {
    aaSorting: [[1, "asc"]],
    bPaginate: false,
    bJQueryUI: true,
    aoColumns: [
      null,
      { sType: "percent" },
      { sType: "percent" },
      null,
      null,
      null,
      null,
      null,
      null
    ],
  }

  tableOptions.fnDrawCallback = function (oSettings) {
    if (window.deadCodeOnDraw) window.deadCodeOnDraw(oSettings);
  };

  $(".file_list").dataTable(tableOptions);

  initDeadCodeSession();

  // TODO: add support for searching on server side
  // best docs on our version of datatables 1.7 https://datatables.net/beta/1.7/examples/server_side/server_side.html
  if ($(".file_list.unsorted").length == 1) {
    $(".dataTables_empty").html("loading...");
    var total_rows = 0;
    var page = 1;
    var all_data = [];

    // load and render page content before we start the loop
    // perhaps move this into a datatable ready event
    $(".dataTables_empty").html("loading...");
    setTimeout(() => {
      get_page(page);
    }, 1200);

    function get_page(page) {
      $.ajax({
        url: `${$(".file_list").data("coverageurl")}/report_json?page=${page}`,
        type: 'GET',
        dataType: 'json',
        success: function (data) {
          total_rows = data["iTotalRecords"];
          all_data = all_data.concat(data["aaData"]);
          $(".dataTables_empty").html("loading... on " + all_data.length + " of " + total_rows + " files");
          page += 1;

          // the page less than 50 is to stop infinite loop in case of folks never clearing out old coverage reports
          if (page < 50 && all_data.length <= total_rows && data["aaData"].length > 0) {
            setTimeout(() => {
              get_page(page);
            }, 10);
          } else {
            $(".file_list.unsorted").dataTable().fnAddData(all_data);
            // allow rendering to complete before we click the anchor
            setTimeout(() => {
              if (window.auto_click_anchor && $(window.auto_click_anchor).length > 0) {
                $(window.auto_click_anchor).click();
              }
            }, 50)
          }
        }
      });
    }
  }

  src_link_click = (trigger_element) => {
    var loader_url = $(trigger_element).attr("data-loader-url");
    auto_click_anchor = null;
    $(trigger_element).colorbox(jQuery.extend(colorbox_options, { href: loader_url }));
  };

  var colorbox_options = {
    transition: "none",
    opacity: 1,
    width: "95%",
    height: "95%",
    onLoad: function () {
      // If not highlighted yet, do it!
      var source_table = $(".shared_source_table");
      if (!source_table.hasClass("highlighted")) {
        source_table.find("pre code").each(function (i, e) {
          hljs.highlightBlock(e, "  ");
        });
        source_table.addClass("highlighted");
      }
      window.location.hash = this.href.split("#")[1];
    },
    onCleanup: function () {
      window.location.hash = $(".group_tabs a:first").attr("href");
    }
  }

  // Hide src files and file list container after load
  $(".source_files").hide();
  $(".file_list_container").hide();

  // Add tabs based upon existing file_list_containers
  $(".file_list_container h2").each(function () {
    var container_id = $(this)
      .parent()
      .attr("id");
    var group_name = $(this)
      .find(".group_name")
      .first()
      .html();
    var covered_percent = $(this)
      .find(".covered_percent")
      .first()
      .html();
    if (covered_percent) {
      covered_percent = "(" + covered_percent + ")";
    } else {
      covered_percent = "";
    }

    $(".group_tabs").append(
      '<li><a href="#' +
      container_id +
      '">' +
      group_name +
      " " +
      covered_percent +
      "</a></li>"
    );
  });

  $(".group_tabs a").each(function () {
    $(this).addClass(
      $(this)
        .attr("href")
        .replace("#", "")
    );
  });

  // Make sure tabs don't get ugly focus borders when active
  $(".group_tabs a").live("focus", function () {
    $(this).blur();
  });

  var favicon_path = $('link[rel="shortcut icon"]').attr("href");
  $(".group_tabs a").live("click", function () {
    if (
      !$(this)
        .parent()
        .hasClass("active")
    ) {
      $(".group_tabs a")
        .parent()
        .removeClass("active");
      $(this)
        .parent()
        .addClass("active");
    }
    $(".file_list_container").hide();
    $(".file_list_container" + $(this).attr("href")).show(function () {
      // If we have an anchor to click, click it
      // allow rendering to complete before we click the anchor
      setTimeout(() => {
        if (window.auto_click_anchor && $(window.auto_click_anchor).length > 0) {
          $(window.auto_click_anchor).click();
        }
      }, 30);
    });
    // Below the #_ is a hack to show we have processed the hash change
    if (!window.auto_click_anchor) {
      window.location.href =
        window.location.href.split("#")[0] +
        $(this)
          .attr("href")
          .replace("#", "#_");
    }

    // Force favicon reload - otherwise the location change containing anchor would drop the favicon...
    // Works only on firefox, but still... - Anyone know a better solution to force favicon on local relative file path?
    $('link[rel="shortcut icon"]').remove();
    $("head").append(
      '<link rel="shortcut icon" type="image/png" href="' +
      favicon_path +
      '" />'
    );
    return false;
  });

  // The below function handles turning initial anchors in links to navigate to correct tab
  if (jQuery.url.attr("anchor")) {
    var anchor = jQuery.url.attr("anchor");
    if (anchor.length == 40) {
      // handles deep links to source files
      window.auto_click_anchor = "a.src_link[href=#" + anchor + "]";
      $(".group_tabs a:first").click();
    } else {
      // handles a # anchor that needs to be processed into a #_ completed action
      if ($(".group_tabs a." + anchor.replace("_", "")).length > 0) {
        $(".group_tabs a." + anchor.replace("_", "")).click();
      }
    }
  } else {
    // No anchor, so click the first navigation tab
    $(".group_tabs a:first").click();
  }

  $("abbr.timeago").timeago();
  $("#loading").fadeOut();
  $("#wrapper").show();
  $(".dataTables_filter input").focus();

  function initDeadCodeSession() {
    if (!window.CoverbandDeadCode || !$(".file_list").length) return;
    var D = window.CoverbandDeadCode;
    var storageKey = "coverband_deadcode_session:" + ($(".file_list").data("coverageurl") || "/");
    var state;
    try {
      state = D.parseState(window.localStorage.getItem(storageKey));
    } catch (e) {
      console && console.warn && console.warn("coverband dead-code session: localStorage unavailable", e);
      state = D.emptyState();
    }
    if (!state.startedAt) state.startedAt = new Date().toISOString();

    function saveState() {
      try {
        window.localStorage.setItem(storageKey, JSON.stringify(state));
      } catch (e) { /* private mode etc.; session still works in-memory */ }
    }
    saveState();

    function extractPath(cellHtml) {
      var m = String(cellHtml).match(/title="([^"]*)"/);
      return m ? m[1] : "";
    }

    function rowRuntime(aData) {
      var n = parseFloat(String(aData[2]));
      return isNaN(n) ? null : n;
    }

    // Custom filter: hide rows excluded by the session (DataTables 1.7 API)
    $.fn.dataTableExt.afnFiltering.push(function (oSettings, aData, iDataIndex) {
      if (!$(oSettings.nTable).hasClass("file_list")) return true;
      return !D.isExcluded(state, extractPath(aData[0]), rowRuntime(aData));
    });

    function redrawTables() {
      $(".file_list").each(function () {
        $(this).dataTable().fnDraw();
      });
      updateBadges();
    }

    function updateBadges() {
      var hidden = 0;
      var stateNoMarks = { hiddenPaths: state.hiddenPaths, markedPaths: [], hideRuntimeUsed: state.hideRuntimeUsed };
      $(".file_list").each(function () {
        var data = $(this).dataTable().fnGetData();
        for (var i = 0; i < data.length; i++) {
          if (D.isExcluded(stateNoMarks, extractPath(data[i][0]), rowRuntime(data[i]))) hidden++;
        }
      });
      $("#dcs-hidden-count").text(hidden + " hidden");
      $("#dcs-marked-count").text(state.markedPaths.length);
      var chips = $("#dcs-chips").empty();
      $.each(state.hiddenPaths, function (_i, entry) {
        var chip = $('<span class="dcs-chip"></span>').text(entry);
        $('<button class="dcs-chip-x" title="Unhide">&times;</button>')
          .appendTo(chip)
          .bind("click", function () {
            D.removeHidden(state, entry);
            saveState();
            redrawTables();
          });
        chips.append(chip);
      });
      chips.toggle(state.hiddenPaths.length > 0 && chips.data("open") === true);
      $("#dcs-chips-toggle").toggle(state.hiddenPaths.length > 0)
        .text("Hidden items (" + state.hiddenPaths.length + ")");
    }

    // Toolbar
    var toolbar = $(
      '<div id="dcs-toolbar">' +
      '  <strong>Dead-code session</strong>' +
      '  <label><input type="checkbox" id="dcs-runtime-toggle"> Hide files with runtime % &gt; 0</label>' +
      '  <span class="dcs-badge" id="dcs-hidden-count">0 hidden</span>' +
      '  <button type="button" id="dcs-marked-btn">Marked for deletion: <span id="dcs-marked-count">0</span></button>' +
      '  <button type="button" id="dcs-chips-toggle">Hidden items</button>' +
      '  <button type="button" id="dcs-reset">Reset session</button>' +
      '  <div id="dcs-chips"></div>' +
      '</div>'
    );
    $("#content").prepend(toolbar);

    $("#dcs-runtime-toggle")
      .prop("checked", state.hideRuntimeUsed)
      .bind("change", function () {
        state.hideRuntimeUsed = this.checked;
        saveState();
        redrawTables();
      });

    $("#dcs-chips-toggle").bind("click", function () {
      var chips = $("#dcs-chips");
      chips.data("open", chips.data("open") !== true);
      updateBadges();
    });

    $("#dcs-reset").bind("click", function () {
      if (!confirm("Reset session? This unhides everything (marked-for-deletion list is kept).")) return;
      window.CoverbandDeadCode.clearHides(state);
      $("#dcs-runtime-toggle").prop("checked", false);
      saveState();
      redrawTables();
    });

    // Exposed for Tasks 3-4 and the shared fnDrawCallback
    window.deadCodeSession = {
      D: D, state: state, saveState: saveState,
      redrawTables: redrawTables, updateBadges: updateBadges,
      extractPath: extractPath
    };
    window.deadCodeOnDraw = function (oSettings) {
      if (window.deadCodeDecorate) window.deadCodeDecorate(oSettings);
      updateBadges();
    };

    function escapeHtml(s) {
      return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }

    window.deadCodeDecorate = function (oSettings) {
      $(oSettings.nTable).find("tbody td a.src_link").not(".dcs-done").each(function () {
        var link = $(this);
        var fullPath = link.attr("title");
        if (!fullPath) return;
        var segs = D.segmentPrefixes(fullPath);
        var html = "";
        for (var i = 0; i < segs.length; i++) {
          html += '<span class="dcs-seg" data-prefix="' + escapeHtml(segs[i].prefix) + '">' +
            escapeHtml(segs[i].label) +
            '<span class="dcs-actions">' +
            '<button type="button" class="dcs-hide" title="Hide ' + escapeHtml(segs[i].prefix) + (segs[i].isFile ? "" : " and everything under it") + '">&times;</button>' +
            '<button type="button" class="dcs-mark" title="Mark ' + escapeHtml(segs[i].prefix) + ' for deletion">&#128465;</button>' +
            '</span></span>' + (segs[i].isFile ? "" : "/");
        }
        link.html(html).addClass("dcs-done");

        link.find(".dcs-hide").bind("click", function (e) {
          e.preventDefault();
          e.stopPropagation();
          D.addHidden(state, $(this).closest(".dcs-seg").attr("data-prefix"));
          saveState();
          redrawTables();
          return false;
        });
        link.find(".dcs-mark").bind("click", function (e) {
          e.preventDefault();
          e.stopPropagation();
          openMarkPopup($(this).closest(".dcs-seg").attr("data-prefix"), e.pageX, e.pageY);
          return false;
        });
      });
    };

    function closeMarkPopup() { $("#dcs-mark-popup").remove(); }

    function openMarkPopup(prefix, x, y) {
      closeMarkPopup();
      var popup = $(
        '<div id="dcs-mark-popup">' +
        '  <div class="dcs-popup-path"></div>' +
        '  <textarea id="dcs-mark-comment" rows="2" placeholder="Optional comment (why is this dead?)"></textarea>' +
        '  <div class="dcs-popup-actions">' +
        '    <button type="button" id="dcs-mark-confirm">Mark for deletion</button>' +
        '    <button type="button" id="dcs-mark-cancel">Cancel</button>' +
        '  </div>' +
        '</div>'
      );
      popup.find(".dcs-popup-path").text(prefix);
      popup.css({ left: Math.min(x, $(window).width() - 340) + "px", top: (y + 8) + "px" });
      $("body").append(popup);
      $("#dcs-mark-comment").focus();
      $("#dcs-mark-cancel").bind("click", closeMarkPopup);
      $("#dcs-mark-confirm").bind("click", function () {
        D.addMark(state, prefix, $("#dcs-mark-comment").val(), new Date().toISOString());
        saveState();
        closeMarkPopup();
        redrawTables();
      });
    }

    function closeMarkedModal() { $("#dcs-modal-overlay").remove(); }

    function downloadCSV() {
      var blob = new Blob([D.toCSV(state.markedPaths)], { type: "text/csv;charset=utf-8" });
      var a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "coverband-dead-code-" + new Date().toISOString().slice(0, 10) + ".csv";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(a.href);
    }

    function openMarkedModal() {
      closeMarkedModal();
      var overlay = $('<div id="dcs-modal-overlay"><div id="dcs-modal">' +
        '<div id="dcs-modal-head"><strong>Marked for deletion</strong>' +
        '<button type="button" id="dcs-modal-close">&times;</button></div>' +
        '<table id="dcs-modal-table"><thead><tr>' +
        '<th>Path</th><th>Comment</th><th>Marked at</th><th></th>' +
        '</tr></thead><tbody></tbody></table>' +
        '<div id="dcs-modal-foot">' +
        '<button type="button" id="dcs-csv">Download CSV</button>' +
        '<button type="button" id="dcs-start-over">Start over</button>' +
        '</div></div></div>');
      var tbody = overlay.find("tbody");
      if (state.markedPaths.length === 0) {
        tbody.append('<tr><td colspan="4"><em>Nothing marked yet.</em></td></tr>');
      }
      $.each(state.markedPaths.slice(), function (_i, m) {
        var tr = $("<tr></tr>");
        $('<td class="dcs-mono"></td>').text(m.path).appendTo(tr);
        var commentInput = $('<input type="text" class="dcs-comment-edit">').val(m.comment)
          .bind("change", function () {
            D.updateComment(state, m.path, $(this).val());
            saveState();
          });
        $("<td></td>").append(commentInput).appendTo(tr);
        $('<td class="dcs-mono"></td>').text(m.markedAt).appendTo(tr);
        $("<td></td>").append(
          $('<button type="button" title="Unmark">&times;</button>').bind("click", function () {
            D.removeMark(state, m.path);
            saveState();
            redrawTables();
            openMarkedModal(); // rebuild
          })
        ).appendTo(tr);
        tbody.append(tr);
      });
      $("body").append(overlay);
      $("#dcs-modal-close").bind("click", closeMarkedModal);
      overlay.bind("click", function (e) { if (e.target === this) closeMarkedModal(); });
      $("#dcs-csv").bind("click", downloadCSV);
      $("#dcs-start-over").bind("click", function () {
        if (!confirm("Clear the entire marked-for-deletion list?")) return;
        D.clearMarks(state);
        saveState();
        redrawTables();
        openMarkedModal();
      });
    }

    $("#dcs-marked-btn").bind("click", openMarkedModal);

    redrawTables();
  }
});
