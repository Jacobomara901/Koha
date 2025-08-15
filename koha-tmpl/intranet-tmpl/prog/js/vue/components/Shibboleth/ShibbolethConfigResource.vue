<template>
    <div class="main container-fluid">
        <div class="row">
            <div class="col-sm-10 col-sm-push-2">
                <main>
                    <div v-if="!initialized">{{ $__("Loading") }}</div>
                    <div v-else-if="config">
                        <h2>{{ $__("Shibboleth configuration") }}</h2>

                        <form @submit.prevent="updateConfig">
                            <fieldset class="rows">
                                <legend>{{ $__("SSO Settings") }}</legend>
                                <ol>
                                    <li>
                                        <label for="force_opac_sso">
                                            <input
                                                id="force_opac_sso"
                                                v-model="config.force_opac_sso"
                                                type="checkbox"
                                            />
                                            {{ $__("Force OPAC SSO") }}
                                        </label>
                                        <div class="hint">
                                            {{
                                                $__(
                                                    "Automatically redirect OPAC users to Shibboleth login"
                                                )
                                            }}
                                        </div>
                                    </li>
                                    <li>
                                        <label for="force_staff_sso">
                                            <input
                                                id="force_staff_sso"
                                                v-model="config.force_staff_sso"
                                                type="checkbox"
                                            />
                                            {{ $__("Force staff SSO") }}
                                        </label>
                                        <div class="hint">
                                            {{
                                                $__(
                                                    "Automatically redirect staff users to Shibboleth login"
                                                )
                                            }}
                                        </div>
                                    </li>
                                </ol>
                            </fieldset>

                            <fieldset class="rows">
                                <legend>{{ $__("User Management") }}</legend>
                                <ol>
                                    <li>
                                        <label for="autocreate">
                                            <input
                                                id="autocreate"
                                                v-model="config.autocreate"
                                                type="checkbox"
                                            />
                                            {{ $__("Auto create users") }}
                                        </label>
                                        <div class="hint">
                                            {{
                                                $__(
                                                    "Automatically create patron records for new Shibboleth users"
                                                )
                                            }}
                                        </div>
                                    </li>
                                    <li>
                                        <label for="sync">
                                            <input
                                                id="sync"
                                                v-model="config.sync"
                                                type="checkbox"
                                            />
                                            {{ $__("Sync user attributes") }}
                                        </label>
                                        <div class="hint">
                                            {{
                                                $__(
                                                    "Update patron attributes from Shibboleth on each login"
                                                )
                                            }}
                                        </div>
                                    </li>
                                    <li>
                                        <label for="welcome">
                                            <input
                                                id="welcome"
                                                v-model="config.welcome"
                                                type="checkbox"
                                            />
                                            {{ $__("Send welcome email") }}
                                        </label>
                                        <div class="hint">
                                            {{
                                                $__(
                                                    "Send welcome email to new users created via Shibboleth"
                                                )
                                            }}
                                        </div>
                                    </li>
                                </ol>
                            </fieldset>

                            <fieldset class="action">
                                <input
                                    type="submit"
                                    class="btn btn-primary"
                                    :value="$__('Update configuration')"
                                />
                                <router-link
                                    :to="{ name: 'ShibbolethHome' }"
                                    role="button"
                                    class="btn btn-default"
                                >
                                    {{ $__("Cancel") }}
                                </router-link>
                            </fieldset>
                        </form>
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
import { ref, onMounted } from "vue";
import { APIClient } from "@fetch/api-client.js";
import { useMainStore } from "../../stores/main.js";
import LeftMenu from "../LeftMenu.vue";

export default {
    name: "ShibbolethConfigResource",
    components: {
        LeftMenu,
    },
    setup() {
        const config = ref(null);
        const initialized = ref(false);
        const { setMessage, setWarning } = useMainStore();

        const loadConfig = async () => {
            try {
                config.value = await APIClient.shibboleth.config.get();
                if (!config.value) {
                    config.value = {
                        force_opac_sso: false,
                        force_staff_sso: false,
                        autocreate: false,
                        sync: false,
                        welcome: false,
                    };
                }
            } catch (error) {
                console.error("Error loading config:", error);
                config.value = {
                    force_opac_sso: false,
                    force_staff_sso: false,
                    autocreate: false,
                    sync: false,
                    welcome: false,
                };
            } finally {
                initialized.value = true;
            }
        };

        const updateConfig = async () => {
            try {
                // Remove read-only fields before sending - exclude shibboleth_config_id
                const configToSend = {
                    force_opac_sso: config.value.force_opac_sso,
                    force_staff_sso: config.value.force_staff_sso,
                    autocreate: config.value.autocreate,
                    sync: config.value.sync,
                    welcome: config.value.welcome
                };
                await APIClient.shibboleth.config.update(configToSend);
                setMessage("Shibboleth configuration updated successfully");
            } catch (error) {
                console.error("Error updating config:", error);
                setWarning("Failed to update configuration");
            }
        };

        onMounted(loadConfig);

        return {
            config,
            initialized,
            updateConfig,
        };
    },
};
</script>
