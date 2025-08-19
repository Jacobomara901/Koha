export class ShibbolethAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/shibboleth/",
        });

        this.httpClientConfig = new HttpClient({
            baseURL: "/api/v1/shibboleth/config/",
        });

        this.httpClientMappings = new HttpClient({
            baseURL: "/api/v1/shibboleth/mappings/",
        });
    }

    get config() {
        return {
            get: () =>
                this.httpClientConfig.get({
                    endpoint: "",
                }),
            update: config =>
                this.httpClientConfig.put({
                    endpoint: "",
                    body: config,
                }),
        };
    }

    get mappings() {
        return {
            create: mapping =>
                this.httpClientMappings.post({
                    endpoint: "",
                    body: mapping,
                }),
            get: id =>
                this.httpClientMappings.get({
                    endpoint: "" + id,
                }),
            getAll: (query, params) =>
                this.httpClientMappings.get({
                    endpoint:
                        "?" +
                        new URLSearchParams({
                            _per_page: -1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
            update: (mapping, id) =>
                this.httpClientMappings.put({
                    endpoint: "" + id,
                    body: mapping,
                }),
            delete: id =>
                this.httpClientMappings.delete({
                    endpoint: "" + id,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "mappings?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }
}

export default ShibbolethAPIClient;
