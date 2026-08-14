# local-web-app

**一行命令，把任意本地 Web 服务包成 macOS 原生 .app。**

零依赖 — 只用系统自带的 `swiftc` + `WKWebView`，生成的 .app 约 **150KB**。

```bash
# 远程一键执行（无需 clone）— 使用 jsDelivr CDN 镜像，国内直连
bash <(curl -sSL https://cdn.jsdelivr.net/gh/huyansheng3/local-web-app@main/create) --preset dsh

# 如果你能访问 GitHub，也可以用原始地址
bash <(curl -sSL https://raw.githubusercontent.com/huyansheng3/local-web-app/main/create) --preset dsh

# 或本地执行
./create --preset dsh

# 自定义任意本地服务
./create 'My App' --url http://localhost:3000 --start 'npm run dev'
```

## 为什么

很多优秀的本地工具提供 Web UI，但每次都要开终端输命令、保持终端窗口不关。

local-web-app 把这类服务**包成双击即开的 macOS App**：

- 🟢 **打开 App** → 自动启动服务 → 等待就绪 → 显示 WebView
- 🔴 **关闭 App** → 自动终止服务进程 → 端口释放
- 🔄 **服务已在运行** → 直接复用，不重复启动
- ⚠️ **启动失败** → 显示错误信息和重试按钮

## 快速开始

### 前置要求

- macOS 14+ (Sonoma)
- Xcode Command Line Tools: `xcode-select --install`

### 远程一键执行（无需 clone）

```bash
# 推荐：通过 jsDelivr CDN 镜像执行（国内直连，不卡）
bash <(curl -sSL https://cdn.jsdelivr.net/gh/huyansheng3/local-web-app@main/create) --preset dsh

# 备选：通过 GitHub raw 执行（需要能访问 GitHub）
bash <(curl -sSL https://raw.githubusercontent.com/huyansheng3/local-web-app/main/create) --preset dsh
```

> ⚠️ 首次编译 SwiftUI 需 30-60 秒，请耐心等待。
>
> 💡 远程执行时预设图标会自动从 jsDelivr CDN 下载（10 秒连接超时 + 30 秒下载超时，失败自动跳过）。你也可以加上 `--icon <url>` 指定自定义图标。

### 本地安装

```bash
git clone https://github.com/huyansheng3/local-web-app.git
cd local-web-app
chmod +x create
```

#### 预设应用（一键包装）

```bash
# DeepSeek Harness — AI 编程助手 Web 端
./create --preset dsh

# Reasonix — AI 推理引擎 Web 端
./create --preset reasonix

# 查看所有预设
./create --list-presets
```

预设自动填充名称、URL、启动命令和图标，一行搞定。

#### 自定义应用

```bash
./create 'App 名称' --url <本地地址> --start <启动命令> [选项]
```

**必选参数：**

| 参数 | 说明 | 示例 |
|------|------|------|
| 位置参数 | App 显示名（也是 .app 文件名） | `'DeepSeek Harness'` |
| `--url` | App 打开的本地 URL | `http://127.0.0.1:3080` |
| `--start` | 启动服务的 shell 命令 | `'dsh --profile web'` |

**可选参数：**

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--preset` | 使用内置预设 | — |
| `--icon` | 图标文件路径或 URL（.png/.icns） | 无 |
| `--timeout` | 服务启动超时秒数 | 30 |
| `--uninstall` | 卸载已创建的 App | — |
| `--rebuild` | 重建 App | — |

### 更多示例

```bash
# Ollama 本地大模型
./create 'Ollama Web' --url http://127.0.0.1:11434 --start 'ollama serve'

# 本地开发服务器
./create 'My Dev' --url http://localhost:3000 --start 'cd ~/project && npm run dev'

# 带自定义图标
./create 'My App' --url http://localhost:8080 --start './start.sh' --icon ./icon.png

# 图标支持 URL 下载
./create 'My App' --url http://localhost:8080 --start './start.sh' \
  --icon https://example.com/icon.png

# 自定义超时（慢启动的服务）
./create 'Slow App' --url http://localhost:8080 --start './slow-start.sh' --timeout 60

# 卸载已创建的 App
./create --uninstall 'DeepSeek Harness'
```

## 预设列表

| 预设名 | 应用 | URL | 启动命令 | 图标 |
|--------|------|-----|---------|------|
| `dsh` | DeepSeek Harness | `http://127.0.0.1:3080` | `dsh --profile web` | ✅ |
| `reasonix` | Reasonix | `http://127.0.0.1:8787` | `reasonix web` | ✅ |

> **注意**：使用预设前需要先安装对应的工具（如 `npm install -g @deepseek-ai/dsh`）。

## 工作原理

```
┌──────────────────────────────────────────────┐
│                macOS .app                    │
│                                              │
│  ┌──────────┐   ┌───────────┐   ┌────────┐  │
│  │  Swift    │──▶│   Server   │──▶│  WKWeb │  │
│  │  App      │   │  Manager   │   │  View  │  │
│  └──────────┘   └───────────┘   └────────┘  │
│       │              │                      │
│       │    ┌─────────▼──────────┐           │
│       │    │ /bin/zsh -l -c    │           │
│       │    │ "exec <command>"  │           │
│       │    └────────────────────┘           │
│       │                                     │
│  onAppear  →  probe → start → poll → ready │
│  willTerminate  →  shutdown process        │
└──────────────────────────────────────────────┘
```

1. **生成 Swift 源码** — 将 URL 和启动命令硬编码进 SwiftUI + WKWebView 代码
2. **`swiftc` 编译** — 用系统编译器生成原生二进制（~150KB）
3. **打包 .app** — 标准 macOS App Bundle 结构 + Info.plist + 图标
4. **Ad-hoc 签名** — `codesign --sign -` 让 Gatekeeper 放行

### 生成的 App 行为

| 事件 | 行为 |
|------|------|
| 打开 App | 先探测端口，服务已运行则直接加载；否则通过 login shell 启动服务 |
| 服务就绪 | HTTP 探测成功 → 停止加载动画 → 显示 WebView |
| 启动超时 | 30 秒内未就绪 → 显示错误 + 重试按钮 + 日志路径 |
| 服务崩溃 | 非零退出码 → 显示错误信息 |
| 关闭 App | `willTerminateNotification` → 终止服务进程 |

### Login Shell 执行

macOS App 从 Finder 启动时**没有终端环境**，npm 全局 CLI 的 PATH 不可用。因此服务通过 login shell 启动：

```
/bin/zsh -l -c "exec <command>"
```

这确保了 `.zshrc` / `.zprofile` 中的 PATH、Node 环境等配置被正确加载。

### 图标处理

- `.icns` 文件：直接复制到 App Bundle
- `.png` 文件：通过 macOS 自带的 `sips`（10 种尺寸）+ `iconutil` 自动转换为 `.icns`
- URL 图标：自动 `curl` 下载后转换

## 更新服务

App **不嵌入服务本身**，只负责启停和 WebView。更新服务照常执行原来的命令即可：

```bash
npm install -g @deepseek-ai/dsh    # 更新 dsh
# 下次打开 App 自动用新版本
```

如需重建 App 本身（如更新了 local-web-app），对预设应用只需重新运行：

```bash
./create --preset dsh    # 重建 DeepSeek Harness App
```

## 竞品对比

### 功能对比

| | **local-web-app** | [app-it](https://github.com/Christian-Katzmann/app-it) | [Pake](https://github.com/tw93/Pake) | [Nativefier](https://github.com/nativefier/nativefier) | Electron |
|---|---|---|---|---|---|
| 包体大小 | **~150KB** | ~150KB | ~3MB | ~150MB | ~150MB |
| 运行时 | 系统 WebView | 系统 WebView / Chrome | 系统 WebView | 自带 Chromium | 自带 Chromium |
| 依赖 | **无**（系统自带） | Claude Code / Codex | Rust 工具链 | Node + Electron | Node + Electron |
| 安装方式 | 一行 shell 命令 | 需安装 AI 技能 | 安装 Rust + npm | npm install | npm + 脚手架 |
| 进程生命周期 | **✅ 自动启停** | ✅ 自动启停 | ❌ 不管理 | ❌ 不管理 | 需自己写 |
| 预设快捷方式 | **✅ 内置** | ❌ | ❌ | ❌ | — |
| 远程一键执行 | **✅ curl + bash** | ❌ | ❌ | ❌ | — |
| 本地服务包装 | **✅ 核心场景** | ✅ | ❌ (远程网站) | ❌ (远程网站) | 需自己写 |
| 远程网站包装 | ❌ | ✅ | ✅ | ✅ | ✅ |
| macOS | ✅ | ✅ | ✅ | ✅ | ✅ |
| Windows | ❌ | 🧪 Beta | ✅ | ✅ | ✅ |
| Linux | ❌ | ❌ | ✅ | ✅ | ✅ |
| 状态 | 活跃 | 活跃 | 活跃 | **已停止维护** | 活跃 |

### 差异解读

**vs app-it** — 最相似的竞品，同样使用 Swift + WKWebView + 进程管理。核心区别：app-it 是 Claude Code/Codex 的 AI 技能，需要先安装 AI 编程助手才能使用；local-web-app 是独立的 shell 脚本，一行命令直接运行，也支持远程一键执行。app-it 更智能（自动探测项目类型、端口、选择启动策略），local-web-app 更直接（你告诉它 URL 和启动命令，它直接做）。

**vs Pake** — Pake 用 Tauri（Rust）包装远程网站为桌面 App，需要 Rust 编译环境，生成的 App ~3MB。Pake 不管理进程生命周期，也不适合包装需要先启动本地服务器的场景。local-web-app 专注本地服务，自动管理启停，零依赖。

**vs Nativefier** — 已停止维护的 Electron 包装工具。包体 ~150MB（自带 Chromium），不支持进程管理，不适合本地服务场景。legacy 项目，不推荐新项目使用。

**核心定位**：local-web-app 专为**本地 Web 服务**设计 — 你的场景是「先启动一个本地进程，再用 WebView 打开它」。这是 Pake/Nativefier 不覆盖的盲区，也是 app-it 覆盖但需要 AI 助手前置的场景。

## 文件结构

```
local-web-app/
├── create           # 主 CLI 脚本
├── icons/
│   ├── dsh.png      # DeepSeek Harness 预设图标
│   └── reasonix.png # Reasonix 预设图标
├── README.md
├── LICENSE
└── .gitignore
```

## 限制

- 仅支持 macOS 14+ (SwiftUI 依赖)
- 仅包装**本地** Web 服务（不适用于远程网站，那直接用浏览器即可）
- App 关闭时会终止服务进程 — 不要用它包装需要持久运行的服务
- 非英文 App 名称完全支持（通过 md5 生成 Bundle ID）

## 常见问题

**Q: 图标怎么自定义？**

使用 `--icon` 参数，支持本地 `.png`/`.icns` 文件或 URL：

```bash
./create 'My App' --url http://localhost:3000 --start 'npm start' --icon ./my-icon.png
./create 'My App' --url http://localhost:3000 --start 'npm start' --icon https://example.com/icon.png
```

**Q: 如何添加新预设？**

编辑 `create` 脚本顶部的 `preset_*` 函数，在 case 语句中添加新条目：

```bash
preset_name()  { case "$1" in ... ; yourapp) echo "Your App Name" ;; esac; }
preset_url()   { case "$1" in ... ; yourapp) echo "http://127.0.0.1:8080" ;; esac; }
preset_start() { case "$1" in ... ; yourapp) echo "yourapp serve" ;; esac; }
preset_icon()  { case "$1" in ... ; yourapp) echo "$SCRIPT_DIR/icons/yourapp.png" ;; esac; }
preset_keys()  { echo "... yourapp"; }
```

欢迎提 PR 添加更多预设！

**Q: 启动超时怎么办？**

默认 30 秒超时，慢启动的服务可以调大：

```bash
./create 'Slow App' --url http://localhost:8080 --start './start.sh' --timeout 60
```

**Q: 生成的 App 很小，功能够吗？**

够的。150KB 的原生二进制包含完整的 SwiftUI 界面 + WKWebView + 进程管理。这是 macOS 系统 API 的优势 — 不需要自带 Chromium 或 Node 运行时。

**Q: 能不能包装远程网站？**

技术上可以，但不推荐。远程网站直接用浏览器更好 — 本地 Web App 的核心价值是**自动启停本地服务进程**。

## 贡献

欢迎贡献预设、图标、Bug 修复和新功能！

1. Fork 本仓库
2. 创建 Feature 分支 (`git checkout -b feature/my-preset`)
3. 提交改动 (`git commit -m 'Add preset for xxx'`)
4. 推送分支 (`git push origin feature/my-preset`)
5. 发起 Pull Request

## License

[MIT](LICENSE)
