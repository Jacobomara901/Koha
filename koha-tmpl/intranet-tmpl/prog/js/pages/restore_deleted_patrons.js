/* global __ $date showMessage escape_str */

$(document).ready(function () {
    $("#categorycode_filter").select2({
        width: "30%",
        allowClear: true,
        placeholder: __("All categories"),
    });
    $("#branchcode_filter").select2({
        width: "30%",
        allowClear: true,
        placeholder: __("All libraries"),
    });

    const library_names = {};
    $("#branchcode_filter option").each(function () {
        library_names[this.value] = $(this).text().trim();
    });

    const category_names = {};
    $("#categorycode_filter option").each(function () {
        category_names[this.value] = $(this).text().trim();
    });

    function exact(selector) {
        return function () {
            return $(selector).val();
        };
    }

    function contains(selector) {
        return function () {
            const value = $(selector).val();
            if (!value) return null;
            return { like: "%" + value + "%" };
        };
    }

    function selected(selector) {
        return function () {
            const values = ($(selector).val() || []).filter(Boolean);
            if (!values.length) return null;
            return values;
        };
    }

    function deletedBetween() {
        const range = {};
        const from = $("#deleted_from").val();
        const to = $("#deleted_to").val();
        if (from) range[">="] = from + "T00:00:00Z";
        if (to) range["<="] = to + "T23:59:59Z";
        if (!Object.keys(range).length) return null;
        return range;
    }

    function renderText(data, type) {
        if (type === "display") return escape_str(data);
        return data || "";
    }

    function renderName(names) {
        return function (data, type) {
            return renderText(names[data] || data, type);
        };
    }

    function renderDate(data, type) {
        if (type === "display" && data) return $date(data);
        return data;
    }

    function renderCheckbox(row, type) {
        if (type !== "display") return "";
        return (
            '<input type="checkbox" class="select_patron" data-patron-id="' +
            row.patron_id +
            '" />'
        );
    }

    const table = $("#deleted_patrons_table").kohaTable(
        {
            ajax: {
                url: "/api/v1/deleted/patrons",
            },
            order: [[7, "desc"]],
            columns: [
                { data: renderCheckbox, searchable: false, orderable: false },
                {
                    data: "cardnumber",
                    searchable: true,
                    orderable: true,
                    render: renderText,
                },
                { data: "patron_id", searchable: true, orderable: true },
                {
                    data: "surname",
                    searchable: true,
                    orderable: true,
                    render: renderText,
                },
                {
                    data: "firstname",
                    searchable: true,
                    orderable: true,
                    render: renderText,
                },
                {
                    data: "category_id",
                    searchable: true,
                    orderable: true,
                    render: renderName(category_names),
                },
                {
                    data: "library_id",
                    searchable: true,
                    orderable: true,
                    render: renderName(library_names),
                },
                {
                    data: "updated_on",
                    searchable: true,
                    orderable: true,
                    render: renderDate,
                },
            ],
        },
        undefined,
        false,
        {
            "me.cardnumber": exact("#cardnumber"),
            "me.borrowernumber": exact("#borrowernumber"),
            "me.surname": contains("#surname"),
            "me.firstname": contains("#firstname"),
            "me.email": contains("#email"),
            "me.categorycode": selected("#categorycode_filter"),
            "me.branchcode": selected("#branchcode_filter"),
            "me.updated_on": deletedBetween,
        }
    );
    const table_api = table.DataTable();

    $("#search_form").on("submit", function (e) {
        e.preventDefault();
        table_api.ajax.reload();
    });

    $("#clear_filters").on("click", function () {
        $("#search_form input[type='text']").val("");
        $("#deleted_from, #deleted_to").each(function () {
            this._flatpickr.clear();
        });
        $("#categorycode_filter, #branchcode_filter")
            .val(null)
            .trigger("change");
        table_api.ajax.reload();
    });

    $("#select_all").on("click", function () {
        $("#deleted_patrons_table tbody .select_patron").prop(
            "checked",
            this.checked
        );
    });

    function patronLink(patron) {
        return (
            '<a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=' +
            encodeURIComponent(patron.patron_id) +
            '" target="_blank">' +
            escape_str(patron.surname) +
            ", " +
            escape_str(patron.firstname) +
            " (" +
            escape_str(patron.cardnumber) +
            ")</a>"
        );
    }

    function restoreErrorMessage(patron_id, xhr) {
        let message = __("Error restoring patron %s").format(patron_id);
        const response = xhr.responseJSON;
        if (response && response.error) {
            message += ": " + escape_str(response.error);
        }
        return message;
    }

    $("#restore_selected").on("click", function () {
        const patron_ids = $(".select_patron:checked")
            .map(function () {
                return $(this).data("patron-id");
            })
            .get();

        if (!patron_ids.length) {
            alert(__("Please select at least one patron to restore."));
            return;
        }

        const confirmed = confirm(
            __("Are you sure you want to restore %s patron(s)?").format(
                patron_ids.length
            )
        );
        if (!confirmed) return;

        const requests = patron_ids.map(function (patron_id) {
            return $.ajax({
                url: "/api/v1/deleted/patrons/" + patron_id,
                type: "PUT",
                headers: {
                    "x-koha-request-id": Math.random(),
                },
            });
        });

        Promise.allSettled(requests).then(function (results) {
            const restored = [];
            results.forEach(function (result, i) {
                if (result.status === "rejected") {
                    showMessage(
                        restoreErrorMessage(patron_ids[i], result.reason),
                        "danger"
                    );
                    return;
                }
                restored.push(patronLink(result.value));
            });

            if (restored.length) {
                showMessage(
                    __("Restored %s patron(s): %s").format(
                        restored.length,
                        restored.join(", ")
                    ),
                    "success"
                );
            }

            $("#select_all").prop("checked", false);
            table_api.ajax.reload();
        });
    });
});
