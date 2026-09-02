/* global __ $date */

function showMessage(message, type) {
    var alert = $(
        '<div class="alert alert-' + type + '">' + message + "</div>"
    );
    $("#messages").append(alert);

    setTimeout(function () {
        alert.fadeOut(400, function () {
            $(this).remove();
        });
    }, 5000);
}

$(document).ready(function () {
    var selectFields = document.querySelectorAll("select[multiple]");
    selectFields.forEach(function (selectField) {
        $(selectField).select2({
            width: "30%",
            allowClear: true,
        });
    });

    var library_names = {};
    $("#branchcode_filter option").each(function () {
        if (this.value) {
            library_names[this.value] = $(this).text().trim();
        }
    });

    var category_names = {};
    $("#categorycode_filter option").each(function () {
        if (this.value) {
            category_names[this.value] = $(this).text().trim();
        }
    });

    function buildQuery() {
        var query = {};

        var cardnumber = $("#cardnumber").val();
        if (cardnumber) {
            query["me.cardnumber"] = cardnumber;
        }

        var borrowernumber = $("#borrowernumber").val();
        if (borrowernumber) {
            query["me.borrowernumber"] = borrowernumber;
        }

        ["surname", "firstname", "email"].forEach(function (field) {
            var value = $("#" + field).val();
            if (value) {
                query["me." + field] = { like: "%" + value + "%" };
            }
        });

        var categories = ($("#categorycode_filter").val() || []).filter(
            Boolean
        );
        if (categories.length) {
            query["me.categorycode"] = categories;
        }

        var branches = ($("#branchcode_filter").val() || []).filter(Boolean);
        if (branches.length) {
            query["me.branchcode"] = branches;
        }

        var date_range = {};
        var from = $("#deleted_from").val();
        if (from) {
            date_range[">="] = from + "T00:00:00Z";
        }
        var to = $("#deleted_to").val();
        if (to) {
            date_range["<="] = to + "T23:59:59Z";
        }
        if (Object.keys(date_range).length) {
            query["me.updated_on"] = date_range;
        }

        return query;
    }

    function tableUrl() {
        var query = buildQuery();
        var url = "/api/v1/deleted/patrons";
        if (Object.keys(query).length) {
            url += "?q=" + encodeURIComponent(JSON.stringify(query));
        }
        return url;
    }

    function escapeCell(data, type) {
        if (type === "display") {
            return data ? $("<div/>").text(data).html() : "";
        }
        return data || "";
    }

    var table = $("#deleted_patrons_table").kohaTable({
        ajax: {
            url: tableUrl(),
        },
        order: [[7, "desc"]],
        columns: [
            {
                data: function (row, type) {
                    if (type === "display") {
                        return (
                            '<input type="checkbox" class="select_patron" data-patron-id="' +
                            row.patron_id +
                            '" />'
                        );
                    }
                    return "";
                },
                searchable: false,
                orderable: false,
            },
            {
                data: "cardnumber",
                searchable: true,
                orderable: true,
                render: escapeCell,
            },
            {
                data: "patron_id",
                searchable: true,
                orderable: true,
            },
            {
                data: "surname",
                searchable: true,
                orderable: true,
                render: escapeCell,
            },
            {
                data: "firstname",
                searchable: true,
                orderable: true,
                render: escapeCell,
            },
            {
                data: "category_id",
                searchable: true,
                orderable: true,
                render: function (data, type, row) {
                    return escapeCell(category_names[data] || data, type);
                },
            },
            {
                data: "library_id",
                searchable: true,
                orderable: true,
                render: function (data, type, row) {
                    return escapeCell(library_names[data] || data, type);
                },
            },
            {
                data: "updated_on",
                searchable: true,
                orderable: true,
                render: function (data, type, row) {
                    if (type === "display" && data) {
                        return $date(data);
                    }
                    return data;
                },
            },
        ],
    });
    var table_api = table.DataTable();

    $("#search_form").on("submit", function (e) {
        e.preventDefault();
        table_api.ajax.url(tableUrl()).load();
    });

    $("#clear_filters").on("click", function () {
        $("#search_form input[type='text']").val("");
        $("#categorycode_filter").val(null).trigger("change");
        $("#branchcode_filter").val(null).trigger("change");
        table_api.ajax.url("/api/v1/deleted/patrons").load();
    });

    $("#select_all").on("click", function () {
        $("#deleted_patrons_table tbody .select_patron").prop(
            "checked",
            this.checked
        );
    });

    $("#restore_selected").on("click", function () {
        var selected = $(".select_patron:checked")
            .map(function () {
                return $(this).data("patron-id");
            })
            .get();

        if (!selected.length) {
            alert(__("Please select at least one patron to restore."));
            return;
        }

        if (
            !confirm(
                __("Are you sure you want to restore %s patron(s)?").format(
                    selected.length
                )
            )
        ) {
            return;
        }

        var restored = 0;
        var failed = 0;

        function finishWhenDone() {
            if (restored + failed !== selected.length) {
                return;
            }
            if (restored > 0) {
                showMessage(
                    __("%s patron(s) restored successfully").format(restored),
                    "success"
                );
            }
            $("#select_all").prop("checked", false);
            table_api.ajax.reload();
        }

        selected.forEach(function (patron_id) {
            $.ajax({
                url: "/api/v1/deleted/patrons/" + patron_id,
                type: "PUT",
                headers: {
                    "x-koha-request-id": Math.random(),
                },
                success: function () {
                    restored++;
                    finishWhenDone();
                },
                error: function (xhr) {
                    failed++;
                    var error_msg = __("Error restoring patron %s").format(
                        patron_id
                    );
                    if (xhr.responseJSON && xhr.responseJSON.error) {
                        error_msg += ": " + xhr.responseJSON.error;
                    }
                    showMessage(error_msg, "danger");
                    finishWhenDone();
                },
            });
        });
    });
});
