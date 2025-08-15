import { markRaw } from "vue";

import Home from "../components/Shibboleth/Home.vue";

import ResourceWrapper from "../components/ResourceWrapper.vue";

import { $__ } from "@koha-vue/i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/admin/shibboleth/shibboleth-home.pl",
        is_default: true,
        is_base: true,
        title: $__("Shibboleth configuration"),
        children: [
            {
                path: "",
                name: "ShibbolethHome",
                component: markRaw(Home),
                is_navigation_item: false,
            },
            {
                path: "/cgi-bin/koha/admin/shibboleth/config",
                title: $__("Configuration"),
                icon: "fa-solid fa-cog",
                is_end_node: true,
                resource: "Shibboleth/ShibbolethConfigResource.vue",
                children: [
                    {
                        path: "",
                        name: "ShibbolethConfig",
                        component: markRaw(ResourceWrapper),
                        title: $__("Shibboleth configuration"),
                    },
                ],
            },
            {
                path: "/cgi-bin/koha/admin/shibboleth/mappings",
                title: $__("Field mappings"),
                icon: "fa-solid fa-exchange-alt",
                is_end_node: true,
                resource: "Shibboleth/ShibbolethMappingsResource.vue",
                children: [
                    {
                        path: "",
                        name: "ShibbolethMappingsList",
                        component: markRaw(ResourceWrapper),
                    },
                    {
                        path: ":mapping_id",
                        name: "ShibbolethMappingsShow",
                        component: markRaw(ResourceWrapper),
                        title: $__("Show {name}"),
                    },
                    {
                        path: "add",
                        name: "ShibbolethMappingsFormAdd",
                        component: markRaw(ResourceWrapper),
                        title: $__("Add field mapping"),
                    },
                    {
                        path: "edit/:mapping_id",
                        name: "ShibbolethMappingsFormAddEdit",
                        component: markRaw(ResourceWrapper),
                        title: $__("Edit field mapping"),
                    },
                ],
            },
        ],
    },
];
