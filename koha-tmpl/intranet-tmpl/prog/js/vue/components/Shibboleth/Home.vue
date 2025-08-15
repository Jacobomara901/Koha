<template>
    <div class="main container-fluid">
        <div class="row">
            <div class="col-sm-10 col-sm-push-2">
                <main>
                    <h2>{{ $__("Shibboleth configuration") }}</h2>

                    <div class="row">
                        <div class="col-md-6">
                            <div class="page-section">
                                <h3>{{ $__("Configuration") }}</h3>
                                <p>
                                    {{
                                        $__(
                                            "Manage global Shibboleth settings including SSO options and user creation preferences."
                                        )
                                    }}
                                </p>
                                <router-link
                                    :to="{ name: 'ShibbolethConfig' }"
                                    class="btn btn-default"
                                >
                                    <i class="fa-solid fa-cog"></i>
                                    {{ $__("Configure Shibboleth") }}
                                </router-link>
                            </div>
                        </div>

                        <div class="col-md-6">
                            <div class="page-section">
                                <h3>{{ $__("Field mappings") }}</h3>
                                <p>
                                    {{
                                        $__(
                                            "Configure how Shibboleth attributes map to Koha patron fields."
                                        )
                                    }}
                                </p>
                                <router-link
                                    :to="{ name: 'ShibbolethMappingsList' }"
                                    class="btn btn-default"
                                >
                                    <i class="fa-solid fa-exchange-alt"></i>
                                    {{ $__("Manage mappings") }}
                                </router-link>
                            </div>
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
import LeftMenu from "../LeftMenu.vue";

export default {
    name: "ShibbolethHome",
    components: {
        LeftMenu,
    },
};
</script>
