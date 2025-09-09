# Service Image and Source Mapping

| Service | Compose Image | Ports | Local Source |
|---------|---------------|-------|--------------|
| users | `supermq/users:latest` | `9002` | _none_ |
| clients | `supermq/clients:latest` | `9006, 7006` | _none_ |
| domains | `supermq/domains:latest` | `9003, 7003` | _none_ |
| certs | `supermq/certs:latest` | `9019` | _none_ |
| http-adapter | `supermq/http:latest` | `8008` | _none_ |
| ws-adapter | `supermq/ws:latest` | `8186` | _none_ |

## Findings

- **users** – Defined in compose with image `supermq/users:${SMQ_RELEASE_TAG}` and port `${SMQ_USERS_HTTP_PORT}`【F:docker/supermq-docker/docker-compose.yaml†L818-L885】. The `.env` file sets `SMQ_USERS_HTTP_PORT=9002` and `SMQ_RELEASE_TAG=latest`【F:docker/supermq-docker/.env†L240-L240】【F:docker/supermq-docker/.env†L519-L519】. No `cmd/users` entry exists; `cmd` contains only `alarms`, `bootstrap`, `cli`, etc.【b6c350†L1-L2】.
- **clients** – Compose references `supermq/clients:${SMQ_RELEASE_TAG}` with HTTP and gRPC ports `${SMQ_CLIENTS_HTTP_PORT}` and `${SMQ_CLIENTS_GRPC_PORT}`【F:docker/supermq-docker/docker-compose.yaml†L445-L520】. `.env` assigns `SMQ_CLIENTS_HTTP_PORT=9006` and `SMQ_CLIENTS_GRPC_PORT=7006`【F:docker/supermq-docker/.env†L315-L323】. There is no `cmd/clients` entrypoint, only an internal package at `internal/clients`【e0eae8†L1-L2】【F:internal/clients/doc.go†L1-L6】.
- **domains** – The compose file uses `supermq/domains:${SMQ_RELEASE_TAG}` exposing `${SMQ_DOMAINS_HTTP_PORT}` and `${SMQ_DOMAINS_GRPC_PORT}`【F:docker/supermq-docker/docker-compose.yaml†L214-L289】, with `.env` defining ports 9003 and 7003【F:docker/supermq-docker/.env†L157-L164】. No `cmd/domains` directory is present【b6c350†L1-L2】.
- **certs** – Optional addon runs `supermq/certs:${SMQ_RELEASE_TAG}` on `${SMQ_CERTS_HTTP_PORT}`【F:docker/supermq-docker/addons/certs/docker-compose.yaml†L33-L43】; `.env` sets the port to 9019【F:docker/supermq-docker/.env†L429-L433】. No `cmd/certs` source exists【b6c350†L1-L2】.
- **http-adapter** – Compose uses `supermq/http:${SMQ_RELEASE_TAG}` with port `${SMQ_HTTP_ADAPTER_PORT}`【F:docker/supermq-docker/docker-compose.yaml†L1213-L1256】. `.env` assigns `SMQ_HTTP_ADAPTER_PORT=8008`【F:docker/supermq-docker/.env†L378-L380】. There is no `cmd/http` or similar entrypoint【b6c350†L1-L2】.
- **ws-adapter** – Compose references `supermq/ws:${SMQ_RELEASE_TAG}` and port `${SMQ_WS_ADAPTER_HTTP_PORT}`【F:docker/supermq-docker/docker-compose.yaml†L1426-L1469】, with `.env` setting the port to 8186【F:docker/supermq-docker/.env†L416-L418】. The repository lacks a `cmd/ws` implementation【b6c350†L1-L2】.

## Recommendation

All six services rely solely on pre-built images without corresponding source directories. Consider vendoring the upstream sources via subtrees/submodules or pinning image tags to known versions to ensure reproducible builds and easier audits.

