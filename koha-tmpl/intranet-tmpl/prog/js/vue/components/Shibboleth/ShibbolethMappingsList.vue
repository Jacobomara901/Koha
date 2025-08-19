<template>
    <div class="main container-fluid">
        <div class="row">
            <div class="col-sm-10 col-sm-push-2">
                <main>
                    <div v-if="!initialized">{{ $__("Loading") }}</div>
                    <div v-else>
                        <h2>{{ $__("Shibboleth field mappings") }}</h2>
                        <div class="page-section">
                            <div id="toolbar" class="btn-toolbar">
                                <router-link
                                    :to="{ name: 'ShibbolethMappingAdd' }"
                                    class="btn btn-default"
                                    id="newmapping"
                                >
                                    <i class="fa fa-plus"></i>
                                    {{ $__("New mapping") }}
                                </router-link>
                            </div>

                            <KohaTable
                                ref="table"
                                v-bind="tableOptions"
                                @edit-mapping="handleEditMapping"
                                @delete-mapping="handleDeleteMapping"
                            ></KohaTable>
                        </div>
                    </div>
                </main>
            </div>

            <div class="col-sm-2 col-sm-pull-10">
                <aside>
                    <LeftMenu />
                </aside>
            </div>
        </div>
    </div>
</template>

<script>
import { ref, computed, getCurrentInstance } from "vue";
import { useRouter } from "vue-router";
import { APIClient } from "@fetch/api-client.js";
import { useMainStore } from "../../stores/main.js";
import LeftMenu from "../LeftMenu.vue";
import KohaTable from "../KohaTable.vue";

export default {
    name: "ShibbolethMappingsList",
    components: {
        LeftMenu,
        KohaTable,
    },
    setup() {
        const instance = getCurrentInstance();
        const { $__ } = instance.appContext.app.config.globalProperties;

        const mainStore = useMainStore();
        const { setMessage, setWarning } = mainStore;
        const initialized = ref(true);
        const table = ref();
        const router = useRouter();

        const editMapping = mapping_id => {
            router.push({
                name: "ShibbolethMappingEdit",
                params: { mapping_id },
            });
        };

        const deleteMapping = async mapping_id => {
            if (
                !confirm($__("Are you sure you want to delete this mapping?"))
            ) {
                return;
            }

            try {
                await APIClient.shibboleth.mappings.delete(mapping_id);
                setMessage("Field mapping deleted successfully");
                table.value.redraw();
            } catch (error) {
                console.error("Error deleting mapping:", error);
                setWarning("Failed to delete field mapping");
            }
        };

        const tableOptions = computed(() => ({
            columns: [
                {
                    title: $__("IdP field"),
                    data: "idp_field",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Koha field"),
                    data: "koha_field",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Match point"),
                    data: "is_matchpoint",
                    searchable: false,
                    orderable: true,
                    render: function (data) {
                        return data
                            ? '<span style="background-color: #28a745; color: white; padding: 2px 8px; border-radius: 4px; font-size: 12px;">' +
                                  $__("Yes") +
                                  "</span>"
                            : '<span style="background-color: #6c757d; color: white; padding: 2px 8px; border-radius: 4px; font-size: 12px;">' +
                                  $__("No") +
                                  "</span>";
                    },
                },
                {
                    title: $__("Default content"),
                    data: "default_content",
                    searchable: true,
                    orderable: true,
                    render: function (data) {
                        return data || "";
                    },
                },
                {
                    title: $__("Actions"),
                    data: function (row, type, val, meta) {
                        return (
                            '<div class="btn-group dropup">' +
                            '<button type="button" class="btn btn-xs btn-default dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">' +
                            $__("Actions") +
                            ' <span class="caret"></span>' +
                            "</button>" +
                            '<ul class="dropdown-menu pull-right">' +
                            '<li><a href="#" class="show-mapping" data-mapping-id="' +
                            row.mapping_id +
                            '">' +
                            '<i class="fa fa-eye"></i> ' +
                            $__("Show") +
                            "</a></li>" +
                            '<li><a href="#" class="edit-mapping" data-mapping-id="' +
                            row.mapping_id +
                            '">' +
                            '<i class="fa fa-pencil"></i> ' +
                            $__("Edit") +
                            "</a></li>" +
                            '<li><a href="#" class="delete-mapping" data-mapping-id="' +
                            row.mapping_id +
                            '">' +
                            '<i class="fa fa-trash"></i> ' +
                            $__("Delete") +
                            "</a></li>" +
                            "</ul>" +
                            "</div>"
                        );
                    },
                    searchable: false,
                    orderable: false,
                },
            ],
            options: {
                dom: '<"top pager"ilpf>tr<"bottom pager"ip>',
                aLengthMenu: [
                    [10, 20, 50, 100],
                    [10, 20, 50, 100],
                ],
                autoWidth: false,
                columnDefs: [
                    { targets: [-1], orderable: false, searchable: false },
                ],
                order: [[1, "asc"]],
                paging: true,
            },
            url: "/api/v1/shibboleth/mappings",
            add_filters: true,
            actions: {
                4: ["edit-mapping", "delete-mapping"],
            },
        }));

        const handleEditMapping = data => {
            editMapping(data.mapping_id);
        };

        const handleDeleteMapping = data => {
            deleteMapping(data.mapping_id);
        };

        return {
            initialized,
            tableOptions,
            table,
            handleEditMapping,
            handleDeleteMapping,
        };
    },
};
</script>
