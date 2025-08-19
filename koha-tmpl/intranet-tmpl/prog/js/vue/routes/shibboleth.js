import { markRaw } from "vue";

import Home from "../components/Shibboleth/Home.vue";
import ShibbolethMappingsList from "../components/Shibboleth/ShibbolethMappingsList.vue";
import ShibbolethMappingForm from "../components/Shibboleth/ShibbolethMappingForm.vue";

import ResourceWrapper from "../components/ResourceWrapper.vue";

import { $__ } from "@koha-vue/i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/admin/shibboleth.pl",
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
                path: "config",
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
                path: "mappings",
                title: $__("Field mappings"),
                icon: "fa-solid fa-exchange-alt",
                is_end_node: true,
                children: [
                    {
                        path: "",
                        name: "ShibbolethMappingsList",
                        component: markRaw(ShibbolethMappingsList),
                        title: $__("Field mappings"),
                    },
                    {
                        path: "add",
                        name: "ShibbolethMappingAdd",
                        component: markRaw(ShibbolethMappingForm),
                        title: $__("Add field mapping"),
                    },
                    {
                        path: ":mapping_id/edit",
                        name: "ShibbolethMappingEdit",
                        component: markRaw(ShibbolethMappingForm),
                        title: $__("Edit field mapping"),
                    },
                ],
            },
        ],
    },
];
