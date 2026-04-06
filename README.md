# DouyinAntiAddict - 抖音防沉迷 macOS 应用

> **AI 对话开发历史 (Prompt)** 详见文末 → [📜 完整开发对话](#完整开发对话prompt)

一个 macOS 原生菜单栏应用，监控并统计你每天浏览抖音的时长，超过设定时间后自动拉黑抖音网站（当日不可撤销）。

## 功能

- **实时监控**: 自动检测 Safari、Chrome、Firefox、Edge、Arc、Brave、Opera 等浏览器中的抖音访问
- **时间统计**: 精确统计每日抖音浏览时长
- **自动拉黑**: 超过限额后通过修改 hosts 文件屏蔽抖音（当日不可撤销）
- **次日恢复**: 每天零点自动重置，恢复访问
- **开机自启**: 通过 LaunchAgent 实现开机自动启动
- **菜单栏界面**: 简洁的菜单栏图标显示状态
- **设置面板**: 可自定义每日使用限额

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode 命令行工具（用于编译）

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

1. **辅助功能权限**: 用于监控浏览器活动（系统设置 > 隐私与安全性 > 辅助功能）
2. **管理员权限**: 修改 hosts 文件以屏蔽抖音（拉黑时会弹出密码验证）

## 工作原理

1. **监控**: 每 5 秒检查一次当前活跃浏览器窗口 URL
2. **统计**: 如果 URL 包含 douyin.com 相关域名，累计使用时间
3. **拉黑**: 当使用时间超过设定限额，向 `/etc/hosts` 添加屏蔽规则
4. **恢复**: 次日零点后统计重置，可手动或通过设置面板解除屏蔽

## 屏蔽的域名

- www.douyin.com
- douyin.com
- live.douyin.com
- www.iesdouyin.com
- iesdouyin.com

## 项目结构

```
Douyin_anti_addict/
├── DouyinAntiAddict/
│   ├── AppConstants.swift        # 常量定义
│   ├── DouyinAntiAddictApp.swift # 应用入口
│   ├── DouyinMonitor.swift       # 抖音使用监控
│   ├── HostsManager.swift        # hosts 文件管理
│   ├── StatsTracker.swift        # 统计数据管理
│   ├── SettingsManager.swift     # 用户设置管理
│   ├── LaunchAgentManager.swift  # 开机自启管理
│   ├── StatusBarManager.swift    # 菜单栏控制器
│   ├── SettingsWindow.swift      # 设置窗口
│   └── Info.plist                # 应用配置
├── build.sh                      # 编译脚本
└── README.md                     # 说明文档
```

## 注意事项

- 拉黑操作需要管理员密码（修改 hosts 文件）
- 拉黑后当日无法通过本应用撤销，需手动编辑 `/etc/hosts` 文件
- 确保在系统设置中授予辅助功能权限，否则无法监控浏览器

---

## 完整开发对话 (Prompt)

<details>
<summary>点击展开完整开发对话</summary>

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

