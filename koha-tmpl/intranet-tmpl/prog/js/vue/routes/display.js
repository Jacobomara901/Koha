import { markRaw } from "vue";

import Home from "../components/Display/Home.vue";

import { $__ } from "@koha-vue/i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/display/display-home.pl",
        is_default: true,
        is_base: true,
        title: $__("Displays"),
        children: [
            {
                path: "",
                name: "Home",
                component: markRaw(Home),
                is_navigation_item: false,
            },
        ],
    },
];
