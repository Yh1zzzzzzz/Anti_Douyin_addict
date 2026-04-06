# DouyinAntiAddict - 抖音防沉迷 macOS 应用

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
