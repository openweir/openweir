# OpenWeir

English · [简体中文](README.zh-CN.md)

OpenWeir is a panel for running a proxy service on Cloudflare Workers, with two node programs:

- **openweir-proxy**: the landing node, which serves users' proxy connections
- **openweir-relay**: the relay node, which forwards traffic to landing nodes, either directly or through an exit tunnel

This repository is where OpenWeir is published. It holds:

- node program releases
- the latest version of each component
- the panel's OpenAPI documents

The source repositories are separate.

## What's here

| Path | Contents |
|---|---|
| [Releases](../../releases) | `proxy-vX.Y.Z` and `relay-vX.Y.Z`: binaries for linux amd64 and arm64 with `SHA256SUMS` |
| [`versions.json`](versions.json) | Latest version of each component, read by the panel every day |
| [`api/`](api) | OpenAPI documents of the panel and the node API |

Everything under `api/` is copied here by the panel's CI. Don't edit them in this repository.

## Install a node

Add the server in the admin console, then copy its install command and run it as root:

```sh
curl -fsSL https://<panel>/api/v1/node/<proxy|relay>/install.sh | sh -s -- --token <token>
```

The token is valid for one hour and works once. The script:

1. exchanges the token for the node config
2. downloads the binary from this repository's releases, or from the mirror set in the panel
3. checks the binary against `SHA256SUMS`
4. writes the config and a systemd or OpenRC service
5. starts the service

Running the script again reinstalls or upgrades the node.

Only the panel serves the script, so servers that can't reach GitHub can still fetch it. Only the binary download needs GitHub or a mirror.

To uninstall:

```sh
curl -fsSL https://<panel>/api/v1/node/<proxy|relay>/install.sh | sh -s -- --uninstall
```

## Releases and versions

- Each release is tagged `<program>-v<version>`, for example `proxy-v1.3.0` or `relay-v0.2.0`.
- Each release has `openweir-<program>-linux-amd64`, `openweir-<program>-linux-arm64` and `SHA256SUMS`.
- Release assets never change after publishing. Download them from their fixed address:

  ```
  https://github.com/openweir/openweir/releases/download/<program>-v<version>/<file>
  ```

- Don't use `releases/latest`. Both programs are released here, so the latest release can belong to either one. Read the latest versions from `versions.json` instead:

  ```json
  { "proxy": "1.3.0", "relay": "0.2.0", "api": "2.4.0" }
  ```

  A version is written there only after all its assets are uploaded.

- Mirrors must keep the `download/<tag>/<file>` layout. Set the mirror's address in the panel's proxy settings.

### Verify a download

```sh
sha256sum --check --ignore-missing SHA256SUMS
```

## API documents

`api/` holds the panel's OpenAPI 3.1 documents:

| File | Covers |
|---|---|
| `admin.json` | Admin console API |
| `app.json` | User-facing API |
| `auth.json` | Sign-in and accounts (every sign-in method) |
| `proxy.json`, `relay.json` | APIs the node programs call |

- `main` always has the newest documents.
- Each panel release is also tagged `api-v<version>`. Pin a tag when you generate a client:

  ```
  https://raw.githubusercontent.com/openweir/openweir/api-v2.4.0/api/admin.json
  ```

## Licenses

- **openweir-proxy** links code licensed under GPL-3.0, so its binaries are distributed under GPL-3.0-only.
  - Each `proxy-v*` release also includes `openweir-proxy-src-<version>.tar.gz`: the complete source of that version with its vendored Go modules.
  - It also includes `openweir-proxy-notices.tar.gz`: third-party licenses and notices.
- **openweir-relay**: see the license file attached to each `relay-v*` release.
