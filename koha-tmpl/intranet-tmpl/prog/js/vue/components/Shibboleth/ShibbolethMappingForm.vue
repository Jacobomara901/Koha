<template>
    <div class="main container-fluid">
        <div class="row">
            <div class="col-sm-10 col-sm-push-2">
                <main>
                    <div v-if="!initialized">{{ $__("Loading") }}</div>
                    <div v-else>
                        <h2>
                            {{
                                mapping_id
                                    ? $__("Edit field mapping")
                                    : $__("New field mapping")
                            }}
                        </h2>

                        <form @submit.prevent="submitForm">
                            <fieldset class="rows">
                                <legend>{{ $__("Mapping details") }}</legend>
                                <ol>
                                    <li>
                                        <label for="idp_field" class="required">
                                            {{ $__("IdP field") }}:
                                        </label>
                                        <input
                                            id="idp_field"
                                            v-model="mapping.idp_field"
                                            type="text"
                                            required
                                            :placeholder="
                                                $__(
                                                    'e.g. displayName, mail, eduPersonAffiliation'
                                                )
                                            "
                                        />
                                        <div class="hint">
                                            {{
                                                $__(
                                                    "The field name from your identity provider"
                                                )
                                            }}
                                        </div>
                                    </li>
                                    <li>
                                        <label
                                            for="koha_field"
                                            class="required"
                                        >
                                            {{ $__("Koha field") }}:
                                        </label>
                                        <select
                                            id="koha_field"
                                            v-model="mapping.koha_field"
                                            required
                                        >
                                            <option value="">
                                                {{ $__("Select a field") }}
                                            </option>
                                            <optgroup
                                                :label="
                                                    $__('Basic information')
                                                "
                                            >
                                                <option value="cardnumber">
                                                    {{ $__("Card number") }}
                                                </option>
                                                <option value="userid">
                                                    {{ $__("Username") }}
                                                </option>
                                                <option value="surname">
                                                    {{ $__("Surname") }}
                                                </option>
                                                <option value="firstname">
                                                    {{ $__("First name") }}
                                                </option>
                                                <option value="middle_name">
                                                    {{ $__("Middle name") }}
                                                </option>
                                                <option value="title">
                                                    {{ $__("Title") }}
                                                </option>
                                                <option value="initials">
                                                    {{ $__("Initials") }}
                                                </option>
                                            </optgroup>
                                            <optgroup
                                                :label="
                                                    $__('Contact information')
                                                "
                                            >
                                                <option value="email">
                                                    {{ $__("Email") }}
                                                </option>
                                                <option value="emailpro">
                                                    {{ $__("Secondary email") }}
                                                </option>
                                                <option value="phone">
                                                    {{ $__("Primary phone") }}
                                                </option>
                                                <option value="phonepro">
                                                    {{ $__("Secondary phone") }}
                                                </option>
                                                <option value="mobile">
                                                    {{ $__("Mobile phone") }}
                                                </option>
                                                <option value="fax">
                                                    {{ $__("Fax") }}
                                                </option>
                                                <option value="address">
                                                    {{ $__("Address") }}
                                                </option>
                                                <option value="address2">
                                                    {{ $__("Address 2") }}
                                                </option>
                                                <option value="city">
                                                    {{ $__("City") }}
                                                </option>
                                                <option value="state">
                                                    {{ $__("State") }}
                                                </option>
                                                <option value="zipcode">
                                                    {{ $__("ZIP/Postal code") }}
                                                </option>
                                                <option value="country">
                                                    {{ $__("Country") }}
                                                </option>
                                            </optgroup>
                                            <optgroup
                                                :label="$__('Organizational')"
                                            >
                                                <option value="branchcode">
                                                    {{ $__("Library") }}
                                                </option>
                                                <option value="categorycode">
                                                    {{ $__("Patron category") }}
                                                </option>
                                                <option value="sort1">
                                                    {{ $__("Sort 1") }}
                                                </option>
                                                <option value="sort2">
                                                    {{ $__("Sort 2") }}
                                                </option>
                                            </optgroup>
                                            <optgroup :label="$__('Dates')">
                                                <option value="dateofbirth">
                                                    {{ $__("Date of birth") }}
                                                </option>
                                                <option value="dateenrolled">
                                                    {{
                                                        $__("Registration date")
                                                    }}
                                                </option>
                                                <option value="dateexpiry">
                                                    {{ $__("Expiration date") }}
                                                </option>
                                            </optgroup>
                                            <optgroup :label="$__('Other')">
                                                <option value="sex">
                                                    {{ $__("Gender") }}
                                                </option>
                                                <option value="relationship">
                                                    {{ $__("Relationship") }}
                                                </option>
                                            </optgroup>
                                        </select>
                                        <div class="hint">
                                            {{
                                                $__(
                                                    "The corresponding field in Koha patron records"
                                                )
                                            }}
                                        </div>
                                    </li>
                                    <li>
                                        <label for="is_matchpoint">
                                            <input
                                                id="is_matchpoint"
                                                v-model="mapping.is_matchpoint"
                                                type="checkbox"
                                            />
                                            {{ $__("Use as match point") }}
                                        </label>
                                        <div class="hint">
                                            {{
                                                $__(
                                                    "Check this if this field should be used to match existing patron records"
                                                )
                                            }}
                                        </div>
                                    </li>
                                    <li>
                                        <label for="default_content">
                                            {{ $__("Default content") }}:
                                        </label>
                                        <input
                                            id="default_content"
                                            v-model="mapping.default_content"
                                            type="text"
                                            :placeholder="
                                                $__('Optional default value')
                                            "
                                        />
                                        <div class="hint">
                                            {{
                                                $__(
                                                    "Default value to use if the IdP doesn't provide this field"
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
                                    :value="
                                        mapping_id
                                            ? $__('Update mapping')
                                            : $__('Add mapping')
                                    "
                                />
                                <router-link
                                    :to="{ name: 'ShibbolethMappingsList' }"
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
import { ref, onMounted, getCurrentInstance } from "vue";
import { useRoute, useRouter } from "vue-router";
import { APIClient } from "@fetch/api-client.js";
import { useMainStore } from "../../stores/main.js";
import LeftMenu from "../LeftMenu.vue";

export default {
    name: "ShibbolethMappingForm",
    components: {
        LeftMenu,
    },
    setup() {
        const instance = getCurrentInstance();
        const { $__ } = instance.appContext.app.config.globalProperties;

        const route = useRoute();
        const router = useRouter();
        const { setMessage, setWarning } = useMainStore();

        const initialized = ref(false);
        const mapping_id = ref(route.params.mapping_id);

        const mapping = ref({
            idp_field: "",
            koha_field: "",
            is_matchpoint: false,
            default_content: "",
        });

        const loadMapping = async () => {
            if (!mapping_id.value) {
                initialized.value = true;
                return;
            }

            try {
                const response = await APIClient.shibboleth.mappings.get(
                    mapping_id.value
                );
                mapping.value = response;
            } catch (error) {
                console.error("Error loading mapping:", error);
                setWarning("Failed to load field mapping");
            } finally {
                initialized.value = true;
            }
        };

        const submitForm = async () => {
            try {
                if (mapping_id.value) {
                    await APIClient.shibboleth.mappings.update(
                        mapping.value,
                        mapping_id.value
                    );
                    setMessage("Field mapping updated successfully");
                } else {
                    await APIClient.shibboleth.mappings.create(mapping.value);
                    setMessage("Field mapping created successfully");
                }
                router.push({ name: "ShibbolethMappingsList" });
            } catch (error) {
                console.error("Error saving mapping:", error);
                setWarning("Failed to save field mapping");
            }
        };

        onMounted(loadMapping);

        return {
            initialized,
            mapping_id,
            mapping,
            submitForm,
        };
    },
};
</script>
