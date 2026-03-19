# ConfBar

![GitHub stars](https://img.shields.io/github/stars/zkforge/CCFDDLMenuBar?style=social)
![GitHub release](https://img.shields.io/github/v/release/zkforge/CCFDDLMenuBar)
![License](https://img.shields.io/github/license/zkforge/CCFDDLMenuBar)

原生 macOS 菜单栏应用（SwiftUI + MenuBarExtra），展示 CCFDDL 最近会议截止日期与倒计时。

[English Documentation](./README.md)

## 应用截图

![菜单面板（中文）](./Assets/Screenshots/menu-zh.png)
![菜单面板（英文）](./Assets/Screenshots/menu-en.png)

## 功能

- 菜单栏默认显示 `ConfBar`，可在设置中指定一个会议并显示分钟级倒计时（如 `AAAI: 2d 10h 20m`）
- 菜单栏会议选择支持搜索（别名 + 模糊匹配），会议很多时可快速定位
- 下拉面板显示未来截止会议列表（默认前 30 条）
- 独立设置窗口：筛选、排序、提醒和导出统一管理
- 应用退出入口在菜单栏面板与设置窗口均可用
- 手动刷新 + 每 30 分钟自动刷新
- 点击会议条目直接打开官网链接
- 截止提醒：支持 `24h/6h/1h` 本地通知（可开关）
- 日历导出：一键导出 `.ics`
- 搜索增强：支持会议别名（如 `NeurIPS/NIPS`）与模糊匹配
- 智能排序：支持按距离截止、会议日期、CCF 等级排序（默认距离截止）
- 筛选持久化：关键词、CCF 级别、方向、仅收藏、排序方式和菜单栏会议选择自动保存
- 收藏置顶：收藏会议在列表中自动排到前面
- 数据源：`https://ccfddl.cn/`

## 环境要求

- macOS 13+
- Xcode 16+（或 Swift 6.0+ 工具链）

## 运行

运行后会在菜单栏显示文本（默认 `CCF`）。应用为菜单栏模式，不显示 Dock 图标。
点击菜单栏面板里的“设置”可打开独立设置窗口。
首次启用提醒时，macOS 会弹出通知授权请求。

## 目录结构

```text
confbar/
├── Assets/                          # 应用资源（图标与截图）
│   └── Screenshots/                # README 展示截图
├── Sources/ConfBar/                  # 核心业务与应用入口
│   └── Views/                      # 菜单栏与设置界面
├── LICENSE                         # 开源许可证（MIT）
├── NOTICE                          # 数据来源与归属声明
├── Package.swift                   # Swift Package 配置
├── README.md                       # 英文文档入口
└── README-zh.md                    # 中文文档
```

## 开源许可证

本项目使用 MIT 许可证发布，详见 [LICENSE](./LICENSE)。

## 数据来源与归属声明

- 本项目通过 `https://ccfddl.cn/` 拉取公开会议信息，仅用于截止时间展示与提醒。
- 本项目是独立实现的客户端，不是 `ccfddl` 官方发布。
- 若复用本项目代码，请遵守 [LICENSE](./LICENSE)。
- 若在本仓库中引入或复用 `ccfddl/ccf-deadlines` 的代码或数据文件，请保留其 MIT 许可与版权声明。

## 致谢

- 上游生态项目：[`ccfddl/ccf-deadlines`](https://github.com/ccfddl/ccf-deadlines)（MIT）
- 额外说明见 [NOTICE](./NOTICE)。
