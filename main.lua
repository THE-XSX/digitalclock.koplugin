local _ = require("gettext")
local Blitbuffer = require("ffi/blitbuffer")
local C_ = _.pgettext
local CenterContainer = require("ui/widget/container/centercontainer")
local datetime = require("frontend/datetime")
local Device = require("device")
local Dispatcher = require("dispatcher")
local DataStorage = require("datastorage")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local ImageWidget = require("ui/widget/imagewidget")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local Input = Device.input
local InputContainer = require("ui/widget/container/inputcontainer")
-- local logger = require("logger")
local Notification = require("ui/widget/notification")
local PluginShare = require("pluginshare")
local Screen = Device.screen
local T = require("ffi/util").template
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

do
    local zh_translations = {
        ["Digital clock"] = "数字时钟",
        ["A digital clock showing time, date and an image"] = "一个可显示时间、日期与图片的数字时钟插件",
        ["Show digital clock"] = "显示数字时钟",
        ["Image mode: single image"] = "图片模式：指定单张图片",
        ["Image mode: folder random image"] = "图片模式：文件夹内随机图片",
        ["Image mode: no image"] = "图片模式：不显示图片",
        ["Set single image path"] = "设置单图路径",
        ["Single image path"] = "单图路径",
        ["Set folder random image path"] = "设置随机图片文件夹路径",
        ["Folder random image path"] = "随机图片文件夹路径",
        ["Single image path saved"] = "已保存单图路径",
        ["Folder random image path saved"] = "已保存随机图片文件夹路径",
        ["Invalid value. Please input a number greater than 0"] = "输入无效，请填写大于 0 的数字",
        ["Cancel"] = "取消",
        ["Save"] = "保存",
        ["Please recharge your device. Battery level: %1%"] = "电量偏低，请尽快充电。当前电量：%1%",
        ["Quick path presets"] = "快速路径预设",
        ["Single image path presets"] = "单图路径预设",
        ["Folder random image presets"] = "随机图片目录预设",
        ["Use Kobo root directory"] = "使用 Kobo 根目录",
        ["Use last opened directory"] = "使用最近打开目录",
        ["Use plugin directory"] = "使用插件目录",
        ["Use plugin default image"] = "使用插件默认图片",
        ["Path not available"] = "路径不可用",
        ["Image scale"] = "图片缩放系数",
        ["Set image scale"] = "设置图片缩放系数",
        ["Image scale (default: 1.0)"] = "图片缩放系数（默认：1.0）",
        ["Image scale saved"] = "已保存图片缩放系数",
        ["Invalid value. Please input a number greater than 0"] = "输入无效，请填写大于 0 的数字",
        ["No supported images found in folder: %1"] = "随机目录未找到可用图片：%1",
    }
    local orig__ = _
    _ = function(s)
        if type(s) == "string" and zh_translations[s] then return zh_translations[s] end
        return orig__(s)
    end
    _G._ = _
end

local PLUGIN_ROOT = "plugins/digitalclock.koplugin/"
local BATTERY_CHECK_INTERVAL = 2 * 3600 -- 2 hours
local SUPPORTED_IMAGE_FILES = {"png", "svg", "jpg", "jpeg"}

local has_lfs, lfs = pcall(require, "lfs")

local DigitalClock = InputContainer:new{
    name = "DigitalClock",
    is_doc_only = false,
    dimen = Screen:getSize(),
    is_clock_visible = false,
}

function DigitalClock:onDispatcherRegisterActions()
    Dispatcher:registerAction("digital_clock", {
        category = "none",
        event = "ShowDigitalClock",
        title = _("Digital clock"),
        general = true,
        filemanager = true,
        reader = true,
    })
end

function DigitalClock:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
    self:_loadSettings()
    math.randomseed(os.time())

    

    if Device:hasKeys() then
        self.key_events.AnyKeyPressed = { { Input.group.Any } }
    end
    if Device:isTouchDevice() then
        self.ges_events.TapClose = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{
                    x = 0, y = 0,
                    w = Screen:getWidth(),
                    h = Screen:getHeight(),
                }
            }
        }
    end
end

function DigitalClock:_loadSettings()
    local settings = rawget(_G, "G_reader_settings")

    self.image_mode = settings and settings:readSetting("digitalclock_image_mode", "single") or "single"
    self.single_image_path = settings and settings:readSetting("digitalclock_single_image_path", "") or ""
    self.random_folder_path = settings and settings:readSetting("digitalclock_random_folder_path", "") or ""
    if self.random_folder_path == "" and settings then
        self.random_folder_path = settings:readSetting("digitalclock_slideshow_folder_path", "") or ""
    end
    self.image_scale = settings and settings:readSetting("digitalclock_image_scale", 1.0) or 1.0

    self.image_scale = tonumber(self.image_scale) or 1.0
    if self.image_scale <= 0 then
        self.image_scale = 1.0
    end

    -- 兼容旧版本模式名
    if self.image_mode == "slideshow" then
        self.image_mode = "folder_random"
        self:_saveSetting("digitalclock_image_mode", self.image_mode)
    end

    if self.image_mode ~= "single" and self.image_mode ~= "folder_random" and self.image_mode ~= "none" then
        self.image_mode = "single"
        self:_saveSetting("digitalclock_image_mode", self.image_mode)
    end

    self._settings_loaded = true
end

function DigitalClock:_ensureSettingsLoaded()
    if not self._settings_loaded then
        self:_loadSettings()
    end

    if self.image_mode ~= "single" and self.image_mode ~= "folder_random" and self.image_mode ~= "none" then
        self.image_mode = "single"
    end
    if self.single_image_path == nil then
        self.single_image_path = ""
    end
end

function DigitalClock:_saveSetting(key, value)
    local settings = rawget(_G, "G_reader_settings")
    if settings then
        settings:saveSetting(key, value)
        settings:flush()
    end
end

function DigitalClock:_setImageMode(mode)
    self.image_mode = mode
    if mode == "none" then
        self.random_folder_images = nil
        self.current_image_file = nil
    elseif mode ~= "folder_random" then
        self.current_image_file = nil
    end
    self:_saveSetting("digitalclock_image_mode", mode)
    self:_reopenClockIfVisible()
end

function DigitalClock:_setImageScale(value)
    local text = tostring(value or "")
    text = text:gsub(",", ".")
    local scale = tonumber(text)
    if not scale or scale <= 0 then
        Notification:notify(_("Invalid value. Please input a number greater than 0"))
        return
    end

    if scale < 0.1 then
        scale = 0.1
    elseif scale > 3.0 then
        scale = 3.0
    end

    self.image_scale = scale
    self:_saveSetting("digitalclock_image_scale", scale)
    Notification:notify(_("Image scale saved"))
    self:_reopenClockIfVisible()
end

function DigitalClock:_reopenClockIfVisible()
    if not self.is_clock_visible then
        return
    end
    if self.onCloseWidget then
        self.onCloseWidget()
    end
    self:_startAutoSuspend()
    UIManager:close(self)
    -- schedule re-open on next event loop tick to avoid UI race
    UIManager:scheduleIn(0.01, function()
        -- guard in case widget state changed
        if not self.is_clock_visible then
            self:showClock()
        else
            self:showClock()
        end
    end)
end

function DigitalClock:_normalizePath(path)
    if not path then
        return ""
    end
    local normalized = path:gsub("^%s+", ""):gsub("%s+$", "")
    normalized = normalized:gsub("^\"(.*)\"$", "%1")
    normalized = normalized:gsub("^'(.*)'$", "%1")
    normalized = normalized:gsub("\\", "/")
    return normalized
end

function DigitalClock:_fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

function DigitalClock:_dirExists(path)
    path = self:_normalizePath(path)
    if path == "" then
        return false
    end

    if has_lfs then
        local attr = lfs.attributes(path)
        return attr and attr.mode == "directory" or false
    end

    if io and io.popen then
        local escaped = path:gsub('"', '\\"')
        local ok_pipe, pipe = pcall(io.popen, "[ -d \"" .. escaped .. "\" ] && echo 1 || echo 0", "r")
        if ok_pipe and pipe then
            local out = pipe:read("*l")
            pipe:close()
            return out == "1"
        end
    end

    return false
end

function DigitalClock:_isSupportedImage(path)
    local ext = path:match("%.([^.]+)$")
    if not ext then
        return false
    end
    ext = ext:lower()
    for _, allowed in ipairs(SUPPORTED_IMAGE_FILES) do
        if ext == allowed then
            return true
        end
    end
    return false
end

function DigitalClock:_getBundledImageFile()
    for _, extension in ipairs(SUPPORTED_IMAGE_FILES) do
        local filename = PLUGIN_ROOT .. "image." .. extension
        if self:_fileExists(filename) then
            return filename
        end
    end

    return nil
end

function DigitalClock:_resolveSingleImagePath(path)
    if not path or path == "" then
        return nil
    end

    if self:_fileExists(path) and self:_isSupportedImage(path) then
        return path
    end

    if self:_dirExists(path) then
        local images = self:_collectFolderImages(path)
        if images and #images > 0 then
            return images[1]
        end
    end

    return nil
end

function DigitalClock:_collectFolderImages(folder)
    folder = self:_normalizePath(folder)
    self._random_debug = {
        path = folder,
        has_lfs = has_lfs,
        has_popen = io and io.popen and true or false,
        dir_exists = false,
        count = 0,
        scanner = "none",
        reason = "",
    }
    -- logger.dbg("digitalclock random scan path:", folder)
    if folder == "" then
        -- logger.dbg("digitalclock random scan skipped: empty path")
        -- logger.warn("digitalclock random scan skipped: empty folder path")
        self._random_debug.reason = "empty_path"
        return {}
    end

    if not has_lfs then
        -- logger.dbg("digitalclock random scan: lfs unavailable, using io.popen fallback")
        -- logger.warn("digitalclock random scan: lfs unavailable, trying shell fallback")
        self._random_debug.scanner = "shell"
        self._random_debug.dir_exists = self:_dirExists(folder)
        local images = {}
        if not (io and io.popen) then
            self._random_debug.reason = "popen_unavailable"
            -- logger.warn("digitalclock random scan fallback unavailable: io.popen missing")
            return images
        end

        local escaped = folder:gsub('"', '\\"')
        local commands = {
            { name = "ls", cmd = "ls -1 \"" .. escaped .. "\" 2>/dev/null" },
            { name = "busybox_ls", cmd = "busybox ls -1 \"" .. escaped .. "\" 2>/dev/null" },
            { name = "find", cmd = "find \"" .. escaped .. "\" -maxdepth 1 -type f 2>/dev/null" },
        }
        local seen = {}
        local used = ""

        for _, item in ipairs(commands) do
            local ok_pipe, pipe = pcall(io.popen, item.cmd, "r")
            if ok_pipe and pipe then
                local found_this_cmd = 0
                for entry in pipe:lines() do
                    local line = (entry or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if line ~= "" then
                        local fullpath = line
                        if line:sub(1, 1) ~= "/" then
                            fullpath = folder .. "/" .. line
                        end
                        if self:_isSupportedImage(fullpath) and self:_fileExists(fullpath) and not seen[fullpath] then
                            seen[fullpath] = true
                            table.insert(images, fullpath)
                            found_this_cmd = found_this_cmd + 1
                        end
                    end
                end
                pipe:close()

                if found_this_cmd > 0 then
                    used = item.name
                    break
                end
            end
        end

        self._random_debug.scanner = used ~= "" and used or "shell_none"
        table.sort(images)
        self._random_debug.count = #images
        -- logger.dbg("digitalclock random scan fallback found:", #images)
        if #images == 0 then
            self._random_debug.reason = "shell_scan_empty"
            -- logger.warn("digitalclock random scan fallback found no images in:", folder)
        end
        return images
    end

    if not self:_dirExists(folder) then
        -- logger.dbg("digitalclock random scan skipped: directory not exists")
        -- logger.warn("digitalclock random scan skipped: directory not exists:", folder)
        self._random_debug.dir_exists = false
        self._random_debug.reason = "dir_not_exists"
        return {}
    end
    self._random_debug.dir_exists = true

    local images = {}
    local ok_dir, iter, dir_obj = pcall(lfs.dir, folder)
    if not ok_dir or not iter then
        -- logger.dbg("digitalclock random scan failed: lfs.dir error")
        -- logger.warn("digitalclock random scan failed: lfs.dir error for:", folder)
        self._random_debug.reason = "lfs_dir_error"
        return images
    end

    for entry in iter, dir_obj do
        if entry ~= "." and entry ~= ".." then
            local fullpath = folder .. "/" .. entry
            local ok_attr, attr = pcall(lfs.attributes, fullpath)
            if attr and attr.mode == "file" and self:_isSupportedImage(fullpath) then
                table.insert(images, fullpath)
            end
        end
    end

    table.sort(images)
    self._random_debug.count = #images
    self._random_debug.scanner = "lfs"
    -- logger.dbg("digitalclock random scan found:", #images)
    if #images == 0 then
        self._random_debug.reason = "lfs_scan_empty"
        -- logger.warn("digitalclock random scan found 0 supported images in:", folder)
    end
    return images
end

function DigitalClock:_getRandomFolderImage()
    local path = self:_normalizePath(self.random_folder_path)
    -- logger.dbg("digitalclock random pick from:", path)
    self._random_debug = self._random_debug or {}
    self._random_debug.path = path
    if path == "" then
        -- logger.dbg("digitalclock random pick skipped: empty path")
        -- logger.warn("digitalclock random pick skipped: empty folder path")
        self._random_debug.reason = "empty_path"
        return nil
    end

    -- 兼容：如果用户误填了单文件路径，也允许显示
    if self:_fileExists(path) and self:_isSupportedImage(path) then
        -- logger.dbg("digitalclock random pick path is single file")
        self._random_debug.count = 1
        self._random_debug.scanner = "single_file"
        self._random_debug.selected_file = path
        return path
    end

    self.random_folder_images = self:_collectFolderImages(path)
    if not self.random_folder_images or #self.random_folder_images == 0 then
        -- 再兜底一次：当路径可被单图解析（例如目录首图）时也可返回
        local resolved = self:_resolveSingleImagePath(path)
        if resolved then
            -- logger.dbg("digitalclock random pick resolved by single-image resolver")
            self._random_debug.selected_file = resolved
            self._random_debug.reason = "resolved_single_fallback"
            return resolved
        end
        -- logger.dbg("digitalclock random pick failed: no images")
        -- logger.warn("digitalclock random pick failed: no supported images in:", path)
        self._random_debug.selected_file = nil
        return nil
    end
    local picked = self.random_folder_images[math.random(1, #self.random_folder_images)]
    -- logger.dbg("digitalclock random picked:", picked)
    self._random_debug.selected_file = picked
    return picked
end

function DigitalClock:_createImageWidget(image_file, screen_size)
    if not image_file then return nil end
    screen_size = screen_size or Screen:getSize()

    local scale = tonumber(self.image_scale) or 1.0
    scale = math.max(0.1, math.min(scale, 3.0))

    -- 计算图片显示框：必须同时提供 width/height，并配合 scale_factor=0 才能“等比适配”
    -- 否则在部分机型上会按原图尺寸参与布局，导致看起来覆盖全屏。
    local base_w = math.floor(screen_size.w * 0.45)
    local base_h = math.floor(screen_size.h * 0.30)
    local target_width = math.max(80, math.floor(base_w * scale))
    local target_height = math.max(80, math.floor(base_h * scale))

    -- 让 ImageWidget 在目标框内等比缩放
    local ok, widget = pcall(function() 
        return ImageWidget:new({ 
            file = image_file, 
            alpha = true, 
            file_do_cache = false,
            width = target_width,
            height = target_height,
            scale_factor = 0,
        }) 
    end)
    
    if ok and widget then
        return widget
    end
    
    -- 如果失败，尝试捆绑图片
    local bundled = self:_getBundledImageFile()
    if bundled and bundled ~= image_file then
        local ok2, widget2 = pcall(function() 
            return ImageWidget:new({ 
                file = bundled, 
                alpha = true, 
                file_do_cache = false,
                width = target_width,
                height = target_height,
                scale_factor = 0,
            }) 
        end)
        if ok2 and widget2 then
            return widget2
        end
    end
    
    return nil
end

function DigitalClock:_getCurrentImageFile()
    self:_ensureSettingsLoaded()

    if self.image_mode == "none" then
        return nil
    end

    if self.image_mode == "single" then
        local resolved = self:_resolveSingleImagePath(self.single_image_path)
        if resolved then
            return resolved
        end
        return self:_getBundledImageFile()
    end

    if self.image_mode == "folder_random" then
        self.current_image_file = self:_getRandomFolderImage()
        if not self.current_image_file then
            Notification:notify(T(_("No supported images found in folder: %1"), self.random_folder_path or ""))
            -- logger.warn("digitalclock random mode fallback to bundled image")
            self.current_image_file = self:_getBundledImageFile()
        end
        return self.current_image_file
    end

    -- for unknown/legacy values, do not fallback to bundled image
    return nil
end

function DigitalClock:_shouldShowLandscapeImage(screen_size)
    if not self.image_widget then
        return false
    end

    local left_width = math.max(self.time_widget:getSize().w, self.date_widget:getSize().w)
    left_width = math.min(left_width, math.floor(screen_size.w * 0.5))
    local scale = tonumber(self.image_scale) or 1.0
    local min_image_width = math.floor(screen_size.w * 0.35 * scale)
    local spacer_width = 20
    local safe_margin = 40

    return (left_width + spacer_width + min_image_width + safe_margin) <= screen_size.w
end

function DigitalClock:_showTextInputDialog(title, initial_value, save_callback, default_value)
    local input_dialog
    -- use explicit default value when current setting is empty
    if (initial_value == nil or initial_value == "") and default_value and default_value ~= "" then
        initial_value = default_value
    end

    input_dialog = InputDialog:new{
        title = title,
        input = initial_value or "",
        buttons = {
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(input_dialog)
                    end,
                },
                {
                    text = _("Save"),
                    is_enter_default = true,
                    callback = function()
                        local value = self:_normalizePath(input_dialog:getInputText())
                        save_callback(value)
                        UIManager:close(input_dialog)
                    end,
                },
            },
        },
    }
    UIManager:show(input_dialog)
    input_dialog:onShowKeyboard()
end

function DigitalClock:_showPathChooser(opts)
    local ok_pc, PathChooser = pcall(require, "ui/widget/pathchooser")
    if not ok_pc or not PathChooser then
        Notification:notify(_("Path not available"))
        return
    end

    local chooser_path = self:_normalizePath(opts.path or "")
    if chooser_path == "" then
        chooser_path = self:_getKoboRootPath()
    end

    if opts.select_directory then
        if not self:_dirExists(chooser_path) then
            local parent = chooser_path:match("^(.*)/[^/]+/?$")
            if parent and self:_dirExists(parent) then
                chooser_path = parent
            else
                chooser_path = self:_getKoboRootPath()
            end
        end
    elseif opts.select_file then
        if self:_fileExists(chooser_path) then
            local parent = chooser_path:match("^(.*)/[^/]+$")
            if parent and self:_dirExists(parent) then
                chooser_path = parent
            end
        elseif not self:_dirExists(chooser_path) then
            local parent = chooser_path:match("^(.*)/[^/]+/?$")
            if parent and self:_dirExists(parent) then
                chooser_path = parent
            else
                chooser_path = self:_getKoboRootPath()
            end
        end
    end

    UIManager:show(PathChooser:new{
        title = opts.title,
        path = chooser_path,
        select_directory = opts.select_directory == true,
        select_file = opts.select_file == true,
        show_files = opts.show_files ~= false,
        file_filter = opts.file_filter,
        onConfirm = function(chosen_path)
            if opts.onConfirm then
                opts.onConfirm(self:_normalizePath(chosen_path))
            end
        end,
    })
end

function DigitalClock:_chooseSingleImagePath(start_path)
    self:_showPathChooser{
        title = _("Long-press file's name to choose it"),
        path = start_path or self.single_image_path or self:_getKoboRootPath(),
        select_directory = false,
        select_file = true,
        show_files = true,
        file_filter = function(filename)
            return self:_isSupportedImage(filename)
        end,
        onConfirm = function(chosen_path)
            self:_setSingleImagePath(chosen_path)
        end,
    }
end

function DigitalClock:_chooseRandomFolderPath(start_path)
    self:_showPathChooser{
        title = _("Long-press folder's name to choose it"),
        path = start_path or self.random_folder_path or self:_getKoboRootPath(),
        select_directory = true,
        select_file = false,
        show_files = false,
        onConfirm = function(chosen_path)
            self:_setRandomFolderPath(chosen_path)
        end,
    }
end

function DigitalClock:_getKoboRootPath()
    local settings = rawget(_G, "G_reader_settings")
    if settings then
        local last_dir = settings:readSetting("lastdir")
        if last_dir and last_dir ~= "" and self:_dirExists(last_dir) then
            return last_dir
        end

        local home_dir = settings:readSetting("home_dir")
        if home_dir and home_dir ~= "" and self:_dirExists(home_dir) then
            return home_dir
        end

        local last_file = settings:readSetting("lastfile")
        if last_file and last_file ~= "" then
            local parent = last_file:match("^(.*)/[^/]+$")
            if parent and self:_dirExists(parent) then
                return parent
            end
        end
    end

    if Device:isKobo() then
        return "/mnt/onboard"
    end

    return DataStorage:getDataDir()
end

function DigitalClock:_safeDirPath(path)
    if type(path) ~= "string" or path == "" then
        return "/"
    end
    return path
end

function DigitalClock:_safeDirPathWithSlash(path)
    local p = self:_safeDirPath(path)
    if p:sub(-1) ~= "/" then
        p = p .. "/"
    end
    return p
end

function DigitalClock:_getLastOpenedDirPath()
    local settings = rawget(_G, "G_reader_settings")
    if not settings then
        return nil
    end

    local last_dir = settings:readSetting("lastdir")
    if last_dir and last_dir ~= "" and self:_dirExists(last_dir) then
        return last_dir
    end

    local last_file = settings:readSetting("lastfile")
    if last_file and last_file ~= "" then
        local parent = last_file:match("^(.*)/[^/]+$")
        if parent and self:_dirExists(parent) then
            return parent
        end
    end

    return nil
end

function DigitalClock:_setSingleImagePath(path)
    self.single_image_path = path
    self.image_mode = "single"
    self:_saveSetting("digitalclock_image_mode", self.image_mode)
    self:_saveSetting("digitalclock_single_image_path", path)
    Notification:notify(_("Single image path saved"))
    self:_reopenClockIfVisible()
end

function DigitalClock:_setRandomFolderPath(path)
    self.random_folder_path = self:_normalizePath(path)
    self.image_mode = "folder_random"
    self.random_folder_images = nil
    self.current_image_file = nil
    self:_saveSetting("digitalclock_image_mode", self.image_mode)
    self:_saveSetting("digitalclock_random_folder_path", self.random_folder_path)
    -- 同步写入旧键名，兼容旧版本读取
    self:_saveSetting("digitalclock_slideshow_folder_path", self.random_folder_path)
    Notification:notify(_("Folder random image path saved"))
    self:_reopenClockIfVisible()
end

function DigitalClock:_updateImageWidget(new_file)
    if not new_file then
        return
    end

    -- Recreate the image widget so new size/scale settings take effect.
    if self.is_clock_visible then
        -- easiest reliable path: reopen the whole clock view asynchronously
        self:_reopenClockIfVisible()
        return
    end

    -- If not visible, update stored image so next open will use correct widget
    self.image_widget = self:_createImageWidget(new_file, Screen:getSize())
end

function DigitalClock:_getDateString()
    local wday  = os.date("%a")
    local month = os.date("%B")
    local day   = os.date("%d")
    local year  = os.date("%Y")

    -- @translators Use the following placeholders in the desired order: %1 name of day, %2 name of month, %3 day, %4 year
    return T(C_("Date string", "%1 %2 %3 %4"),
        datetime.shortDayOfWeekToLongTranslation[wday], datetime.longMonthTranslation[month], day, year)
end

function DigitalClock:_pauseAutoSuspend()
    if Device:isCervantes() or Device:isKobo() then
        PluginShare.pause_auto_suspend = true
    elseif Device:isKindle() then
        os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver 1")
    else
        -- logger.warn("pause suspend not supported on this device")
    end
end

function DigitalClock:_startAutoSuspend()
    if Device:isCervantes() or Device:isKobo() then
        PluginShare.pause_auto_suspend = false
    elseif Device:isKindle() then
        os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver 0")
    else
        -- logger.warn("pause suspend not supported on this device")
    end
end

function DigitalClock:_getNextDateRefreshInSeconds()
    return (24 - tonumber(os.date("%H"))) * 3600
end

function DigitalClock:addToMainMenu(menu_items)
    menu_items.digital_clock = {
        text = _("Digital clock"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("Show digital clock"),
                callback = function()
                    DigitalClock:showClock()
                end,
            },
            {
                text = _("Image mode: single image"),
                checked_func = function()
                    return self.image_mode == "single"
                end,
                callback = function()
                    self:_setImageMode("single")
                end,
            },
            {
                text = _("Image mode: folder random image"),
                checked_func = function()
                    return self.image_mode == "folder_random"
                end,
                callback = function()
                    self:_setImageMode("folder_random")
                end,
            },
            {
                text = _("Image mode: no image"),
                checked_func = function()
                    return self.image_mode == "none"
                end,
                callback = function()
                    self:_setImageMode("none")
                end,
            },
            {
                text = _("Set single image path"),
                callback = function()
                    self:_chooseSingleImagePath(self.single_image_path)
                end,
            },
            {
                text = _("Set folder random image path"),
                callback = function()
                    self:_chooseRandomFolderPath(self.random_folder_path)
                end,
            },
            {
                text = _("Quick path presets"),
                sub_item_table = {
                    {
                        text = _("Single image path presets"),
                        sub_item_table = {
                            {
                                text = _("Use plugin default image"),
                                callback = function()
                                    local image_file = self:_getBundledImageFile()
                                    self:_setSingleImagePath(image_file)
                                end,
                            },
                            {
                                text = _("Use Kobo root directory"),
                                callback = function()
                                    self:_chooseSingleImagePath(self:_getKoboRootPath())
                                end,
                            },
                            {
                                text = _("Use last opened directory"),
                                callback = function()
                                    local last_dir = self:_getLastOpenedDirPath()
                                    if not last_dir then
                                        Notification:notify(_("Path not available"))
                                        return
                                    end
                                    self:_chooseSingleImagePath(last_dir)
                                end,
                            },
                            {
                                text = _("Use plugin directory"),
                                callback = function()
                                    self:_chooseSingleImagePath(PLUGIN_ROOT)
                                end,
                            },
                        },
                    },
                    {
                        text = _("Folder random image presets"),
                        sub_item_table = {
                            {
                                text = _("Use Kobo root directory"),
                                callback = function()
                                    self:_setRandomFolderPath(self:_safeDirPath(self:_getKoboRootPath()))
                                end,
                            },
                            {
                                text = _("Use last opened directory"),
                                callback = function()
                                    local last_dir = self:_getLastOpenedDirPath()
                                    if not last_dir then
                                        Notification:notify(_("Path not available"))
                                        return
                                    end
                                    self:_setRandomFolderPath(last_dir)
                                end,
                            },
                            {
                                text = _("Use plugin directory"),
                                callback = function()
                                    self:_setRandomFolderPath(PLUGIN_ROOT)
                                end,
                            },
                        },
                    },
                },
            },
            {
                text = _("Set image scale"),
                callback = function()
                    self:_showTextInputDialog(_("Image scale (default: 1.0)"), tostring(self.image_scale or 1.0), function(value)
                        self:_setImageScale(value)
                    end, "1.0")
                end,
            },
        },
    }
end

function DigitalClock:showClock()
    -- 强制重新读取设置，确保运行时修改（尤其图片缩放）立即生效
    self:_loadSettings()

    -- always refresh current screen size (important after rotation)
    self.dimen = Screen:getSize()
    local screen_size = self.dimen
    self.is_landscape = screen_size.w > screen_size.h

    local time_font_size = self.is_landscape and 120 or 170
    local date_font_size = self.is_landscape and 32 or 40

    self.time_widget = TextWidget:new{
        text = datetime.secondsToHour(os.time()),
        face = Font:getFace("cfont", time_font_size)
    }

    self.separator = VerticalSpan:new{height = 130}

    self.date_widget = TextWidget:new{
        text = self:_getDateString(),
        face = Font:getFace("cfont", date_font_size)
    }


    local image_file = self:_getCurrentImageFile()

    -- adapt layout for landscape vs portrait
    local vertical_items = { self.time_widget, self.date_widget }
    
    local image_display_height = 0
    if image_file then
        -- create widget via helper
        self.image_widget = self:_createImageWidget(image_file, screen_size)
        if self.image_widget then
            local scale = tonumber(self.image_scale) or 1.0
            scale = math.max(0.1, math.min(scale, 3.0))

            local base_w = self.is_landscape and math.floor(screen_size.w * 0.32) or math.floor(screen_size.w * 0.45)
            local base_h = self.is_landscape and math.floor(screen_size.h * 0.42) or math.floor(screen_size.h * 0.30)

            local slot_w = math.max(80, math.floor(base_w * scale))
            local slot_h = math.max(80, math.floor(base_h * scale))

            self.image_container = CenterContainer:new{
                self.image_widget,
                dimen = Geom:new{
                    x = 0,
                    y = 0,
                    w = slot_w,
                    h = slot_h,
                },
            }

            image_display_height = slot_h
        else
            self.image_container = nil
            image_display_height = 0
        end
    else
        self.image_widget = nil
        self.image_container = nil
    end

    local text_lift = 0
    if image_display_height > 0 then
        text_lift = math.max(12, math.floor(image_display_height * (self.is_landscape and 0.18 or 0.10)))
    end

    if self.is_landscape then
        -- landscape: time/date on left, image on right
        if text_lift > 0 then
            table.insert(vertical_items, VerticalSpan:new{ height = text_lift })
        end
        local left_column = VerticalGroup:new(vertical_items)
        local spacer = HorizontalSpan and HorizontalSpan:new{ width = 20 } or VerticalSpan:new{ height = 20 }
        local right = self.image_container or VerticalGroup:new{}
        self.vertical_container = HorizontalGroup:new{ left_column, spacer, right }
        self.centered_container = CenterContainer:new{ self.vertical_container, dimen = self.dimen }
    else
        -- portrait: vertical layout (time, date, image)
        if self.image_container then
            table.insert(vertical_items, self.separator)
            table.insert(vertical_items, self.image_container)
            if text_lift > 0 then
                table.insert(vertical_items, VerticalSpan:new{ height = text_lift })
            end
        end
        self.vertical_container = VerticalGroup:new(vertical_items)
        self.centered_container = CenterContainer:new{ self.vertical_container, dimen = self.dimen }
    end

    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        self.centered_container
    }

    local time_widget_height = self.time_widget:getSize().h
    local date_widget_height = self.date_widget:getSize().h

    self.time_dimen = Geom:new{
        x = 0,
        y = 100,
        w = self.dimen.w,
        h = time_widget_height,
    }

    self.date_dimen = Geom:new{
        x = 0,
        y = 100 + time_widget_height,
        w = self.dimen.w,
        h = date_widget_height,
    }

    self.powerd = Device:getPowerDevice()

    UIManager:show(self, "full")
    self.is_clock_visible = true

    self:_pauseAutoSuspend()
    self:setupAutoRefreshTime()
end

function DigitalClock:setupAutoRefreshTime()
    -- Setup refresh functions
    self.autoRefreshTime = function()
        local current_is_landscape = Screen:getWidth() > Screen:getHeight()
        if self.is_landscape ~= current_is_landscape then
            self:_reopenClockIfVisible()
            return
        end

        -- Update clock
        self.time_widget:setText(datetime.secondsToHour(os.time()))
        self.vertical_container:free()

        UIManager:setDirty(self, "full")

        UIManager:scheduleIn(61 - tonumber(os.date("%S")), self.autoRefreshTime)
    end

    self.autoRefreshDate = function()
        -- Update date
        self.date_widget:setText(self:_getDateString())
        self.vertical_container:free()

        UIManager:setDirty(self, "full")

        UIManager:scheduleIn(self:_getNextDateRefreshInSeconds(), self.autoRefreshDate)
    end

    self.autoCheckBatteryLevel = function()
        -- Check battery level
        if self.bat_info_msg then
            self.bat_info_msg:onTapClose()
        end

        if Device:hasBattery() then
            local main_batt_lvl = self.powerd:getCapacity()

            if Device:hasAuxBattery() and self.powerd:isAuxBatteryConnected() then
                local aux_batt_lvl = self.powerd:getAuxCapacity()
                is_charging = self.powerd:isAuxCharging()

                -- Sum both batteries for the actual text
                batt_lvl = (main_batt_lvl + aux_batt_lvl) / 2
            else
                is_charging = self.powerd:isCharging()
                batt_lvl = main_batt_lvl
            end

            if is_charging then
                battery_indicator = Notification:new{
                    text = "⚡" .. batt_lvl .. "%",
                    face = Font:getFace("cfont", 20),
                    timeout = BATTERY_CHECK_INTERVAL
                }

                UIManager:show(battery_indicator)
            end

            if not is_charging and batt_lvl < 20 then
                self.bat_info_msg = InfoMessage:new{
                    text = T("Please recharge your device. Battery level: %1%", batt_lvl)
                }
                UIManager:show(self.bat_info_msg)
            end

            UIManager:scheduleIn(BATTERY_CHECK_INTERVAL, self.autoCheckBatteryLevel)
        end
    end

    -- Unschedule refresh functions
    self.onCloseWidget = function()
        self.is_clock_visible = false
        UIManager:unschedule(self.autoRefreshTime)
        UIManager:unschedule(self.autoRefreshDate)
        UIManager:unschedule(self.autoCheckBatteryLevel)
    end
    self.onSuspend = function()
        UIManager:unschedule(self.autoRefreshTime)
        UIManager:unschedule(self.autoRefreshDate)
        UIManager:unschedule(self.autoCheckBatteryLevel)
    end
    self.onResume = function()
        self.autoRefreshTime()
        self.autoRefreshDate()
        self.autoCheckBatteryLevel()
    end

    -- Schedule run refresh functions
    -- Refresh time every minute
    UIManager:scheduleIn(61 - tonumber(os.date("%S")), self.autoRefreshTime)
    -- Refresh date every day
    UIManager:scheduleIn(self:_getNextDateRefreshInSeconds(), self.autoRefreshDate)
    -- Check battery level every 2h
    UIManager:scheduleIn(2 * 3600, self.autoCheckBatteryLevel)
end


function DigitalClock:onTapClose()
    self:_startAutoSuspend()
    self.is_clock_visible = false
    UIManager:close(self)
end
DigitalClock.onAnyKeyPressed = DigitalClock.onTapClose

function DigitalClock:onShowDigitalClock()
    DigitalClock:showClock()
end

return DigitalClock
