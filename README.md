# 团子 AI (Duanzi AI)

> 💡 **项目说明**：本项目是一个 **AI 辅助编程** 的实验性作品，核心代码由 GPT、Gemini、Claude、GLM 等模型生成。作为一个正在学习 ArkTS 的开发者，我非常欢迎社区提交 Issue 或 PR，一起交流与改进。

**团子 AI** 是一款专为 **HarmonyOS NEXT** 打造的现代化多模型 AI 对话客户端。它支持多 API 管理、流式响应、Markdown 完美渲染以及多模态交互（图片/文件），旨在为你提供流畅的原生鸿蒙 AI 体验。

## ✨ 核心特性

- **多模型聚合**：支持按需添加 API 配置，快速切换不同服务商与模型。
- **流畅交互**：全流程流式输出体验，对话无缝衔接。
- **富文本渲染**：Markdown 渲染引擎加持，完美展示代码块、引用与公式。
- **多模态支持**：支持发送图片与文件附件，不仅限于纯文本交流。
- **HTML 预览**：内置 HTML 代码预览弹窗，无需离开应用即可查看结果。
- **会话管理**：历史会话按天分组，且支持自动持久化存储。

## 📸 界面预览

| 封面 | 识图演示 | 设置页 |
| :---: | :---: | :---: |
| ![封面](docs/screenshots/cover.jpg) | ![识图演示](docs/screenshots/vision-demo.jpg) | ![设置页](docs/screenshots/settings.jpg) |

| HTML 预览 | 模型选择 |
| :---: | :---: |
| ![HTML 预览](docs/screenshots/html-preview.jpg) | ![模型选择](docs/screenshots/model-selector.jpg) |

## 🛠️ 技术栈

本项目基于 **HarmonyOS NEXT** 原生开发栈构建：

- **核心框架**：ArkTS / ArkUI
- **网络通信**：`@kit.NetworkKit`
- **Markdown 渲染**：`@luvi/lv-markdown-in` (感谢开源社区贡献)

## 📂 项目结构

```text
entry/src/main/ets/
├── pages/                 # 页面与主要业务逻辑
├── view/                  # 可复用 UI 组件库
├── entryability/          # 应用入口 Ability
└── entrybackupability/    # 数据备份与恢复扩展 Ability
```

## 🚀 快速开始

### 环境要求

- **IDE**：DevEco Studio（建议保持最新版本）
- **SDK**：HarmonyOS SDK `6.0.2(22)` 或更高版本
- **Runtime**：Node.js

### 安装步骤

1. **克隆代码**
   ```bash
   git clone [your-repo-url]
   ```

2. **安装依赖**
   ```bash
   ohpm install
   ```

3. **构建与运行**
   ```bash
   hvigorw assembleHap
   ```
   或使用 DevEco Studio 直接按 `Run` 按钮运行。

## ⚙️ 配置说明

首次启动应用后，请前往**设置页面**添加 API 配置：

1. **API Endpoint**：模型服务商的接口地址（如 OpenAI / DeepSeek / Claude 等兼容 API）。
2. **API Key**：你的 API 密钥。
3. **默认模型**：设置你需要调用的具体模型名称（如 `gpt-4o`, `gemini-1.5-pro` 等）。
4. **参数微调**：可自定义温度（Temperature）与最大输出 Token 限制。

## ❤️ 致谢

- 特别感谢 **GPT-4o**, **Gemini 1.5 Pro**, **Claude 3.5 Sonnet**, **GLM-4** 等 AI 模型在这个项目开发过程中提供的全方位协助。
- 感谢 [lv-markdown-in](https://gitee.com/luvi/lv-markdown-in) 提供的优秀 Markdown 渲染组件。

---

*Made with ❤️ and AI.*
