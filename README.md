# local-web-app

**一行命令，把任意本地 Web 服务包成 macOS 原生 .app。**

零依赖 — 只用系统自带的 `swiftc` + `WKWebView`，生成的 .app 约 **150KB**。

```bash
# 一键包装 DeepSeek Harness
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

### 使用

```bash
git clone https://github.com/huyansheng/local-web-app.git
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

## 为什么不是 Pake / Electron / Tauri

| | **local-web-app** | Pake | Electron | Tauri |
|---|---|---|---|---|
| 包体大小 | **~150KB** | ~3MB | ~150MB | ~5MB |
| 依赖 | **无**（系统自带） | Rust 工具链 | Node + Electron | Rust + Cargo |
| 进程生命周期 | **✅ 自动管理** | ❌ 不管理 | 需自己写 | 需自己写 |
| 系统资源 | 系统 WebView | 系统 WebView | 自带 Chromium | 系统 WebView |
| 安装步骤 | 一条命令 | 安装 Rust + 编译 | 安装 Node + 脚手架 | 安装 Rust + 编译 |

核心差异：**零依赖 + 进程生命周期管理**。不需要装 Rust/Node，不需要编译原生模块，系统自带的 `swiftc` 就够了。

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

编辑 `create` 脚本顶部的 `PRESET_*` 关联数组：

```bash
PRESET_NAME[yourapp]="Your App Name"
PRESET_URL[yourapp]="http://127.0.0.1:8080"
PRESET_START[yourapp]="yourapp serve"
PRESET_ICON[yourapp]="$SCRIPT_DIR/icons/yourapp.png"
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
