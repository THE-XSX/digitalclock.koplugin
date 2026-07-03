# digitalclock.koplugin

中文 | [English](#english)

将你的电子书阅读器当作数字时钟使用。这个 KOReader 插件可以显示时间、日期，以及一张指定图片或随机图片。

![preview](https://github.com/user-attachments/assets/68ad0b89-9ab2-45f4-8765-8397d386daec)

插件运行时会暂停自动休眠，但整体仍以低功耗显示为目标。关闭无线连接的情况下，通常可以持续显示较长时间。电量较低时，插件会弹出提醒。

## 中文说明

### 功能

- 全屏显示时间和日期。
- 图片显示支持三种模式：
  - 单张图片
  - 文件夹内随机图片
  - 不显示图片
- 支持 png、svg、jpg、jpeg。
- 支持图片缩放设置。
- 支持低电量提醒。
- 支持多语言显示。

### 安装

将 digitalclock.koplugin 整个文件夹复制到 koreader/plugins 目录。

### 使用

在设备中打开：Tools -> More Tools -> Digital clock。

### 配置

插件菜单中可以设置以下内容：

- Image mode: single image
  - 使用单张图片模式。
- Image mode: folder random image
  - 从指定文件夹中随机选择一张图片。
- Image mode: no image
  - 只显示时间和日期。
- Set single image path
  - 打开文件选择器，长按图片文件名确认选择。
- Set folder random image path
  - 打开文件夹选择器，长按文件夹名称确认选择。
- Quick path presets
  - 提供插件默认图片、Kobo 根目录、最近打开目录、插件目录等快捷入口。
- Set image scale
  - 设置图片缩放系数，默认值为 1.0。

### 自定义图片

如果你希望直接使用插件目录中的默认图片，可以把图片放进 digitalclock.koplugin 目录，并命名为以下任一文件名：

- image.png
- image.jpg
- image.svg
- image.jpeg

### 注意事项

- clock.koplugin 与 digitalclock.koplugin 会冲突。使用前请先从设备中移除 clock.koplugin。
- 过大的非 SVG 图片可能导致 KOReader 崩溃，建议优先使用 SVG 或先压缩图片。

---

## English

Use your e-reader as a digital clock with this KOReader plugin. It displays the current time, date, and an optional image.

### Features

- Fullscreen time and date display.
- Three image modes:
  - single image
  - random image from folder
  - no image
- Supported image formats: png, svg, jpg, jpeg
- Configurable image scale.
- Low-battery reminder.
- Locale-aware UI.

### Installation

Copy the whole digitalclock.koplugin folder into koreader/plugins.

### Usage

Open on device: Tools -> More Tools -> Digital clock.

### Configuration

Available from the plugin menu:

- Image mode: single image
- Image mode: folder random image
- Image mode: no image
- Set single image path
  - Opens a file chooser. Long-press an image filename to confirm.
- Set folder random image path
  - Opens a folder chooser. Long-press a folder name to confirm.
- Quick path presets
  - Includes plugin default image, Kobo root directory, last opened directory, and plugin directory.
- Set image scale
  - Sets the image scale factor, default 1.0.

### Custom image

To use a bundled default image from the plugin directory, place an image in digitalclock.koplugin and rename it to one of:

- image.png
- image.jpg
- image.svg
- image.jpeg

### Warnings

- clock.koplugin conflicts with digitalclock.koplugin. Remove clock.koplugin before using this plugin.
- Very large non-SVG images may crash KOReader. Prefer SVG or resize large images first.