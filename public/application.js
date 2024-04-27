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

  $(".file_list").dataTable(tableOptions);

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
});
