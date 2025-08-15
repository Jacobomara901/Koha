export class ShibbolethAPIClient {
    constructor(HttpClient) {
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
                this.httpClientMappings.getAll({
                    endpoint: "",
                    params,
                    query,
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
                this.httpClientMappings
                    .getAll({
                        endpoint: "",
                        ...(Object.keys(query).length > 0 && { query }),
                    })
                    .then(data => (Array.isArray(data) ? data.length : 0))
                    .catch(() => 0),
        };
    }
}

export default ShibbolethAPIClient;
