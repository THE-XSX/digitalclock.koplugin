# digitalclock.koplugin

将你的电子书设备用作数字时钟的 KOReader 插件。显示时间、日期和可选图片。

预览与更多信息见英文说明：[README.md](README.md)

**功能简介：**

- **显示时间与日期**：在全屏模式下以大字体显示当前时间与日期。

- **图片支持**：可同时显示一张图片，支持三种图片模式：单张图片（single）、文件夹随机图片（folder_random）、不显示图片（none）。

- **图片缩放**：支持缩放系数（默认 1.0），取值范围约 0.1 - 3.0，用于调节图片显示大小。

- **低电量提醒**：会周期性检查电量并在低电量时弹出提示；显示时会暂停系统自动休眠（仅在显示时）。

- **多语言**：插件自带翻译接口（含中文翻译），如果发现本地化问题可以提出 issue。

**支持的图片格式**

- png, svg, jpg, jpeg

**安装与使用**

- 将整个 `digitalclock.koplugin` 文件夹复制到你的 `koreader/plugins` 目录下。

- 在设备上进入：工具 -> 更多工具 -> Digital clock（数字时钟）。

**配置（通过插件菜单）**

- Image mode（图片模式）

	- 单张图片（Image mode: single image）：使用 `Single image path` 指定一张图片或文件夹（若填写文件夹则取该文件夹内第一张图片）。

	- 文件夹随机图片（Image mode: folder random image）：在指定文件夹内随机选择一张支持格式的图片显示。

	- 不显示图片（Image mode: no image）：只显示时间与日期。

- Set single image path / Set folder random image path：通过输入或快速预设设置路径。

- Quick path presets（快速路径预设）：

	- 使用插件自带默认图片（Use plugin default image）

	- 使用 Kobo 根目录（Use Kobo root directory）

	- 使用最近打开的目录（Use last opened directory）

	- 使用插件目录（Use plugin directory）

- Image scale（图片缩放系数）：在菜单中设置，输入小数（小数点可用逗号或点）。无效输入会提示报错。

**实现细节与行为说明**

- 插件在显示时会暂停系统自动休眠，以便作为持续显示的时钟；关闭时会恢复系统自动休眠。不同设备上采用不同的实现（Kobo/Cervantes 使用 PluginShare，Kindle 使用 lipc-set-prop）。

- 图片加载：插件会根据当前屏幕尺寸与缩放系数计算图片显示区域并让图片等比适配；若加载指定图片失败，会尝试使用插件捆绑的默认图片作为回退。

- 文件/路径处理：会对输入路径做规范化（去空格、去引号，将反斜杠转换为正斜杠）；若路径是文件夹，插件会扫描并收集支持的图片。

- 随机图片扫描：优先使用 lfs（LuaFileSystem），如果不可用则回退到系统命令（如 ls/find）扫描；在某些环境下可能无法扫描，此时会给出提示。

**电量与提示**

- 插件会每 2 小时检查一次电池状态；当设备充电时会短暂显示充电图标与百分比；当未充电且电量低于 20% 时会显示信息提示“请尽快充电”。

**注意与警告**

- `clock.koplugin` 与 `digitalclock.koplugin` 互相冲突，使用前请**删除**设备上的 `clock.koplugin`。

- 使用过大的非 SVG 图片可能会导致 KOReader 崩溃，请在使用前缩小图片或使用 SVG 格式以稳妥显示。

**调试与兼容性**

- 插件内包含一些调试信息（在代码中会记录随机扫描器、扫描计数等），便于排查“未找到图片”的问题。

- 如果在你的语言或设备上出现显示问题，请在仓库中提交 issue，并附上设备型号与尽可能多的日志/调试信息（例如随机扫描时的调试结构）。详见主程序：[main.lua](main.lua)

---

## English version

Use your e-reader as a digital clock with this KOReader plugin. It displays the current time, date and an optional image.

Features:

- Fullscreen time and date display with large fonts.

- Image support with three modes: single image (`single`), random image from folder (`folder_random`), and no image (`none`).

- Image scale control (default 1.0, effective range ~0.1–3.0).

- Low-battery notification and periodic battery checks (every 2 hours). The plugin pauses auto-suspend while the clock is visible.

- Locale-aware (includes Chinese translations); please file an issue if translations are incorrect.

Supported image formats:

- png, svg, jpg, jpeg

Installation and usage:

- Copy the `digitalclock.koplugin` folder into your `koreader/plugins` directory.

- On the device open: Tools -> More Tools -> Digital clock.

Configuration (via plugin menu):

- Image mode:

	- Single image: set `Single image path` to a file or folder (if folder is given, the first supported image inside will be used).

	- Folder random: set a folder and the plugin will pick a random supported image from it.

	- No image: show only time and date.

- Set single image path / Set folder random image path: enter a path or use quick presets.

- Quick path presets include: Use plugin default image, Use Kobo root directory, Use last opened directory, Use plugin directory.

- Image scale: enter a decimal value (dot or comma); invalid input will be rejected.

Behavior and implementation details:

- The plugin pauses system auto-suspend while visible and resumes it when closed. Implementation differs by device (Kobo/Cervantes via PluginShare, Kindle via `lipc-set-prop`).

- Images are loaded and scaled to fit a computed display slot; if loading fails the bundled plugin image is used as a fallback.

- Path handling normalizes input (trims whitespace and quotes, converts backslashes to slashes). If a folder is given the plugin scans it for supported images.

- Folder scanning prefers `lfs` (LuaFileSystem); if unavailable it falls back to shell commands (`ls`/`find`) where supported.

Battery and notifications:

- The plugin checks battery every 2 hours. When charging it briefly shows a charging indicator; when not charging and battery <20% it displays a reminder to recharge.

Warnings:

- `clock.koplugin` conflicts with `digitalclock.koplugin`. Remove `clock.koplugin` before using this plugin.

- Very large non-SVG images may crash KOReader; prefer SVG or shrink large images.

Debug and compatibility:

- The code includes debug info for random-folder scanning (scanner used, count, selected file) to help troubleshooting.

- If you experience issues, please open an issue with device model and any logs or debug data. See `main.lua` for implementation details.
