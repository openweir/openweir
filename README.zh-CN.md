# OpenWeir

[English](README.md) · 简体中文

OpenWeir 是运行在 Cloudflare Workers 上的代理服务面板，配有两个节点程序：

- **openweir-proxy**：落地节点，承接用户的代理连接
- **openweir-relay**：中转节点，把流量直连或经出口隧道转发到落地节点

这个仓库专门用来对外发布 OpenWeir，里面有：

- 节点程序的发布版本
- 安装脚本
- 各组件的最新版本号
- 面板的 OpenAPI 文档

源码在其他仓库，不在这里。

## 仓库内容

| 位置 | 内容 |
|---|---|
| [Releases](../../releases) | `proxy-vX.Y.Z`、`relay-vX.Y.Z`：linux amd64 / arm64 二进制和 `SHA256SUMS` |
| [`install-proxy.sh`](install-proxy.sh)、[`install-relay.sh`](install-relay.sh) | 两个节点程序各自的安装脚本，和面板提供的是同一份 |
| [`versions.json`](versions.json) | 各组件的最新版本号，面板每天读取一次 |
| [`api/`](api) | 面板和节点接口的 OpenAPI 文档 |

安装脚本和 `api/` 下的文件由面板仓库的 CI 自动同步过来，不要在这里直接修改。

## 安装节点

在后台添加服务器后，复制它的安装命令，以 root 身份运行：

```sh
curl -fsSL https://<面板地址>/api/v1/node/<proxy|relay>/install.sh | sh -s -- --token <令牌>
```

令牌 1 小时内有效，只能用一次。脚本会依次：

1. 用令牌向面板换取节点配置
2. 从本仓库的 Releases 下载二进制（如果面板里设置了镜像，就从镜像下载）
3. 用 `SHA256SUMS` 校验二进制
4. 写入配置文件和 systemd / OpenRC 服务
5. 启动服务

重新运行脚本就是重装或升级。

脚本本身由面板提供，所以访问不了 GitHub 的服务器也能拿到脚本；只有下载二进制需要访问 GitHub 或镜像。

也可以直接用本仓库里的脚本，这时需要自己传入面板地址：

```sh
curl -fsSL https://raw.githubusercontent.com/openweir/openweir/main/install-relay.sh \
  | sh -s -- --panel https://<面板地址> --token <令牌>
```

卸载：

```sh
curl -fsSL https://<面板地址>/api/v1/node/<proxy|relay>/install.sh | sh -s -- --uninstall
```

## 版本与下载

- 每个版本的标签是 `<程序>-v<版本>`，例如 `proxy-v1.3.0`、`relay-v0.2.0`。
- 每个版本都包含 `openweir-<程序>-linux-amd64`、`openweir-<程序>-linux-arm64` 和 `SHA256SUMS`。
- 发布后附件不会再改动，下载地址是固定的：

  ```
  https://github.com/openweir/openweir/releases/download/<程序>-v<版本>/<文件>
  ```

- 不要用 `releases/latest`。两个程序都在这里发布，GitHub 的"最新版本"可能是其中任意一个。最新版本号请看 `versions.json`：

  ```json
  { "proxy": "1.3.0", "relay": "0.2.0", "api": "2.4.0" }
  ```

  一个版本的附件全部上传完成后，才会写进 `versions.json`。

- 使用镜像时，镜像必须保持 `download/<标签>/<文件>` 的目录结构。镜像地址在面板的代理设置里填写。

### 校验下载的文件

```sh
sha256sum --check --ignore-missing SHA256SUMS
```

## API 文档

`api/` 下是面板的 OpenAPI 3.1 文档：

| 文件 | 内容 |
|---|---|
| `admin.json` | 后台接口 |
| `app.json` | 用户端接口 |
| `auth.json` | 登录与账号（包含全部登录方式） |
| `proxy.json`、`relay.json` | 节点程序调用的接口 |

- `main` 分支始终是最新的文档。
- 面板每次发版时，还会打一个 `api-v<版本>` 标签。生成客户端时建议固定到某个标签：

  ```
  https://raw.githubusercontent.com/openweir/openweir/api-v2.4.0/api/admin.json
  ```

## 许可

- **openweir-proxy** 链接了 GPL-3.0 许可的代码，所以二进制按 GPL-3.0-only 分发。
  - 每个 `proxy-v*` 版本都附带 `openweir-proxy-src-<版本>.tar.gz`：这个版本的完整源码，包含 vendor 的 Go 依赖。
  - 同时附带 `openweir-proxy-notices.tar.gz`：第三方的许可与声明。
- **openweir-relay**：许可见每个 `relay-v*` 版本附带的许可文件。
