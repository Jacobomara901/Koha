<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import { inject } from "vue";
import BaseResource from "../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { APIClient } from "@fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
        const { setError } = inject("mainStore");

        const kohaFields = [
            { value: "userid", label: $__("User ID") },
            { value: "cardnumber", label: $__("Card number") },
            { value: "firstname", label: $__("First name") },
            { value: "surname", label: $__("Surname") },
            { value: "email", label: $__("Email") },
            { value: "phone", label: $__("Phone") },
            { value: "mobile", label: $__("Mobile") },
            { value: "address", label: $__("Address") },
            { value: "address2", label: $__("Address 2") },
            { value: "city", label: $__("City") },
            { value: "state", label: $__("State") },
            { value: "zipcode", label: $__("Zip code") },
            { value: "country", label: $__("Country") },
            { value: "branchcode", label: $__("Home library") },
            { value: "categorycode", label: $__("Category") },
        ];

        const baseResource = useBaseResource({
            resourceName: "shibboleth_mappings",
            nameAttr: "koha_field",
            idAttr: "mapping_id",
            components: {
                show: "ShibbolethMappingsShow",
                list: "ShibbolethMappingsList",
                add: "ShibbolethMappingsFormAdd",
                edit: "ShibbolethMappingsFormAddEdit",
            },
            apiClient: APIClient.shibboleth.mappings,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this field mapping?"
                ),
                deleteSuccessMessage: $__("Field mapping deleted"),
                displayName: $__("Field mapping"),
                editLabel: $__("Edit field mapping #%s"),
                emptyListMessage: $__("There are no field mappings defined"),
                newLabel: $__("New field mapping"),
            },
            table: {
                addFilters: false,
                resourceTableUrl:
                    APIClient.shibboleth.httpClientMappings._baseURL + "",
            },
            embedded: props.embedded,
            props,
            resourceAttrs: [
                {
                    name: "mapping_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form", "Show"],
                },
                {
                    name: "koha_field",
                    label: $__("Koha field"),
                    type: "select",
                    options: kohaFields,
                    selectLabel: "label",
                    requiredKey: "value",
                    required: true,
                },
                {
                    name: "idp_field",
                    label: $__("IdP attribute"),
                    type: "text",
                    required: true,
                },
                {
                    name: "default_content",
                    label: $__("Default value"),
                    type: "text",
                    required: false,
                },
                {
                    name: "is_matchpoint",
                    label: $__("Matchpoint"),
                    type: "boolean",
                    required: false,
                    tableColumnDefinition: {
                        title: $__("Matchpoint"),
                        data: "is_matchpoint",
                        searchable: false,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return data ? $__("Yes") : $__("No");
                        },
                    },
                },
            ],
            props: props,
        });

        const tableOptions = {
            url: "/api/v1/shibboleth/mappings",
            options: {},
            add_filters: true,
            actions: {
                0: ["show"],
                1: ["show"],
                "-1": ["edit", "delete"],
            },
        };

        const checkForm = async mapping => {
            let errors = [];

            if (mapping.is_matchpoint) {
                const existingMappings = await baseResource.apiClient.getAll();
                const otherMatchpoints = existingMappings.filter(
                    m => m.is_matchpoint && m.mapping_id !== mapping.mapping_id
                );

                if (otherMatchpoints.length > 0) {
                    errors.push(
                        $__("Only one field can be set as the matchpoint")
                    );
                }
            }

            baseResource.setWarning(errors.join("<br>"));
            return !errors.length;
        };

        const onFormSave = async (e, mappingToSave) => {
            e.preventDefault();

            const mapping = JSON.parse(JSON.stringify(mappingToSave));
            const mappingId = mapping.mapping_id;

            if (!(await checkForm(mapping))) {
                return false;
            }

            delete mapping.mapping_id;

            if (mappingId) {
                baseResource.apiClient.update(mapping, mappingId).then(
                    success => {
                        baseResource.setMessage($__("Field mapping updated"));
                        baseResource.router.push({
                            name: "ShibbolethMappingsList",
                        });
                    },
                    error => {}
                );
            } else {
                baseResource.apiClient.create(mapping).then(
                    success => {
                        baseResource.setMessage($__("Field mapping created"));
                        baseResource.router.push({
                            name: "ShibbolethMappingsList",
                        });
                    },
                    error => {}
                );
            }
        };

        return {
            ...baseResource,
            tableOptions,
            checkForm,
            onFormSave,
        };
    },
    emits: ["select-resource"],
    name: "ShibbolethMappingsResource",
    components: {
        BaseResource,
    },
};
</script>
