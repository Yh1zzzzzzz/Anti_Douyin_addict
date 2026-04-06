# DouyinAntiAddict - 抖音防沉迷 macOS 应用

<p align="center">
  <img src="./logo.png" alt="DouyinAntiAddict Logo" width="180">
</p>

> **完整 Prompt（原始版）已置顶保留。**
> 为了方便归档和复现，下面先放原始开发对话；文末另附一份仅精简 Assistant 回复的速览版。

## 完整 Prompt（原始版）

<details open>
<summary>点击展开完整原始开发对话</summary>

### 对话记录

**User:** 我想写一个macOS原生程序，监控、统计我电脑每天浏览抖音(https://www.douyin.com/)的时长，如果超过我设定的时长，今日（仅限于今日）拉黑抖音的网站不再允许访问且无法撤销。要求有图形化界面，开机自动启动

**Assistant:** 创建了项目结构，包含以下核心模块：
- `DouyinAntiAddictApp.swift` - SwiftUI 应用入口
- `AppConstants.swift` - 常量定义
- `StatusBarManager.swift` - 菜单栏控制器
- `DouyinMonitor.swift` - 浏览器监控（AppleScript 获取 URL）
- `HostsManager.swift` - hosts 文件管理
- `StatsTracker.swift` - 每日使用统计
- `SettingsManager.swift` - 用户设置
- `LaunchAgentManager.swift` - 开机自启
- `SettingsWindow.swift` - 设置窗口
- `Info.plist` - 应用配置

---

**User:** 这个程序的核心功能实现是如何进行的？我的电脑一直是使用VPN全局TUN模式，这一点对于我们的核心功能有没有影响？

**Assistant:** 解释了核心功能实现原理：
1. NSWorkspace.frontmostApplication 获取当前活跃应用
2. AppleScript 查询浏览器当前标签页 URL
3. 检查 URL 是否包含 douyin.com 相关域名
4. 累计使用时间，超限时修改 /etc/hosts 屏蔽

**VPN TUN 模式影响：** hosts 文件可能被绕过，因为 VPN 可能使用自己的 DNS 服务器，不经过系统 DNS 解析。建议添加 pf 防火墙作为双重保障，pf 工作在内核网络层，所有网络接口（包括 TUN 虚拟网卡）统一生效，VPN 无法绕过。

**User 选择:** hosts + pf 防火墙（推荐）

---

**Assistant:** 添加了 pf 防火墙双重封锁机制：
- 创建 `BlockManager.swift` 替代 `HostsManager.swift`
- 第一层：hosts DNS 解析拦截（应用层）
- 第二层：pf 防火墙包过滤（内核网络栈）
- pf 规则：`block drop quick` 拦截 80/443 端口的 TCP/UDP 流量
- 通过 `dig +short` 解析抖音域名为实际 IP，创建 pf table

---

**User:** 这个限制是保证只会影响当日的抖音浏览对吗？第二天会重制？

**Assistant:** 检查代码后发现**有问题**：
- ✅ 统计数据会自动按天重置（StatsTracker 按日期 yyyy-MM-dd 存储）
- ❌ 封锁不会自动重置 - BlockManager 修改的 hosts 和 pf 规则会一直存在

修复方案：
- 添加 `blockedDateKey` 保存封锁日期
- 添加 `isBlockedToday()` 方法判断是否是当日封锁
- 添加 `checkAndResetIfNewDay()` 方法，每次检查时对比日期，不同则自动解封
- 在 `StatusBarManager.checkDouyinUsage()` 中每 5 秒调用 `checkAndResetIfNewDay()`
- 删除旧的 `HostsManager.swift`

**保证只影响当日，第二天自动恢复。**

---

**User:** 把这个项目推送到git@github.com:Yh1zzzzzzz/Anti_Douyin_addict.git，在README的最显眼的地方附上我们的聊天历史Prompt

**User:** 继续未完成的任务

</details>

## 项目简介

一个 macOS 原生菜单栏应用，监控并统计你每天浏览抖音的时长，超过设定时间后自动拉黑抖音网站，并在第二天自动恢复访问。

## 功能

- **实时监控**: 自动检测 Safari、Chrome、Firefox、Edge、Arc、Brave、Opera 等浏览器中的抖音访问
- **时间统计**: 按天累计抖音浏览时长
- **双层封锁**: 同时使用 `hosts` 和 `pf` 防火墙拦截，兼顾普通 DNS 场景与 VPN/TUN 场景
- **次日恢复**: 每天零点自动重置统计并解除封锁
- **开机自启**: 通过 LaunchAgent 开机后自动启动
- **菜单栏界面**: 菜单栏图标显示当前状态和剩余时长
- **设置面板**: 可自定义每日使用限额，并查看最近 7 天统计

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- 完整版 Xcode（已验证 `xcodebuild` 构建流程）

## 编译

```bash
chmod +x build.sh
./build.sh
```

## 运行

```bash
open build/DouyinAntiAddict.app
```

## 安装到 Applications

```bash
cp -r build/DouyinAntiAddict.app /Applications/
```

## 权限说明

首次运行时，系统会请求以下权限：

1. **辅助功能权限**: 用于读取当前浏览器窗口状态
2. **通知权限**: 用于在达到当日上限时发出系统通知
3. **管理员权限**: 用于修改 `hosts` 和加载 `pf` 规则

## 工作原理

1. **监控**: 每 5 秒检查一次当前前台浏览器标签页 URL
2. **统计**: 仅当 URL 的真实 host 属于 `douyin.com` / `iesdouyin.com` 域名时累计时间
3. **封锁**: 超过限额后，同时写入 `hosts` 规则并加载 `pf` 规则
4. **恢复**: 记录封锁日期，到第二天自动解除

## 屏蔽的域名

- `www.douyin.com`
- `douyin.com`
- `live.douyin.com`
- `www.iesdouyin.com`
- `iesdouyin.com`

## 项目结构

```text
Douyin_anti_addict/
├── DouyinAntiAddict/
│   ├── AppConstants.swift
│   ├── BlockManager.swift
│   ├── DouyinAntiAddictApp.swift
│   ├── DouyinMonitor.swift
│   ├── LaunchAgentManager.swift
│   ├── SettingsManager.swift
│   ├── SettingsWindow.swift
│   ├── StatsTracker.swift
│   ├── StatusBarManager.swift
│   ├── Assets.xcassets/
│   └── Info.plist
├── build.sh
├── logo.png
└── README.md
```

## 注意事项

- 超限封锁需要管理员密码
- 如果没有授予辅助功能权限，浏览器监控不会生效
- `pf` 规则会覆盖普通 DNS 绕过路径，但系统安全策略、企业网络配置和浏览器行为仍可能影响实际效果

---

## 精简开发对话（Assistant 回复精简版）

<details>
<summary>点击展开精简版</summary>

**User:** 我想写一个macOS原生程序，监控、统计我电脑每天浏览抖音(https://www.douyin.com/)的时长，如果超过我设定的时长，今日（仅限于今日）拉黑抖音的网站不再允许访问且无法撤销。要求有图形化界面，开机自动启动

**Assistant:** 先把项目拆成入口、监控、统计、封锁、设置、自启几个模块，按菜单栏 macOS 应用来实现。

---

**User:** 这个程序的核心功能实现是如何进行的？我的电脑一直是使用VPN全局TUN模式，这一点对于我们的核心功能有没有影响？

**Assistant:** 解释监控链路，同时指出单靠 `hosts` 可能被 VPN/TUN 绕过，建议补 `pf` 防火墙。

**User 选择:** hosts + pf 防火墙（推荐）

---

**Assistant:** 引入 `BlockManager`，把封锁升级为 `hosts + pf` 双层方案。

---

**User:** 这个限制是保证只会影响当日的抖音浏览对吗？第二天会重制？

**Assistant:** 发现“统计会重置，但封锁不会自动解除”的问题，并补上按天记录与跨天自动解封逻辑。

---

**User:** 把这个项目推送到git@github.com:Yh1zzzzzzz/Anti_Douyin_addict.git，在README的最显眼的地方附上我们的聊天历史Prompt

**User:** 继续未完成的任务

**Assistant:** 继续完善 README、工程配置、构建链路和后续修复。

</details>
