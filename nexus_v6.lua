--[[
    NEXUS V6 | Monochrome Movement Hub
    Roblox Studio | LocalScript
    Place in StarterPlayer > StarterPlayerScripts

    Movement : Walk speed, sprint multiplier, jump power, double / infinite jump,
               air control, fly, wall run, wall hop, noclip
    Abilities: Dash (+FOV kick), glide, bunny hop, teleport to cursor,
               checkpoint (with marker), void rescue
    World    : gravity, FOV, max zoom, brightness, time of day, freeze time,
               fullbright, no fog
    Interface: animated loading screen, animated window, minimize pill, toast notifications, speedometer HUD,
               crosshair, accent colors, window opacity, rebindable keys,
               presets, editable slider values, FPS / ping stats
    Extras   : highlight ESP, name/distance tags, team colors, trail (rainbow),
               ghost mode, air walk, rocket jump, hold-C zoom, x-ray,
               ctrl+click delete with undo
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer

--==================================================
-- CONFIG
--==================================================

local CONFIG = {
    UseHotkeys = true,
    Notifications = true,
    Speedometer = true,
    Crosshair = false,
    CoordsHud = false,

    -- Set to true and add your UserId(s) so only you / your testers get this menu.
    -- (Otherwise EVERY player in your game gets it.)
    RestrictToUserIds = false,
    AllowedUserIds = {},
}

if CONFIG.RestrictToUserIds and not table.find(CONFIG.AllowedUserIds, player.UserId) then
    return
end

local KEYS = {
    Menu = Enum.KeyCode.RightShift,
    Fly = Enum.KeyCode.F,
    Noclip = Enum.KeyCode.N,
    Dash = Enum.KeyCode.Q,
    Teleport = Enum.KeyCode.T,
    SetCheckpoint = Enum.KeyCode.Z,
    ReturnCheckpoint = Enum.KeyCode.X,
    Freecam = Enum.KeyCode.G,
}

local KEY_ORDER = { "Menu", "Fly", "Noclip", "Dash", "Teleport", "SetCheckpoint", "ReturnCheckpoint", "Freecam" }
local KEY_LABELS = {
    Menu = "Show / Hide Menu",
    Fly = "Toggle Fly",
    Noclip = "Toggle Noclip",
    Dash = "Dash",
    Teleport = "Teleport to Cursor",
    SetCheckpoint = "Set Checkpoint",
    ReturnCheckpoint = "Return to Checkpoint",
    Freecam = "Toggle Freecam",
}

local rebinding = nil

local playerGui = player:WaitForChild("PlayerGui")

local C = {
    bg = Color3.fromRGB(9, 9, 10),
    panel = Color3.fromRGB(16, 16, 18),
    card = Color3.fromRGB(25, 25, 28),
    cardHover = Color3.fromRGB(33, 33, 37),
    hover = Color3.fromRGB(43, 43, 47),
    white = Color3.fromRGB(248, 248, 250),
    muted = Color3.fromRGB(153, 153, 160),
    border = Color3.fromRGB(55, 55, 60),
    black = Color3.fromRGB(12, 12, 13),
    accent = Color3.fromRGB(235, 235, 240),
}

local ACCENTS = {
    { "Mono", Color3.fromRGB(235, 235, 240) },
    { "Ice", Color3.fromRGB(140, 190, 255) },
    { "Ember", Color3.fromRGB(255, 165, 90) },
    { "Mint", Color3.fromRGB(110, 225, 170) },
}

local SETTINGS = {
    WalkSpeed = 16,
    SprintMultiplier = 1.75,
    JumpPower = 50,
    FlySpeed = 55,
    AirControl = 0.16,
    WallHopPush = 24,
    WallRunSpeed = 24,
    WallRunMax = 1.15,
    DashPower = 80,
    DashCooldown = 1.2,
    GlideFall = 14,
    SpinSpeed = 360,
    FreecamSpeed = 50,
    Time = Lighting.ClockTime,
}

-- Only override the game's own values after the user actually touches a control.
local touched = { Speed = false, Jump = false }

-- Original world values (restored on reset / unload).
local orig = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Gravity = workspace.Gravity,
    MaxZoom = player.CameraMaxZoomDistance,
    FOV = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70,
}

--==================================================
-- CONNECTION MANAGEMENT
--==================================================

local connections = {}

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

for _, oldName in ipairs({ "NexusV2", "NexusV3", "NexusV4", "NexusV5" }) do
    local oldGui = playerGui:FindFirstChild(oldName)
    if oldGui then oldGui:Destroy() end
end

local gui = Instance.new("ScreenGui")
gui.Name = "NexusV5"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = playerGui

--==================================================
-- UI HELPERS
--==================================================

-- Auto-assigns increasing LayoutOrder so list layouts keep creation order.
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do
        obj[k] = v
    end
    if parent then
        if obj:IsA("GuiObject") then
            local n = (parent:GetAttribute("_n") or 0) + 1
            parent:SetAttribute("_n", n)
            obj.LayoutOrder = n
        end
        obj.Parent = parent
    end
    return obj
end

local function round(obj, px)
    make("UICorner", { CornerRadius = UDim.new(0, px or 8) }, obj)
end

local function outline(obj)
    return make("UIStroke", {
        Color = C.border,
        Thickness = 1,
        Transparency = 0.15,
    }, obj)
end

local function text(parent, value, size, color, font)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = value,
        TextColor3 = color or C.white,
        TextSize = size or 13,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, 24),
    }, parent)
end

local function tween(obj, props, duration, style, direction)
    TweenService:Create(
        obj,
        TweenInfo.new(duration or 0.15, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
        props
    ):Play()
end

-- Accent color registry: components register a refresh function.
local accentFns = {}

local function onAccent(fn)
    table.insert(accentFns, fn)
    fn()
end

local function setAccent(color)
    C.accent = color
    for _, fn in ipairs(accentFns) do
        fn()
    end
end

-- Toast notifications -----------------------------------------------------

local toastHolder = make("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -16, 1, -16),
    Size = UDim2.fromOffset(250, 320),
    BackgroundTransparency = 1,
}, gui)

make("UIListLayout", {
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, toastHolder)

local function notify(message)
    if not CONFIG.Notifications then return end

    local existing = {}
    for _, child in ipairs(toastHolder:GetChildren()) do
        if child:IsA("CanvasGroup") then
            table.insert(existing, child)
        end
    end
    if #existing >= 4 then existing[1]:Destroy() end

    local toast = make("CanvasGroup", {
        Size = UDim2.fromOffset(230, 34),
        BackgroundColor3 = C.panel,
        BorderSizePixel = 0,
        GroupTransparency = 1,
    }, toastHolder)
    round(toast, 8)
    outline(toast)

    make("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, toast)

    local label = text(toast, message, 12, C.white, Enum.Font.GothamMedium)
    label.Position = UDim2.fromOffset(14, 0)
    label.Size = UDim2.new(1, -20, 1, 0)

    tween(toast, { GroupTransparency = 0 }, 0.15)

    task.delay(2.2, function()
        if toast.Parent then
            tween(toast, { GroupTransparency = 1 }, 0.25)
            task.delay(0.3, function()
                if toast.Parent then toast:Destroy() end
            end)
        end
    end)
end

local function newButton(parent, caption, height)
    local b = make("TextButton", {
        Size = UDim2.new(1, 0, 0, height or 38),
        BackgroundColor3 = C.card,
        Text = caption,
        TextColor3 = C.white,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
    }, parent)

    round(b, 8)
    outline(b)

    b.MouseEnter:Connect(function()
        tween(b, { BackgroundColor3 = C.hover })
    end)
    b.MouseLeave:Connect(function()
        tween(b, { BackgroundColor3 = C.card })
    end)

    return b
end

--==================================================
-- LOADING SCREEN
--==================================================

local loader = {}

do
    local TIPS = {
        "Press Q to dash once Dash is enabled.",
        "Set a checkpoint with Z and return to it with X.",
        "Click any slider value to type an exact number.",
        "Every keybind can be changed in Settings.",
        "Pair Noclip with Fly so you don't fall through the floor.",
        "Presets in Settings give you one-click setups.",
        "Hold Space near a wall in the air to wall-hop.",
        "The minimize button turns the menu into a small pill.",
        "Freecam: right-mouse drag to look, Shift to move faster.",
        "Save waypoints in the Tools tab and jump back any time.",
        "Anti-AFK stops the idle kick while you tab away.",
    }

    local blur = Instance.new("BlurEffect")
    blur.Name = "NexusLoadBlur"
    blur.Size = 0
    blur.Parent = Lighting
    loader.blur = blur
    tween(blur, { Size = 18 }, 0.4)

    local screen = make("CanvasGroup", {
        Name = "Loader",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.bg,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        ZIndex = 100,
    }, gui)

    make("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(9, 9, 10), Color3.fromRGB(24, 24, 28)),
    }, screen)

    local stack = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(320, 260),
        BackgroundTransparency = 1,
    }, screen)

    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, stack)

    local logo = make("Frame", {
        Size = UDim2.fromOffset(64, 64),
        BackgroundColor3 = C.white,
        BorderSizePixel = 0,
    }, stack)
    round(logo, 16)

    local logoScale = make("UIScale", {}, logo)
    TweenService:Create(
        logoScale,
        TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Scale = 1.1 }
    ):Play()

    local logoText = text(logo, "N", 32, C.black, Enum.Font.GothamBold)
    logoText.Size = UDim2.fromScale(1, 1)
    logoText.TextXAlignment = Enum.TextXAlignment.Center

    local spacer = make("Frame", { Size = UDim2.fromOffset(1, 6), BackgroundTransparency = 1 }, stack)

    local title = text(stack, "NEXUS", 26, C.white, Enum.Font.GothamBold)
    title.Size = UDim2.new(1, 0, 0, 32)
    title.TextXAlignment = Enum.TextXAlignment.Center

    local subtitle = text(stack, "MOVEMENT HUB  /  V5.0", 10, C.muted)
    subtitle.Size = UDim2.new(1, 0, 0, 16)
    subtitle.TextXAlignment = Enum.TextXAlignment.Center

    local welcome = text(stack, "Welcome, " .. player.DisplayName, 12, C.muted)
    welcome.Size = UDim2.new(1, 0, 0, 20)
    welcome.TextXAlignment = Enum.TextXAlignment.Center

    local barBack = make("Frame", {
        Size = UDim2.fromOffset(280, 4),
        BackgroundColor3 = C.border,
        BorderSizePixel = 0,
    }, stack)
    round(barBack, 4)

    local fill = make("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = C.white,
        BorderSizePixel = 0,
    }, barBack)
    round(fill, 4)

    local infoRow = make("Frame", {
        Size = UDim2.fromOffset(280, 16),
        BackgroundTransparency = 1,
    }, stack)

    local status = text(infoRow, "Starting up", 10, C.muted)
    status.Size = UDim2.new(0.75, 0, 1, 0)

    local percent = text(infoRow, "0%", 10, C.muted, Enum.Font.GothamMedium)
    percent.AnchorPoint = Vector2.new(1, 0)
    percent.Position = UDim2.fromScale(1, 0)
    percent.Size = UDim2.new(0.25, 0, 1, 0)
    percent.TextXAlignment = Enum.TextXAlignment.Right

    local tip = text(screen, "Tip: " .. TIPS[math.random(1, #TIPS)], 11, C.muted)
    tip.AnchorPoint = Vector2.new(0.5, 1)
    tip.Position = UDim2.new(0.5, 0, 1, -36)
    tip.Size = UDim2.fromOffset(520, 20)
    tip.TextXAlignment = Enum.TextXAlignment.Center

    function loader.set(p, message)
        tween(fill, { Size = UDim2.fromScale(math.clamp(p, 0, 1), 1) }, 0.25)
        status.Text = message
        percent.Text = math.floor(p * 100 + 0.5) .. "%"
    end

    -- Updates the bar, then yields briefly so the screen actually renders each stage.
    function loader.step(p, message)
        loader.set(p, message)
        task.wait(0.14)
    end

    function loader.finish()
        loader.set(1, "Ready")
        task.wait(0.35)
        tween(screen, { GroupTransparency = 1 }, 0.45)
        tween(blur, { Size = 0 }, 0.45)
        task.wait(0.5)
        screen:Destroy()
        blur:Destroy()
        loader.blur = nil
    end

    loader.set(0.05, "Starting up")
end

--==================================================
-- WINDOW
--==================================================

local main = make("CanvasGroup", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(840, 540),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    GroupTransparency = 1,
}, gui)

round(main, 12)
outline(main)

local uiScale = make("UIScale", {}, main)

-- Open / close animation + window opacity share GroupTransparency.
local openVal = Instance.new("NumberValue")
openVal.Value = 0
local baseTransparency = 0
local fitScale = 1
local menuOpen = true

local function applyOpen()
    local v = openVal.Value
    main.GroupTransparency = baseTransparency + (1 - v) * (1 - baseTransparency)
    uiScale.Scale = fitScale * (0.92 + 0.08 * v)
end

openVal.Changed:Connect(applyOpen)

local function updateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    fitScale = math.clamp(math.min(vp.X / 900, vp.Y / 610), 0.5, 1)
    applyOpen()
end

updateScale()
do
    local cam = workspace.CurrentCamera
    if cam then
        connect(cam:GetPropertyChangedSignal("ViewportSize"), updateScale)
    end
end

-- Floating pill shown while the menu is hidden (works on touch, too).
local pill = make("TextButton", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 14, 1, -14),
    Size = UDim2.fromOffset(42, 42),
    BackgroundColor3 = C.panel,
    Text = "N",
    TextColor3 = C.white,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = false,
    Visible = false,
}, gui)
round(pill, 21)
outline(pill)

local function setMenuOpen(open)
    menuOpen = open

    if open then
        main.Visible = true
        pill.Visible = false
    end

    local tw = TweenService:Create(
        openVal,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Value = open and 1 or 0 }
    )
    tw:Play()

    if not open then
        tw.Completed:Connect(function()
            if not menuOpen then
                main.Visible = false
                pill.Visible = true
            end
        end)
    end
end

pill.MouseButton1Click:Connect(function()
    setMenuOpen(true)
end)

local top = make("Frame", {
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, main)

make("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = C.border,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
}, top)

local brand = make("Frame", {
    Position = UDim2.fromOffset(16, 13),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = C.accent,
}, top)
round(brand, 8)
onAccent(function() brand.BackgroundColor3 = C.accent end)

local logo = text(brand, "N", 18, C.black, Enum.Font.GothamBold)
logo.Size = UDim2.fromScale(1, 1)
logo.TextXAlignment = Enum.TextXAlignment.Center

local title = text(top, "NEXUS", 16, C.white, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(58, 8)
title.Size = UDim2.fromOffset(120, 22)

local subtitle = text(top, "MOVEMENT HUB  /  V5.0", 9, C.muted)
subtitle.Position = UDim2.fromOffset(59, 29)
subtitle.Size = UDim2.fromOffset(180, 16)

local status = text(top, "● READY", 10, C.muted)
status.TextXAlignment = Enum.TextXAlignment.Right
status.Position = UDim2.new(1, -185, 0, 17)
status.Size = UDim2.fromOffset(90, 24)

local minimize = newButton(top, "–", 30)
minimize.Size = UDim2.fromOffset(30, 30)
minimize.Position = UDim2.new(1, -78, 0, 14)
minimize.TextSize = 16
minimize.MouseButton1Click:Connect(function()
    setMenuOpen(false)
end)

local close = newButton(top, "×", 30)
close.Size = UDim2.fromOffset(30, 30)
close.Position = UDim2.new(1, -42, 0, 14)
close.TextSize = 18

-- Dragging (mouse + touch)
do
    local dragging = false
    local dragStart, startPosition

    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
        end
    end)

    connect(UIS.InputChanged, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = (input.Position - dragStart) / uiScale.Scale
            main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

loader.step(0.2, "Building window")

--==================================================
-- SIDEBAR / PAGES
--==================================================

local sidebar = make("Frame", {
    Position = UDim2.fromOffset(0, 58),
    Size = UDim2.new(0, 185, 1, -58),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
}, main)

make("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.fromScale(1, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = C.border,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
}, sidebar)

local content = make("Frame", {
    Position = UDim2.fromOffset(185, 58),
    Size = UDim2.new(1, -185, 1, -58),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, main)

local sideHeading = text(sidebar, "NAVIGATION", 10, C.muted, Enum.Font.GothamBold)
sideHeading.Position = UDim2.fromOffset(17, 17)

local nav = make("Frame", {
    Position = UDim2.fromOffset(10, 47),
    Size = UDim2.new(1, -20, 0, 300),
    BackgroundTransparency = 1,
}, sidebar)

make("UIListLayout", {
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, nav)

local pages = {}
local navButtons = {}
local navIndicators = {}
local currentPage = "Overview"

local function createPage(name)
    local page = make("ScrollingFrame", {
        Name = name,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.muted,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Visible = false,
    }, content)

    make("UIPadding", {
        PaddingTop = UDim.new(0, 22),
        PaddingLeft = UDim.new(0, 22),
        PaddingRight = UDim.new(0, 22),
        PaddingBottom = UDim.new(0, 20),
    }, page)

    make("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)

    pages[name] = page
    return page
end

local tabs = {
    { "Overview", "01" },
    { "Movement", "02" },
    { "Abilities", "03" },
    { "World", "04" },
    { "Tools", "05" },
    { "Extras", "06" },
    { "Settings", "07" },
}

local function switchPage(name)
    currentPage = name

    for pageName, page in pairs(pages) do
        local show = pageName == name
        if show and not page.Visible then
            page.Position = UDim2.fromOffset(0, 14)
            page.Visible = true
            tween(page, { Position = UDim2.fromOffset(0, 0) }, 0.2)
        elseif not show then
            page.Visible = false
        end
    end

    for tabName, b in pairs(navButtons) do
        local selected = tabName == name
        b.BackgroundColor3 = selected and C.hover or C.panel
        b.TextColor3 = selected and C.white or C.muted
        navIndicators[tabName].Visible = selected
    end
end

for _, item in ipairs(tabs) do
    local name, number = item[1], item[2]

    local b = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 39),
        BackgroundColor3 = C.panel,
        Text = number .. "     " .. name,
        TextColor3 = C.muted,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    }, nav)
    round(b, 8)
    outline(b)
    make("UIPadding", { PaddingLeft = UDim.new(0, 14) }, b)

    local ind = make("Frame", {
        Position = UDim2.new(0, -11, 0.5, -9),
        Size = UDim2.fromOffset(3, 18),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
        Visible = false,
    }, b)
    round(ind, 2)
    onAccent(function() ind.BackgroundColor3 = C.accent end)

    navButtons[name] = b
    navIndicators[name] = ind

    b.MouseEnter:Connect(function()
        if currentPage ~= name then
            tween(b, { BackgroundColor3 = C.card })
        end
    end)
    b.MouseLeave:Connect(function()
        tween(b, { BackgroundColor3 = currentPage == name and C.hover or C.panel })
    end)
    b.MouseButton1Click:Connect(function()
        switchPage(name)
    end)
end

local sideFooter = text(sidebar, "", 9, C.muted)
sideFooter.Position = UDim2.new(0, 15, 1, -30)
sideFooter.Size = UDim2.new(1, -20, 0, 18)

local function updateFooter()
    sideFooter.Text = "NEXUS / BUILD 007  ·  " .. KEYS.Menu.Name .. " hides"
end
updateFooter()

--==================================================
-- HUD ELEMENTS (speedometer + crosshair)
--==================================================

local hud = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -120),
    Size = UDim2.fromOffset(210, 54),
    BackgroundColor3 = C.bg,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Visible = CONFIG.Speedometer,
}, gui)
round(hud, 10)
outline(hud)

local hudValue = text(hud, "0", 22, C.white, Enum.Font.GothamBold)
hudValue.Position = UDim2.fromOffset(14, 5)
hudValue.Size = UDim2.fromOffset(90, 28)

local hudUnit = text(hud, "STUDS / SEC", 9, C.muted)
hudUnit.Position = UDim2.fromOffset(14, 32)
hudUnit.Size = UDim2.fromOffset(90, 14)

local hudDash = text(hud, "", 9, C.muted, Enum.Font.GothamMedium)
hudDash.TextXAlignment = Enum.TextXAlignment.Right
hudDash.Position = UDim2.fromOffset(104, 8)
hudDash.Size = UDim2.fromOffset(92, 16)

local hudBar = make("Frame", {
    Position = UDim2.fromOffset(104, 34),
    Size = UDim2.fromOffset(92, 4),
    BackgroundColor3 = C.border,
    BorderSizePixel = 0,
}, hud)
round(hudBar, 4)

local hudFill = make("Frame", {
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
}, hudBar)
round(hudFill, 4)
onAccent(function() hudFill.BackgroundColor3 = C.accent end)

local crosshair = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = C.white,
    BorderSizePixel = 0,
    Visible = CONFIG.Crosshair,
}, gui)
round(crosshair, 3)
make("UIStroke", { Color = C.black, Thickness = 1 }, crosshair)

--==================================================
-- REUSABLE UI COMPONENTS
--==================================================

local function section(parent, heading)
    local wrap = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, parent)

    make("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, wrap)

    local h = text(wrap, heading, 11, C.muted, Enum.Font.GothamBold)
    h.Size = UDim2.new(1, 0, 0, 22)

    return wrap
end

local function pageTitle(parent, heading, subheading)
    local h = text(parent, heading, 21, C.white, Enum.Font.GothamBold)
    h.Size = UDim2.new(1, 0, 0, 30)

    local sub = text(parent, subheading, 11, C.muted)
    sub.Size = UDim2.new(1, 0, 0, 20)
end

-- Returns a function that updates the visual only (does not fire the callback).
local function toggle(parent, name, initial, callback, desc)
    local height = desc and 54 or 43

    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, parent)
    round(row, 8)
    outline(row)

    row.MouseEnter:Connect(function() tween(row, { BackgroundColor3 = C.cardHover }) end)
    row.MouseLeave:Connect(function() tween(row, { BackgroundColor3 = C.card }) end)

    local caption = text(row, name, 12, C.white)
    caption.Position = UDim2.fromOffset(12, desc and 7 or 0)
    caption.Size = UDim2.new(1, -80, 0, desc and 20 or height)

    if desc then
        local d = text(row, desc, 10, C.muted)
        d.Position = UDim2.fromOffset(12, 28)
        d.Size = UDim2.new(1, -80, 0, 18)
    end

    local active = initial == true

    local track = make("TextButton", {
        Position = UDim2.new(1, -53, 0.5, -9),
        Size = UDim2.fromOffset(40, 18),
        BackgroundColor3 = active and C.accent or C.border,
        Text = "",
        AutoButtonColor = false,
    }, row)
    round(track, 10)

    local knob = make("Frame", {
        Position = UDim2.new(0, active and 23 or 3, 0.5, -6),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = active and C.black or C.white,
        BorderSizePixel = 0,
    }, track)
    round(knob, 8)

    local function apply(value)
        active = value == true
        track.BackgroundColor3 = active and C.accent or C.border
        knob.BackgroundColor3 = active and C.black or C.white
        tween(knob, { Position = UDim2.new(0, active and 23 or 3, 0.5, -6) })
    end

    onAccent(function()
        if active then track.BackgroundColor3 = C.accent end
    end)

    track.MouseButton1Click:Connect(function()
        apply(not active)
        if callback then callback(active) end
    end)

    return apply
end

-- Returns setValue(value, silent). The value label is editable: click it and type a number.
local function slider(parent, name, min, max, initial, step, callback)
    step = step or 1

    local function snap(v)
        v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
        return tonumber(string.format("%.3f", v))
    end

    local current = snap(initial)

    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 65),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, parent)
    round(row, 8)
    outline(row)

    row.MouseEnter:Connect(function() tween(row, { BackgroundColor3 = C.cardHover }) end)
    row.MouseLeave:Connect(function() tween(row, { BackgroundColor3 = C.card }) end)

    local caption = text(row, name, 12, C.white)
    caption.Position = UDim2.fromOffset(12, 5)

    local valueBox = make("TextBox", {
        BackgroundTransparency = 1,
        Text = tostring(current),
        TextColor3 = C.muted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
        ClearTextOnFocus = false,
        Position = UDim2.new(1, -72, 0, 5),
        Size = UDim2.fromOffset(60, 22),
    }, row)

    local bar = make("Frame", {
        Position = UDim2.new(0, 12, 0, 43),
        Size = UDim2.new(1, -24, 0, 4),
        BackgroundColor3 = C.border,
        BorderSizePixel = 0,
    }, row)
    round(bar, 4)

    local function ratioFor(v)
        return math.clamp((v - min) / (max - min), 0, 1)
    end

    local fill = make("Frame", {
        Size = UDim2.new(ratioFor(current), 0, 1, 0),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, bar)
    round(fill, 4)
    onAccent(function() fill.BackgroundColor3 = C.accent end)

    local knob = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(ratioFor(current), 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = C.white,
        BorderSizePixel = 0,
    }, bar)
    round(knob, 10)

    -- Larger invisible hit area so the 4px bar is easy to grab.
    local hit = make("Frame", {
        Position = UDim2.new(0, 6, 0, 30),
        Size = UDim2.new(1, -12, 0, 30),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, row)

    local function setValue(value, silent)
        value = snap(value)
        local changed = value ~= current
        current = value

        local r = ratioFor(value)
        fill.Size = UDim2.new(r, 0, 1, 0)
        knob.Position = UDim2.new(r, 0, 0.5, 0)
        valueBox.Text = tostring(value)

        if callback and changed and not silent then
            callback(value)
        end
    end

    local function setFromX(x)
        local r = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        setValue(min + r * (max - min))
    end

    valueBox.Focused:Connect(function() valueBox.TextColor3 = C.white end)
    valueBox.FocusLost:Connect(function()
        valueBox.TextColor3 = C.muted
        local n = tonumber(valueBox.Text)
        if n then
            setValue(n)
        else
            valueBox.Text = tostring(current)
        end
    end)

    local held = false
    local scroller = row:FindFirstAncestorOfClass("ScrollingFrame")

    local function release()
        held = false
        if scroller then scroller.ScrollingEnabled = true end
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            held = true
            if scroller then scroller.ScrollingEnabled = false end
            setFromX(input.Position.X)
        end
    end)

    connect(UIS.InputChanged, function(input)
        if held and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            setFromX(input.Position.X)
        end
    end)

    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            release()
        end
    end)

    return setValue
end

-- Row of equally sized buttons. defs = { {"Label", callback}, ... }
local function buttonRow(parent, defs)
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundTransparency = 1,
    }, parent)

    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)

    local n = #defs
    for _, def in ipairs(defs) do
        local b = newButton(row, def[1], 38)
        b.Size = UDim2.new(1 / n, -(8 * (n - 1)) / n, 1, 0)
        b.MouseButton1Click:Connect(def[2])
    end

    return row
end

loader.step(0.4, "Loading components")

--==================================================
-- CHARACTER / MOVEMENT STATE
--==================================================

local character, humanoid, root
local originals = {}

local FEATURES = {
    { "Sprint", "Sprint" },
    { "DoubleJump", "Double Jump" },
    { "InfiniteJump", "Infinite Jump" },
    { "AirControl", "Air Control" },
    { "AutoJump", "Bunny Hop" },
    { "Glide", "Glide" },
    { "Dash", "Dash" },
    { "AutoWallHop", "Wall-Hop" },
    { "WallRun", "Wall Run" },
    { "Fly", "Fly" },
    { "Noclip", "Noclip" },
    { "Teleport", "Cursor TP" },
    { "VoidRescue", "Void Rescue" },
    { "Fullbright", "Fullbright" },
    { "NoFog", "No Fog" },
    { "TimeLock", "Freeze Time" },
    { "Freecam", "Freecam" },
    { "Spin", "Spin" },
    { "AntiAfk", "Anti-AFK" },
    { "FpsBoost", "FPS Boost" },
}

local state, LABELS = {}, {}
for _, f in ipairs(FEATURES) do
    state[f[1]] = false
    LABELS[f[1]] = f[2]
end

local jumpCount = 0
local lastJump = 0
local lastWallHop = 0
local wallRunTime = 0

local dashUntil, dashDir, dashReadyAt = 0, nil, 0
local kicking = false

local lastSafeCF, lastSafeT = nil, 0
local lastRescue = 0
local checkpointCF, checkpointPart

local flyObjects = {}
local flyVelocity
local flyAlign

local savedCollisions = {}
local charParts = {}
local charConns = {}

local smoothSpeed = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true

local function hasChar()
    return humanoid ~= nil and humanoid.Parent ~= nil
        and root ~= nil and root.Parent ~= nil
        and humanoid.Health > 0
end

local function horizontal(v)
    return Vector3.new(v.X, 0, v.Z)
end

local function airborne()
    return humanoid.FloorMaterial == Enum.Material.Air
end

local function typing()
    return UIS:GetFocusedTextBox() ~= nil
end

local function keyDown(key)
    return not typing() and UIS:IsKeyDown(key)
end

local function readJumpPower(h)
    if h.UseJumpPower then
        return h.JumpPower
    end
    return math.sqrt(2 * workspace.Gravity * h.JumpHeight)
end

--==================================================
-- FEATURE REGISTRY (keeps duplicate toggles in sync)
--==================================================

local uiRegistry = {}
local handlers = {}
local suppressNotify = false

local function setFeature(key, value)
    value = value == true
    local prev = state[key]

    local handler = handlers[key]
    if handler then
        local result = handler(value)
        if result ~= nil then value = result end
    end

    state[key] = value

    for _, setVisual in ipairs(uiRegistry[key] or {}) do
        setVisual(value)
    end

    if value ~= prev and not suppressNotify then
        notify(LABELS[key] .. (value and "  ON" or "  OFF"))
    end
end

local function bindToggle(parent, label, key, desc)
    local setVisual = toggle(parent, label, state[key], function(v)
        setFeature(key, v)
    end, desc)
    uiRegistry[key] = uiRegistry[key] or {}
    table.insert(uiRegistry[key], setVisual)
end

--==================================================
-- HUMANOID VALUE HELPERS
--==================================================

local function baseWalkSpeed()
    if touched.Speed then
        return SETTINGS.WalkSpeed
    end
    return originals.WalkSpeed or 16
end

local function desiredWalkSpeed()
    local base = baseWalkSpeed()
    return state.Sprint and base * SETTINGS.SprintMultiplier or base
end

local function currentJumpPower()
    return touched.Jump and SETTINGS.JumpPower or (originals.JumpPowerValue or 50)
end

local function restoreHumanoid()
    if not (humanoid and humanoid.Parent) or not originals.WalkSpeed then return end
    humanoid.WalkSpeed = originals.WalkSpeed
    humanoid.UseJumpPower = originals.UseJumpPower
    if originals.UseJumpPower then
        humanoid.JumpPower = originals.JumpPower
    else
        humanoid.JumpHeight = originals.JumpHeight
    end
end

--==================================================
-- FLY
--==================================================

local function stopFly()
    local wasFlying = next(flyObjects) ~= nil

    for _, obj in ipairs(flyObjects) do
        obj:Destroy()
    end
    table.clear(flyObjects)
    flyVelocity, flyAlign = nil, nil

    if wasFlying and humanoid and humanoid.Parent then
        humanoid.AutoRotate = true
        if humanoid.Health > 0 then
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end
end

local function startFly()
    if not hasChar() then return false end
    if next(flyObjects) then return true end

    local attachment = Instance.new("Attachment")
    attachment.Name = "NexusFlyAttachment"
    attachment.Parent = root

    flyVelocity = Instance.new("LinearVelocity")
    flyVelocity.Name = "NexusFlyVelocity"
    flyVelocity.Attachment0 = attachment
    flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    flyVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    flyVelocity.MaxForce = math.huge
    flyVelocity.VectorVelocity = Vector3.zero
    flyVelocity.Parent = root

    flyAlign = Instance.new("AlignOrientation")
    flyAlign.Name = "NexusFlyAlign"
    flyAlign.Attachment0 = attachment
    flyAlign.Mode = Enum.OrientationAlignmentMode.OneAttachment
    flyAlign.Responsiveness = 20
    flyAlign.MaxTorque = math.huge
    flyAlign.CFrame = root.CFrame
    flyAlign.Parent = root

    flyObjects = { attachment, flyVelocity, flyAlign }

    humanoid.AutoRotate = false
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    return true
end

handlers.Fly = function(value)
    if value then
        return startFly()
    end
    stopFly()
    return false
end

local function updateFly()
    local camera = workspace.CurrentCamera
    if not (camera and flyVelocity and flyAlign) then return end

    local camCF = camera.CFrame
    local look, right = camCF.LookVector, camCF.RightVector
    local flatLook = horizontal(look)
    local flatRight = horizontal(right)

    local dir = Vector3.zero
    local move = humanoid.MoveDirection

    if move.Magnitude > 0 then
        local forwardAmount = flatLook.Magnitude > 0.01 and move:Dot(flatLook.Unit) or 0
        local rightAmount = flatRight.Magnitude > 0.01 and move:Dot(flatRight.Unit) or 0
        dir = look * forwardAmount + right * rightAmount
    end

    local vertical = (keyDown(Enum.KeyCode.Space) and 1 or 0)
        - (keyDown(Enum.KeyCode.LeftControl) and 1 or 0)

    local velocity = (dir + Vector3.new(0, vertical, 0)) * SETTINGS.FlySpeed
    if velocity.Magnitude > SETTINGS.FlySpeed then
        velocity = velocity.Unit * SETTINGS.FlySpeed
    end
    flyVelocity.VectorVelocity = velocity

    if flatLook.Magnitude > 0.01 then
        flyAlign.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
    end
end

--==================================================
-- NOCLIP
--==================================================

local function restoreCollisions()
    for part in pairs(savedCollisions) do
        if part.Parent then
            part.CanCollide = true
        end
    end
    table.clear(savedCollisions)
end

handlers.Noclip = function(value)
    if not value then
        restoreCollisions()
    end
end

local function clearCharConns()
    for _, c in ipairs(charConns) do
        c:Disconnect()
    end
    table.clear(charConns)
    table.clear(charParts)
end

local function trackParts(char)
    clearCharConns()

    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then charParts[d] = true end
    end

    table.insert(charConns, char.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") then charParts[d] = true end
    end))

    table.insert(charConns, char.DescendantRemoving:Connect(function(d)
        charParts[d] = nil
        savedCollisions[d] = nil
    end))
end

-- Stepped runs before physics, which is what noclip needs.
connect(RunService.Stepped, function()
    if not state.Noclip then return end
    for part in pairs(charParts) do
        if part.CanCollide then
            savedCollisions[part] = true
            part.CanCollide = false
        end
    end
end)

--==================================================
-- WORLD HANDLERS (fullbright / no fog)
--==================================================

local fullbrightSaved
local fullbrightColor = Color3.fromRGB(178, 178, 178)

handlers.Fullbright = function(value)
    if value then
        if not fullbrightSaved then
            fullbrightSaved = {
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                GlobalShadows = Lighting.GlobalShadows,
            }
        end
        Lighting.Ambient = fullbrightColor
        Lighting.OutdoorAmbient = fullbrightColor
        Lighting.GlobalShadows = false
    elseif fullbrightSaved then
        Lighting.Ambient = fullbrightSaved.Ambient
        Lighting.OutdoorAmbient = fullbrightSaved.OutdoorAmbient
        Lighting.GlobalShadows = fullbrightSaved.GlobalShadows
        fullbrightSaved = nil
    end
end

local fogSaved

handlers.NoFog = function(value)
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

    if value then
        if not fogSaved then
            fogSaved = {
                FogEnd = Lighting.FogEnd,
                FogStart = Lighting.FogStart,
                Density = atmosphere and atmosphere.Density,
                Haze = atmosphere and atmosphere.Haze,
            }
        end
        Lighting.FogEnd = 1e6
        if atmosphere then
            atmosphere.Density = 0
            atmosphere.Haze = 0
        end
    elseif fogSaved then
        Lighting.FogEnd = fogSaved.FogEnd
        Lighting.FogStart = fogSaved.FogStart
        if atmosphere and fogSaved.Density then
            atmosphere.Density = fogSaved.Density
            atmosphere.Haze = fogSaved.Haze
        end
        fogSaved = nil
    end
end

local function enforceWorld()
    if state.Fullbright then
        if Lighting.Ambient ~= fullbrightColor then Lighting.Ambient = fullbrightColor end
        if Lighting.OutdoorAmbient ~= fullbrightColor then Lighting.OutdoorAmbient = fullbrightColor end
        if Lighting.GlobalShadows then Lighting.GlobalShadows = false end
    end

    if state.NoFog then
        if Lighting.FogEnd < 1e5 then Lighting.FogEnd = 1e6 end
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere and (atmosphere.Density ~= 0 or atmosphere.Haze ~= 0) then
            atmosphere.Density = 0
            atmosphere.Haze = 0
        end
    end
end

--==================================================
-- WALL DETECTION
--==================================================

local WALL_DISTANCE = 3

-- Casts in 8 horizontal directions and returns the closest vertical-ish wall hit.
local function findWall()
    local origin = root.Position
    local best

    for i = 0, 7 do
        local angle = math.rad(i * 45)
        local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local result = workspace:Raycast(origin, dir * WALL_DISTANCE, rayParams)

        if result and math.abs(result.Normal.Y) < 0.3 then
            if not best or result.Distance < best.Distance then
                best = result
            end
        end
    end

    return best
end

--==================================================
-- TELEPORT / CHECKPOINT / DASH
--==================================================

local function teleportTo(cf)
    if not hasChar() then return end
    root.AssemblyLinearVelocity = Vector3.zero
    root.CFrame = cf
end

local function teleportToCursor()
    if not (state.Teleport and hasChar()) then return end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local loc = UIS:GetMouseLocation()
    local ray = cam:ViewportPointToRay(loc.X, loc.Y)
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, rayParams)

    if hit then
        local pos = hit.Position + hit.Normal * 1.5 + Vector3.new(0, 3, 0)
        teleportTo(CFrame.new(pos) * (root.CFrame - root.CFrame.Position))
    end
end

local function setCheckpoint()
    if not hasChar() then return end

    checkpointCF = root.CFrame

    if not checkpointPart then
        checkpointPart = Instance.new("Part")
        checkpointPart.Name = "NexusCheckpoint"
        checkpointPart.Anchored = true
        checkpointPart.CanCollide = false
        checkpointPart.CanQuery = false
        checkpointPart.CanTouch = false
        checkpointPart.Material = Enum.Material.Neon
        checkpointPart.Transparency = 0.5
        checkpointPart.Size = Vector3.new(4, 0.2, 4)
        checkpointPart.Parent = workspace
    end

    checkpointPart.Color = C.accent
    checkpointPart.CFrame = CFrame.new(
        root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 - 0.1, 0)
    )

    notify("Checkpoint set")
end

local function returnToCheckpoint()
    if not hasChar() then return end

    if checkpointCF then
        teleportTo(checkpointCF + Vector3.new(0, 1, 0))
        notify("Returned to checkpoint")
    else
        notify("No checkpoint set yet")
    end
end

local function fovKick()
    local cam = workspace.CurrentCamera
    if not cam or kicking then return end

    kicking = true
    local base = cam.FieldOfView

    local up = TweenService:Create(cam, TweenInfo.new(0.08), { FieldOfView = base + 10 })
    up:Play()
    up.Completed:Connect(function()
        local down = TweenService:Create(cam, TweenInfo.new(0.25), { FieldOfView = base })
        down:Play()
        down.Completed:Connect(function() kicking = false end)
    end)
end

local function doDash()
    if not (state.Dash and hasChar()) or state.Fly then return end

    local now = os.clock()
    if now < dashReadyAt then return end

    local dir = horizontal(humanoid.MoveDirection)
    if dir.Magnitude < 0.1 then
        local cam = workspace.CurrentCamera
        dir = cam and horizontal(cam.CFrame.LookVector) or horizontal(root.CFrame.LookVector)
    end
    if dir.Magnitude < 0.01 then return end

    dashDir = dir.Unit
    dashUntil = now + 0.16
    dashReadyAt = now + SETTINGS.DashCooldown

    local vel = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(
        dashDir.X * SETTINGS.DashPower, vel.Y, dashDir.Z * SETTINGS.DashPower
    )
    fovKick()
end

--==================================================
-- JUMP INPUT
--==================================================

connect(UIS.JumpRequest, function()
    if not hasChar() or state.Fly then return end

    if not airborne() then
        jumpCount = 0
        return
    end

    local now = os.clock()
    if now - lastJump < 0.18 then return end

    if state.InfiniteJump or (state.DoubleJump and jumpCount < 1) then
        if not state.InfiniteJump then
            jumpCount += 1
        end
        lastJump = now

        local vel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(vel.X, math.max(currentJumpPower(), 45), vel.Z)
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

--==================================================
-- MOVEMENT HEARTBEAT
--==================================================

connect(RunService.Heartbeat, function(dt)
    -- World locks run even without a character.
    if state.TimeLock and Lighting.ClockTime ~= SETTINGS.Time then
        Lighting.ClockTime = SETTINGS.Time
    end

    if not hasChar() then return end

    local air = airborne()
    local now = os.clock()

    if not air then
        jumpCount = 0
        wallRunTime = 0

        if not state.Fly and not state.Noclip and now - lastSafeT > 0.5 then
            lastSafeT = now
            lastSafeCF = root.CFrame
        end
    end

    -- Void rescue.
    if state.VoidRescue and now - lastRescue > 1
        and root.Position.Y < workspace.FallenPartsDestroyHeight + 80 then
        lastRescue = now
        local cf = checkpointCF or lastSafeCF
        if cf then
            teleportTo(cf + Vector3.new(0, 3, 0))
            notify("Void rescue")
        end
    end

    -- Keep our values applied (games sometimes reset them).
    if touched.Speed then
        local want = desiredWalkSpeed()
        if humanoid.WalkSpeed ~= want then
            humanoid.WalkSpeed = want
        end
    end

    if touched.Jump then
        if not humanoid.UseJumpPower then humanoid.UseJumpPower = true end
        if humanoid.JumpPower ~= SETTINGS.JumpPower then
            humanoid.JumpPower = SETTINGS.JumpPower
        end
    end

    if state.Fly then
        updateFly()
        return
    end

    -- Dash keeps its velocity for a short burst.
    local dashing = now < dashUntil and dashDir ~= nil
    if dashing then
        local vel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(
            dashDir.X * SETTINGS.DashPower, vel.Y, dashDir.Z * SETTINGS.DashPower
        )
    end

    -- Bunny hop: hold Space on the ground to keep jumping.
    if state.AutoJump and not air and keyDown(Enum.KeyCode.Space) then
        humanoid.Jump = true
    end

    if not air then return end

    -- Air control (frame-rate independent smoothing).
    if state.AirControl and not dashing then
        local move = humanoid.MoveDirection
        if move.Magnitude > 0 then
            local vel = root.AssemblyLinearVelocity
            local current = horizontal(vel)
            local target = move.Unit * humanoid.WalkSpeed
            local strength = math.clamp(SETTINGS.AirControl, 0, 1)
            local alpha = 1 - (1 - strength) ^ (dt * 60)
            local adjusted = current:Lerp(target, alpha)
            root.AssemblyLinearVelocity = Vector3.new(adjusted.X, vel.Y, adjusted.Z)
        end
    end

    -- Glide: hold Space while falling to slow the descent and carry momentum.
    if state.Glide and not dashing and keyDown(Enum.KeyCode.Space) then
        local vel = root.AssemblyLinearVelocity
        if vel.Y < -8 then
            local flat = horizontal(vel)
            local move = humanoid.MoveDirection
            if move.Magnitude > 0 then
                local target = move.Unit * math.max(humanoid.WalkSpeed * 1.4, 26)
                local alpha = 1 - (1 - 0.08) ^ (dt * 60)
                flat = flat:Lerp(target, alpha)
            end
            root.AssemblyLinearVelocity = Vector3.new(
                flat.X, math.max(vel.Y, -SETTINGS.GlideFall), flat.Z
            )
        end
    end

    local hopped = false

    -- Assisted wall hop: hold Space near a wall while airborne.
    if state.AutoWallHop and keyDown(Enum.KeyCode.Space) and now - lastWallHop > 0.35 then
        local hit = findWall()
        if hit then
            local normal = horizontal(hit.Normal)
            if normal.Magnitude > 0.01 then
                normal = normal.Unit
                lastWallHop = now
                hopped = true
                wallRunTime = 0

                local vel = root.AssemblyLinearVelocity
                local flat = horizontal(vel)

                -- Cancel velocity pushing into the wall so the hop is consistent.
                local into = flat:Dot(-normal)
                if into > 0 then
                    flat += normal * into
                end

                local push = flat + normal * SETTINGS.WallHopPush
                root.AssemblyLinearVelocity = Vector3.new(
                    push.X, math.max(currentJumpPower() * 0.86, 30), push.Z
                )
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end

    -- Wall run: hold W beside a wall while airborne. Limited per air time.
    if state.WallRun and not hopped
        and keyDown(Enum.KeyCode.W)
        and wallRunTime < SETTINGS.WallRunMax then

        local hit = findWall()
        if hit then
            local normal = horizontal(hit.Normal)
            local camera = workspace.CurrentCamera
            local forward = camera and horizontal(camera.CFrame.LookVector) or Vector3.zero
            if forward.Magnitude < 0.01 then
                forward = horizontal(root.CFrame.LookVector)
            end

            if normal.Magnitude > 0.01 and forward.Magnitude > 0.01 then
                normal = normal.Unit
                forward = forward.Unit

                -- Ignore walls we're facing head-on.
                if math.abs(forward:Dot(normal)) < 0.85 then
                    local along = Vector3.new(-normal.Z, 0, normal.X)
                    if along:Dot(forward) < 0 then
                        along = -along
                    end

                    wallRunTime += dt

                    local vel = root.AssemblyLinearVelocity
                    local speed = math.max(SETTINGS.WallRunSpeed, humanoid.WalkSpeed * 1.2)
                    local v = along * speed - normal * 2 -- slight push keeps us attached
                    root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(vel.Y, -4), v.Z)
                end
            end
        end
    end
end)

--==================================================
-- EXTRA TOOLS ENGINE (freecam, spin, anti-AFK, FPS boost, spectate)
--==================================================

-- Freecam -----------------------------------------------------------------

local freecam = {
    active = false,
    yaw = 0,
    pitch = 0,
    pos = Vector3.zero,
    prevType = nil,
    anchoredRoot = nil,
    prevAnchored = false,
}

handlers.Freecam = function(value)
    local cam = workspace.CurrentCamera

    if value then
        if not cam then return false end
        if freecam.active then return true end

        if state.Fly then setFeature("Fly", false) end

        local rx, ry = cam.CFrame:ToOrientation()
        freecam.pitch, freecam.yaw = rx, ry
        freecam.pos = cam.CFrame.Position
        freecam.prevType = cam.CameraType
        cam.CameraType = Enum.CameraType.Scriptable

        -- Freeze the character so WASD only moves the camera.
        if hasChar() then
            freecam.anchoredRoot = root
            freecam.prevAnchored = root.Anchored
            root.Anchored = true
        end

        freecam.active = true
        return true
    end

    if freecam.active then
        freecam.active = false
        if cam then
            cam.CameraType = freecam.prevType or Enum.CameraType.Custom
        end
        if freecam.anchoredRoot and freecam.anchoredRoot.Parent then
            freecam.anchoredRoot.Anchored = freecam.prevAnchored
        end
        freecam.anchoredRoot = nil
    end
    return false
end

connect(UIS.InputChanged, function(input)
    if not freecam.active then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        freecam.yaw -= math.rad(input.Delta.X * 0.3)
        freecam.pitch = math.clamp(freecam.pitch - math.rad(input.Delta.Y * 0.3), -1.5, 1.5)
    end
end)

connect(RunService.RenderStepped, function(dt)
    if not freecam.active then return end

    local cam = workspace.CurrentCamera
    if not cam then return end

    if cam.CameraType ~= Enum.CameraType.Scriptable then
        cam.CameraType = Enum.CameraType.Scriptable
    end

    local rot = CFrame.fromOrientation(freecam.pitch, freecam.yaw, 0)

    local move = Vector3.zero
    if keyDown(Enum.KeyCode.W) then move += Vector3.new(0, 0, -1) end
    if keyDown(Enum.KeyCode.S) then move += Vector3.new(0, 0, 1) end
    if keyDown(Enum.KeyCode.A) then move += Vector3.new(-1, 0, 0) end
    if keyDown(Enum.KeyCode.D) then move += Vector3.new(1, 0, 0) end

    local dir = move.Magnitude > 0 and rot:VectorToWorldSpace(move.Unit) or Vector3.zero
    local vertical = (keyDown(Enum.KeyCode.Space) and 1 or 0)
        - (keyDown(Enum.KeyCode.LeftControl) and 1 or 0)

    local speed = SETTINGS.FreecamSpeed * (keyDown(Enum.KeyCode.LeftShift) and 3 or 1)
    freecam.pos += (dir + Vector3.new(0, vertical, 0)) * speed * dt

    cam.CFrame = CFrame.new(freecam.pos) * rot
end)

-- Fly and freecam can't run together (freecam anchors the character).
do
    local baseFly = handlers.Fly
    handlers.Fly = function(value)
        if value and state.Freecam then
            setFeature("Freecam", false)
        end
        return baseFly(value)
    end
end

-- Spin --------------------------------------------------------------------

connect(RunService.Heartbeat, function(dt)
    if not state.Spin or state.Fly or state.Freecam or not hasChar() then return end
    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(SETTINGS.SpinSpeed) * dt, 0)
end)

-- Anti-AFK ----------------------------------------------------------------

connect(player.Idled, function()
    if not state.AntiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- FPS boost ---------------------------------------------------------------

local boostSaved

local function isHeavyEffect(d)
    return d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
        or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles")
end

handlers.FpsBoost = function(value)
    if value then
        if boostSaved then return true end

        boostSaved = { effects = {}, post = {} }

        pcall(function()
            boostSaved.quality = settings().Rendering.QualityLevel
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)

        for _, d in ipairs(workspace:GetDescendants()) do
            if isHeavyEffect(d) and d.Enabled then
                boostSaved.effects[d] = true
                d.Enabled = false
            end
        end

        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") and e.Name ~= "NexusLoadBlur" and e.Enabled then
                boostSaved.post[e] = true
                e.Enabled = false
            end
        end

        return true
    end

    if boostSaved then
        for d in pairs(boostSaved.effects) do
            if d.Parent then d.Enabled = true end
        end
        for e in pairs(boostSaved.post) do
            if e.Parent then e.Enabled = true end
        end
        if boostSaved.quality then
            pcall(function()
                settings().Rendering.QualityLevel = boostSaved.quality
            end)
        end
        boostSaved = nil
    end
    return false
end

-- Spectate ----------------------------------------------------------------

local spectating = nil

local function stopSpectate()
    if not spectating then return end
    spectating = nil

    local cam = workspace.CurrentCamera
    if cam and humanoid and humanoid.Parent then
        cam.CameraSubject = humanoid
    end
end

local function spectatePlayer(target)
    local cam = workspace.CurrentCamera
    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    if not (cam and hum) then
        notify(target.DisplayName .. " has no character")
        return
    end

    if state.Freecam then setFeature("Freecam", false) end

    spectating = target
    cam.CameraSubject = hum
    notify("Viewing " .. target.DisplayName)
end

-- Waypoints (5 slots) -----------------------------------------------------

local waypoints = {}

local function saveWaypoint(slot)
    if not hasChar() then return false end
    waypoints[slot] = root.CFrame
    notify("Waypoint " .. slot .. " saved")
    return true
end

local function gotoWaypoint(slot)
    if not hasChar() then return end
    local cf = waypoints[slot]
    if not cf then
        notify("Waypoint " .. slot .. " is empty")
        return
    end
    teleportTo(cf + Vector3.new(0, 1, 0))
    notify("Waypoint " .. slot)
end

loader.step(0.55, "Starting movement engine")

--==================================================
-- CHARACTER LIFECYCLE
--==================================================

local function onCharacterAdded(char)
    setFeature("Fly", false) -- uses the old humanoid reference, safely guarded
    setFeature("Freecam", false)
    spectating = nil
    table.clear(savedCollisions)

    character, humanoid, root = char, nil, nil

    local hum = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    if player.Character ~= char then return end

    humanoid, root = hum, hrp
    rayParams.FilterDescendantsInstances = { char }

    originals = {
        WalkSpeed = hum.WalkSpeed,
        UseJumpPower = hum.UseJumpPower,
        JumpPower = hum.JumpPower,
        JumpHeight = hum.JumpHeight,
        JumpPowerValue = readJumpPower(hum),
    }

    trackParts(char)
    table.insert(charConns, hum.Died:Connect(function()
        setFeature("Fly", false)
    end))

    jumpCount = 0
    wallRunTime = 0
    dashUntil = 0
    lastSafeCF = hrp.CFrame
end

connect(player.CharacterAdded, onCharacterAdded)

--==================================================
-- WORLD RESTORE / CLEANUP
--==================================================

local sliders = {}
local cleaned = false

local function restoreWorldValues()
    handlers.Fullbright(false)
    handlers.NoFog(false)
    handlers.FpsBoost(false)

    Lighting.Brightness = orig.Brightness
    Lighting.ClockTime = orig.ClockTime
    workspace.Gravity = orig.Gravity
    player.CameraMaxZoomDistance = orig.MaxZoom

    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = orig.FOV
    end
end

local function cleanup()
    if cleaned then return end
    cleaned = true

    for _, c in ipairs(connections) do
        c:Disconnect()
    end
    table.clear(connections)

    stopFly()
    handlers.Freecam(false)
    stopSpectate()
    restoreCollisions()
    clearCharConns()
    restoreHumanoid()
    restoreWorldValues()

    if checkpointPart then checkpointPart:Destroy() end
    if loader.blur then loader.blur:Destroy() end
    openVal:Destroy()

    if gui.Parent then gui:Destroy() end
end

gui.Destroying:Connect(cleanup)
close.MouseButton1Click:Connect(cleanup)

loader.step(0.7, "Preparing pages")

--==================================================
-- PAGE: OVERVIEW
--==================================================

local h0 = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
local walkInit = h0 and math.clamp(math.floor(h0.WalkSpeed + 0.5), 8, 100) or 16
local jumpInit = h0 and math.clamp(math.floor(readJumpPower(h0) + 0.5), 20, 150) or 50
SETTINGS.WalkSpeed = walkInit
SETTINGS.JumpPower = jumpInit

local overview = createPage("Overview")
pageTitle(overview, "Overview", "Welcome to your movement control center.")

local statsSection = section(overview, "PLAYER INFORMATION")

local stats = make("Frame", {
    Size = UDim2.new(1, 0, 0, 150),
    BackgroundTransparency = 1,
}, statsSection)

make("UIGridLayout", {
    CellSize = UDim2.new(0.333, -7, 0, 70),
    CellPadding = UDim2.fromOffset(10, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, stats)

local function statCard(parent, heading, value)
    local card = make("Frame", {
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, parent)
    round(card, 8)
    outline(card)

    local h = text(card, heading, 9, C.muted)
    h.Position = UDim2.fromOffset(10, 8)
    h.Size = UDim2.new(1, -20, 0, 18)

    local v = text(card, value, 15, C.white, Enum.Font.GothamBold)
    v.Position = UDim2.fromOffset(10, 30)
    v.Size = UDim2.new(1, -20, 0, 26)

    return v
end

statCard(stats, "PLAYER", player.DisplayName)
local walkStat = statCard(stats, "WALK SPEED", "16")
local speedStat = statCard(stats, "STUDS / SEC", "0")
local fpsStat = statCard(stats, "FPS", "--")
local pingStat = statCard(stats, "PING", "--")
local featureStat = statCard(stats, "ACTIVE FEATURES", "0")

local activeLabel = text(overview, "Active: None", 11, C.muted)
activeLabel.Size = UDim2.new(1, 0, 0, 34)
activeLabel.TextWrapped = true
activeLabel.TextYAlignment = Enum.TextYAlignment.Top

local quick = section(overview, "QUICK TOGGLES")
bindToggle(quick, "Sprint", "Sprint")
bindToggle(quick, "Fly Mode", "Fly")
bindToggle(quick, "Noclip", "Noclip")
bindToggle(quick, "Dash", "Dash")

local overviewNote = text(overview,
    "Tip: your menu key hides this window and the – button minimizes it to a pill.", 10, C.muted)
overviewNote.Size = UDim2.new(1, 0, 0, 24)

--==================================================
-- PAGE: MOVEMENT
--==================================================

local movementPage = createPage("Movement")
pageTitle(movementPage, "Movement", "Configure movement abilities and physics.")

local speedSection = section(movementPage, "MOVEMENT VALUES")

sliders.Walk = slider(speedSection, "Walk Speed", 8, 100, walkInit, 1, function(value)
    SETTINGS.WalkSpeed = value
    touched.Speed = true
end)

sliders.Sprint = slider(speedSection, "Sprint Multiplier", 1, 3, SETTINGS.SprintMultiplier, 0.05, function(value)
    SETTINGS.SprintMultiplier = value
    touched.Speed = true
end)

sliders.Jump = slider(speedSection, "Jump Power", 20, 150, jumpInit, 1, function(value)
    SETTINGS.JumpPower = value
    touched.Jump = true
end)

sliders.Fly = slider(speedSection, "Fly Speed", 10, 120, SETTINGS.FlySpeed, 1, function(value)
    SETTINGS.FlySpeed = value
end)

sliders.Air = slider(speedSection, "Air Control Strength", 0, 100, SETTINGS.AirControl * 100, 1, function(value)
    SETTINGS.AirControl = value / 100
end)

local abilitySection = section(movementPage, "MOVEMENT ABILITIES")

bindToggle(abilitySection, "Sprint", "Sprint", "Run faster by the sprint multiplier")
bindToggle(abilitySection, "Double Jump", "DoubleJump", "One extra jump in the air")
bindToggle(abilitySection, "Infinite Jump", "InfiniteJump", "Jump again anywhere, any time")
bindToggle(abilitySection, "Air Control", "AirControl", "Steer your momentum while airborne")
bindToggle(abilitySection, "Auto Wall-Hop", "AutoWallHop", "Hold Space near a wall in the air")
bindToggle(abilitySection, "Wall Run", "WallRun", "Hold W beside a wall in the air")
bindToggle(abilitySection, "Fly Mode", "Fly", "WASD toward your camera, Space up, Left Ctrl down")
bindToggle(abilitySection, "Noclip", "Noclip", "Pass through walls (pair with fly)")

handlers.Sprint = function()
    touched.Speed = true
end

handlers.DoubleJump = function(value)
    if value then setFeature("InfiniteJump", false) end
end

handlers.InfiniteJump = function(value)
    if value then setFeature("DoubleJump", false) end
end

--==================================================
-- PAGE: ABILITIES
--==================================================

local abilitiesPage = createPage("Abilities")
pageTitle(abilitiesPage, "Abilities", "Dash, glide, checkpoints and quality-of-life tools.")

local dashSection = section(abilitiesPage, "TUNING")

sliders.DashPower = slider(dashSection, "Dash Power", 30, 150, SETTINGS.DashPower, 1, function(value)
    SETTINGS.DashPower = value
end)

sliders.DashCD = slider(dashSection, "Dash Cooldown (sec)", 0.4, 5, SETTINGS.DashCooldown, 0.1, function(value)
    SETTINGS.DashCooldown = value
end)

sliders.Glide = slider(dashSection, "Glide Fall Speed", 4, 40, SETTINGS.GlideFall, 1, function(value)
    SETTINGS.GlideFall = value
end)

local extraSection = section(abilitiesPage, "EXTRA ABILITIES")

bindToggle(extraSection, "Dash", "Dash", "Burst of speed in your move direction (Q)")
bindToggle(extraSection, "Glide", "Glide", "Hold Space while falling to glide")
bindToggle(extraSection, "Bunny Hop", "AutoJump", "Hold Space on the ground to keep jumping")
bindToggle(extraSection, "Teleport to Cursor", "Teleport", "Press T to teleport where your cursor points")
bindToggle(extraSection, "Void Rescue", "VoidRescue", "Return to checkpoint / last safe ground if you fall out")

local checkpointSection = section(abilitiesPage, "CHECKPOINT")
buttonRow(checkpointSection, {
    { "Set Checkpoint", setCheckpoint },
    { "Return to Checkpoint", returnToCheckpoint },
})

local controlsSection = section(abilitiesPage, "CONTROLS")
local controlText = text(controlsSection,
    "Keys are rebindable in Settings. Defaults: Q dash, T teleport to cursor,\n"
    .. "Z set checkpoint, X return to checkpoint, F fly, N noclip.\n"
    .. "NOTE: noclip without fly will drop you through the floor.",
    11, C.muted)
controlText.Size = UDim2.new(1, 0, 0, 56)
controlText.TextWrapped = true
controlText.TextYAlignment = Enum.TextYAlignment.Top

--==================================================
-- PAGE: WORLD
--==================================================

local worldPage = createPage("World")
pageTitle(worldPage, "World", "Local camera, lighting and physics preferences.")

local physicsSection = section(worldPage, "PHYSICS")

sliders.Gravity = slider(physicsSection, "Gravity", 10, 400, orig.Gravity, 1, function(value)
    workspace.Gravity = value
end)

local cameraSection = section(worldPage, "CAMERA")

sliders.FOV = slider(cameraSection, "Field of View", 50, 120, orig.FOV, 1, function(value)
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = value
    end
end)

sliders.Zoom = slider(cameraSection, "Max Camera Zoom", 10, 1000, math.clamp(orig.MaxZoom, 10, 1000), 1, function(value)
    player.CameraMaxZoomDistance = value
end)

local lightingSection = section(worldPage, "LIGHTING")

sliders.Brightness = slider(lightingSection, "Brightness", 0, 5, orig.Brightness, 0.1, function(value)
    Lighting.Brightness = value
end)

sliders.Time = slider(lightingSection, "Time of Day", 0, 24, orig.ClockTime, 0.25, function(value)
    SETTINGS.Time = value
    Lighting.ClockTime = value
end)

buttonRow(lightingSection, {
    { "Dawn", function() Lighting.ClockTime = 6; SETTINGS.Time = 6; sliders.Time(6, true) end },
    { "Noon", function() Lighting.ClockTime = 12; SETTINGS.Time = 12; sliders.Time(12, true) end },
    { "Dusk", function() Lighting.ClockTime = 18; SETTINGS.Time = 18; sliders.Time(18, true) end },
    { "Night", function() Lighting.ClockTime = 0; SETTINGS.Time = 0; sliders.Time(0, true) end },
})

bindToggle(lightingSection, "Freeze Time", "TimeLock", "Keeps the time of day above, even if the game changes it")
bindToggle(lightingSection, "Fullbright", "Fullbright", "Removes darkness and global shadows")
bindToggle(lightingSection, "No Fog", "NoFog", "Clears fog and atmosphere haze")

local worldInfo = text(worldPage,
    "World changes are local to your client.", 11, C.muted)
worldInfo.Size = UDim2.new(1, 0, 0, 24)

local function restoreWorld()
    local old = suppressNotify
    suppressNotify = true
    setFeature("TimeLock", false)
    setFeature("Fullbright", false)
    setFeature("NoFog", false)
    setFeature("FpsBoost", false)
    suppressNotify = old

    restoreWorldValues()

    SETTINGS.Time = orig.ClockTime
    sliders.Gravity(orig.Gravity, true)
    sliders.FOV(orig.FOV, true)
    sliders.Zoom(math.clamp(orig.MaxZoom, 10, 1000), true)
    sliders.Brightness(orig.Brightness, true)
    sliders.Time(orig.ClockTime, true)

    notify("World restored")
end

local restoreWorldSection = section(worldPage, "RESET")
buttonRow(restoreWorldSection, { { "Restore World Defaults", restoreWorld } })

--==================================================
-- PAGE: TOOLS
--==================================================

local toolsPage = createPage("Tools")
pageTitle(toolsPage, "Tools", "Camera, teleport and quality-of-life utilities.")

-- Coordinates HUD (shown above the speedometer).
local coordsHud = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -182),
    Size = UDim2.fromOffset(210, 26),
    BackgroundColor3 = C.bg,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Visible = CONFIG.CoordsHud,
}, gui)
round(coordsHud, 8)
outline(coordsHud)

local coordsLabel = text(coordsHud, "X 0    Y 0    Z 0", 10, C.white, Enum.Font.GothamMedium)
coordsLabel.Size = UDim2.fromScale(1, 1)
coordsLabel.TextXAlignment = Enum.TextXAlignment.Center

local cameraTools = section(toolsPage, "CAMERA & SPIN")

sliders.Freecam = slider(cameraTools, "Freecam Speed", 10, 300, SETTINGS.FreecamSpeed, 1, function(value)
    SETTINGS.FreecamSpeed = value
end)

sliders.Spin = slider(cameraTools, "Spin Speed (deg/sec)", 60, 1440, SETTINGS.SpinSpeed, 10, function(value)
    SETTINGS.SpinSpeed = value
end)

bindToggle(cameraTools, "Freecam", "Freecam", "Detach the camera: right-mouse drag to look, WASD / Space / Ctrl, Shift = fast")
bindToggle(cameraTools, "Spin", "Spin", "Rotate your character in place")

local qolTools = section(toolsPage, "QUALITY OF LIFE")

bindToggle(qolTools, "Anti-AFK", "AntiAfk", "Stops the 20 minute idle kick")
bindToggle(qolTools, "FPS Boost", "FpsBoost", "Lowest quality level, disables particles and post effects")

toggle(qolTools, "Coordinates HUD", CONFIG.CoordsHud, function(value)
    CONFIG.CoordsHud = value
    coordsHud.Visible = value
end, "Shows your position on screen")

-- Waypoints ---------------------------------------------------------------

local waypointSection = section(toolsPage, "WAYPOINTS")

local waypointStatus = {}

for slot = 1, 5 do
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, waypointSection)
    round(row, 8)
    outline(row)

    local cap = text(row, "Waypoint " .. slot, 12, C.white)
    cap.Position = UDim2.fromOffset(12, 0)
    cap.Size = UDim2.new(1, -230, 1, 0)

    local info = text(row, "empty", 10, C.muted)
    info.AnchorPoint = Vector2.new(1, 0)
    info.Position = UDim2.new(1, -150, 0, 0)
    info.Size = UDim2.fromOffset(70, 40)
    info.TextXAlignment = Enum.TextXAlignment.Right
    waypointStatus[slot] = info

    local saveBtn = newButton(row, "Save", 26)
    saveBtn.AnchorPoint = Vector2.new(1, 0.5)
    saveBtn.Position = UDim2.new(1, -66, 0.5, 0)
    saveBtn.Size = UDim2.fromOffset(60, 26)
    saveBtn.MouseButton1Click:Connect(function()
        if saveWaypoint(slot) then
            info.Text = "saved"
            info.TextColor3 = C.accent
        end
    end)

    local goBtn = newButton(row, "Go", 26)
    goBtn.AnchorPoint = Vector2.new(1, 0.5)
    goBtn.Position = UDim2.new(1, -8, 0.5, 0)
    goBtn.Size = UDim2.fromOffset(50, 26)
    goBtn.MouseButton1Click:Connect(function()
        gotoWaypoint(slot)
    end)
end

-- Players ----------------------------------------------------------------

local playerSection = section(toolsPage, "PLAYERS")

local playerList = make("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
}, playerSection)

make("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, playerList)

local function refreshPlayers()
    for _, child in ipairs(playerList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    playerList:SetAttribute("_n", 0)

    local count = 0
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            count += 1

            local row = make("Frame", {
                Size = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = C.card,
                BorderSizePixel = 0,
            }, playerList)
            round(row, 8)
            outline(row)

            local cap = text(row, other.DisplayName, 12, C.white)
            cap.Position = UDim2.fromOffset(12, 0)
            cap.Size = UDim2.new(1, -150, 1, 0)

            local tpBtn = newButton(row, "TP", 26)
            tpBtn.AnchorPoint = Vector2.new(1, 0.5)
            tpBtn.Position = UDim2.new(1, -68, 0.5, 0)
            tpBtn.Size = UDim2.fromOffset(52, 26)
            tpBtn.MouseButton1Click:Connect(function()
                local theirRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
                if theirRoot and hasChar() then
                    teleportTo(theirRoot.CFrame * CFrame.new(0, 0, 4))
                    notify("Teleported to " .. other.DisplayName)
                else
                    notify(other.DisplayName .. " isn't available")
                end
            end)

            local viewBtn = newButton(row, "View", 26)
            viewBtn.AnchorPoint = Vector2.new(1, 0.5)
            viewBtn.Position = UDim2.new(1, -8, 0.5, 0)
            viewBtn.Size = UDim2.fromOffset(54, 26)
            viewBtn.MouseButton1Click:Connect(function()
                spectatePlayer(other)
            end)
        end
    end

    if count == 0 then
        local empty = make("Frame", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
        }, playerList)
        local label = text(empty, "No other players in this server.", 11, C.muted)
        label.Size = UDim2.fromScale(1, 1)
    end
end

connect(Players.PlayerAdded, function() task.delay(0.25, refreshPlayers) end)
connect(Players.PlayerRemoving, function(leaving)
    if spectating == leaving then stopSpectate() end
    task.delay(0.25, refreshPlayers)
end)
refreshPlayers()

buttonRow(playerSection, {
    { "Stop Viewing", function()
        stopSpectate()
        notify("Camera restored")
    end },
    { "Refresh List", refreshPlayers },
})

-- Server -----------------------------------------------------------------

local serverSection = section(toolsPage, "SERVER")
buttonRow(serverSection, {
    { "Rejoin Server", function()
        notify("Rejoining...")
        pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
    end },
})

--==================================================
-- PAGE: EXTRAS (new in V6)
-- Everything lives in one table + its own function scope
-- so the main chunk doesn't hit Lua's 200-local limit.
--==================================================

local EX = { esp = {}, tags = {}, state = {}, deleted = {}, xray = {} }

;(function()
    local page = createPage("Extras")
    pageTitle(page, "Extras", "Player visuals, character effects and fun utilities.")

    local function say(name, v)
        notify(name .. (v and "  ON" or "  OFF"))
    end

    local function clearMap(m)
        for k, v in pairs(m) do
            if v and v.Parent then v:Destroy() end
            m[k] = nil
        end
    end

    ------------------------------------------------------------------
    -- PLAYER VISUALS
    ------------------------------------------------------------------
    local espSec = section(page, "PLAYER VISUALS")

    toggle(espSec, "Highlight ESP", false, function(v)
        EX.state.Esp = v
        if not v then clearMap(EX.esp) end
        say("Highlight ESP", v)
    end, "Outline other players through walls")

    toggle(espSec, "Name & Distance Tags", false, function(v)
        EX.state.Tags = v
        if not v then clearMap(EX.tags) end
        say("Name Tags", v)
    end, "Shows each player's name and how far away they are")

    toggle(espSec, "Team Colors", false, function(v)
        EX.state.TeamColor = v
    end, "Color ESP by team instead of your accent color")

    local function espColor(other)
        if EX.state.TeamColor and other.Team then
            return other.TeamColor.Color
        end
        return C.accent
    end

    local function updatePlayerVisuals()
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= player then
                local char = other.Character

                -- Highlight
                if EX.state.Esp and char then
                    local h = EX.esp[other]
                    if not h or h.Parent ~= char then
                        if h then h:Destroy() end
                        h = Instance.new("Highlight")
                        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        h.FillTransparency = 0.75
                        h.OutlineTransparency = 0
                        h.Adornee = char
                        h.Parent = char
                        EX.esp[other] = h
                    end
                    local col = espColor(other)
                    h.FillColor = col
                    h.OutlineColor = col
                end

                -- Name / distance tag
                local head = char and char:FindFirstChild("Head")
                if EX.state.Tags and head then
                    local bb = EX.tags[other]
                    if not bb or bb.Adornee ~= head or not bb.Parent then
                        if bb then bb:Destroy() end
                        bb = Instance.new("BillboardGui")
                        bb.Name = "NexusTag"
                        bb.Size = UDim2.fromOffset(170, 36)
                        bb.StudsOffset = Vector3.new(0, 2.6, 0)
                        bb.AlwaysOnTop = true
                        bb.Adornee = head
                        bb.ResetOnSpawn = false

                        local lbl = Instance.new("TextLabel")
                        lbl.Name = "L"
                        lbl.Size = UDim2.fromScale(1, 1)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamBold
                        lbl.TextSize = 13
                        lbl.TextStrokeTransparency = 0.4
                        lbl.Parent = bb

                        bb.Parent = playerGui
                        EX.tags[other] = bb
                    end
                    local dist = hasChar() and math.floor((root.Position - head.Position).Magnitude + 0.5) or 0
                    bb.L.Text = other.DisplayName .. "\n" .. dist .. " studs"
                    bb.L.TextColor3 = espColor(other)
                elseif EX.tags[other] then
                    EX.tags[other]:Destroy()
                    EX.tags[other] = nil
                end
            end
        end
    end

    connect(Players.PlayerRemoving, function(leaving)
        if EX.esp[leaving] then EX.esp[leaving]:Destroy() EX.esp[leaving] = nil end
        if EX.tags[leaving] then EX.tags[leaving]:Destroy() EX.tags[leaving] = nil end
    end)

    ------------------------------------------------------------------
    -- CHARACTER EFFECTS
    ------------------------------------------------------------------
    local charSec = section(page, "CHARACTER EFFECTS")

    toggle(charSec, "Trail", false, function(v)
        EX.state.Trail = v
        if not v and EX.trail then
            EX.trail:Destroy()
            if EX.a0 then EX.a0:Destroy() end
            if EX.a1 then EX.a1:Destroy() end
            EX.trail, EX.a0, EX.a1 = nil, nil, nil
        end
        say("Trail", v)
    end, "Leaves a glowing trail behind you")

    toggle(charSec, "Rainbow Trail", false, function(v)
        EX.state.Rainbow = v
    end, "Cycles the trail through every color")

    toggle(charSec, "Ghost Mode", false, function(v)
        EX.state.Ghost = v
        if not v and character then
            for _, p in ipairs(character:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 0 end
            end
        end
        say("Ghost Mode", v)
    end, "Makes your character see-through (only on your screen)")

    toggle(charSec, "Air Walk", false, function(v)
        EX.state.AirWalk = v
        if v then
            if not EX.platform then
                local p = Instance.new("Part")
                p.Name = "NexusAirWalk"
                p.Size = Vector3.new(7, 1, 7)
                p.Anchored = true
                p.Transparency = 1
                p.CanCollide = true
                p.Parent = workspace
                EX.platform = p
            end
            EX.airY = nil
        elseif EX.platform then
            EX.platform:Destroy()
            EX.platform = nil
        end
        say("Air Walk", v)
    end, "Walk on air at your current height. Jump to go higher, hold Ctrl to go lower")

    buttonRow(charSec, {
        { "Rocket Jump", function()
            if hasChar() then
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(v.X, 160, v.Z)
                notify("Liftoff!")
            end
        end },
        { "Sit", function()
            if hasChar() then humanoid.Sit = true end
        end },
        { "Reset", function()
            if hasChar() then humanoid.Health = 0 end
        end },
    })

    local function updateCharacterEffects(dt)
        if not hasChar() then return end

        -- Trail
        if EX.state.Trail and (not EX.trail or EX.trail.Parent ~= root) then
            if EX.trail then EX.trail:Destroy() end
            if EX.a0 then EX.a0:Destroy() end
            if EX.a1 then EX.a1:Destroy() end
            local a0 = Instance.new("Attachment")
            a0.Position = Vector3.new(0, 1, 0)
            a0.Parent = root
            local a1 = Instance.new("Attachment")
            a1.Position = Vector3.new(0, -1, 0)
            a1.Parent = root
            local t = Instance.new("Trail")
            t.Attachment0 = a0
            t.Attachment1 = a1
            t.Lifetime = 0.6
            t.LightEmission = 0.8
            t.Transparency = NumberSequence.new(0.2, 1)
            t.Parent = root
            EX.trail, EX.a0, EX.a1 = t, a0, a1
        end
        if EX.trail then
            local col = EX.state.Rainbow and Color3.fromHSV((os.clock() * 0.4) % 1, 0.85, 1) or C.accent
            EX.trail.Color = ColorSequence.new(col)
        end

        -- Ghost
        if EX.state.Ghost then
            for _, p in ipairs(character:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 0.65 end
            end
        end

        -- Air walk
        if EX.state.AirWalk and EX.platform then
            local footY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
            if not EX.airY then EX.airY = footY end
            if root.AssemblyLinearVelocity.Y <= 0 and footY > EX.airY + 0.6 then
                EX.airY = footY -- jumped higher and started falling: new floor
            end
            if keyDown(Enum.KeyCode.LeftControl) then
                EX.airY -= 18 * dt
            end
            EX.platform.CFrame = CFrame.new(root.Position.X, EX.airY - 0.5, root.Position.Z)
        end
    end

    ------------------------------------------------------------------
    -- CAMERA
    ------------------------------------------------------------------
    local camSec = section(page, "CAMERA")

    EX.state.ZoomKey = true
    toggle(camSec, "Hold C to Zoom", true, function(v)
        EX.state.ZoomKey = v
    end, "Hold C for a quick spyglass zoom")

    EX.zoomFov = 20
    slider(camSec, "Zoom FOV", 5, 50, EX.zoomFov, 1, function(v)
        EX.zoomFov = v
    end)

    connect(UIS.InputBegan, function(input, processed)
        if processed or typing() then return end
        local cam = workspace.CurrentCamera
        if not cam then return end

        if input.KeyCode == Enum.KeyCode.C and EX.state.ZoomKey and not EX.zooming then
            EX.zooming = true
            EX.prevFov = cam.FieldOfView
            tween(cam, { FieldOfView = EX.zoomFov }, 0.18)
        end

        -- Ctrl + Click delete (local)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and EX.state.ClickDelete
            and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            local target = player:GetMouse().Target
            if target and not target:IsA("Terrain") and not (character and target:IsDescendantOf(character)) then
                table.insert(EX.deleted, { target, target.Parent })
                target.Parent = nil
                notify("Deleted " .. target.Name .. "  (Undo in Extras)")
            end
        end
    end)

    connect(UIS.InputEnded, function(input)
        if input.KeyCode == Enum.KeyCode.C and EX.zooming then
            EX.zooming = false
            local cam = workspace.CurrentCamera
            if cam then tween(cam, { FieldOfView = EX.prevFov or 70 }, 0.18) end
        end
    end)

    ------------------------------------------------------------------
    -- WORLD TOOLS
    ------------------------------------------------------------------
    local worldSec = section(page, "WORLD TOOLS")

    local function setXray(v)
        if v then
            for _, p in ipairs(workspace:GetDescendants()) do
                if p:IsA("BasePart") and not p:IsA("Terrain") then
                    local model = p:FindFirstAncestorOfClass("Model")
                    if not (model and model:FindFirstChildOfClass("Humanoid")) then
                        p.LocalTransparencyModifier = 0.6
                        table.insert(EX.xray, p)
                    end
                end
            end
        else
            for _, p in ipairs(EX.xray) do
                if p.Parent then p.LocalTransparencyModifier = 0 end
            end
            table.clear(EX.xray)
        end
    end
    EX.setXray = setXray

    toggle(worldSec, "X-Ray", false, function(v)
        setXray(v)
        say("X-Ray", v)
    end, "See through walls and the map (only on your screen)")

    toggle(worldSec, "Ctrl + Click Delete", false, function(v)
        EX.state.ClickDelete = v
        say("Click Delete", v)
    end, "Hold Ctrl and click a part to remove it on your screen only")

    local function restoreDeleted(all)
        local n = 0
        while #EX.deleted > 0 do
            local entry = table.remove(EX.deleted)
            if entry[2] and entry[2].Parent ~= nil or entry[2] == workspace then
                entry[1].Parent = entry[2]
                n += 1
            end
            if not all then break end
        end
        return n
    end
    EX.restoreDeleted = restoreDeleted

    buttonRow(worldSec, {
        { "Undo Delete", function()
            notify(restoreDeleted(false) > 0 and "Part restored" or "Nothing to undo")
        end },
        { "Restore All", function()
            notify("Restored " .. restoreDeleted(true) .. " parts")
        end },
    })

    ------------------------------------------------------------------
    -- LOOPS + CLEANUP
    ------------------------------------------------------------------
    local acc = 0
    connect(RunService.Heartbeat, function(dt)
        updateCharacterEffects(dt)
        acc += dt
        if acc >= 0.2 then
            acc = 0
            updatePlayerVisuals()
        end
    end)

    gui.Destroying:Connect(function()
        clearMap(EX.esp)
        clearMap(EX.tags)
        if EX.trail then EX.trail:Destroy() end
        if EX.a0 then EX.a0:Destroy() end
        if EX.a1 then EX.a1:Destroy() end
        if EX.platform then EX.platform:Destroy() end
        setXray(false)
        restoreDeleted(true)
        if character then
            for _, p in ipairs(character:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 0 end
            end
        end
    end)
end)()


loader.step(0.85, "Applying settings")

--==================================================
-- PAGE: SETTINGS
--==================================================

local settingsPage = createPage("Settings")
pageTitle(settingsPage, "Settings", "Interface, keybinds, presets and resets.")

local uiSection = section(settingsPage, "INTERFACE")

toggle(uiSection, "Show Online Status", true, function(value)
    status.Visible = value
end)

toggle(uiSection, "Enable Hotkeys", CONFIG.UseHotkeys, function(value)
    CONFIG.UseHotkeys = value
end, "Fly, noclip, dash, teleport and checkpoint keys")

toggle(uiSection, "Notifications", CONFIG.Notifications, function(value)
    CONFIG.Notifications = value
end, "Small toasts when features change")

toggle(uiSection, "Speedometer HUD", CONFIG.Speedometer, function(value)
    CONFIG.Speedometer = value
    hud.Visible = value
end, "Live speed and dash cooldown above your hotbar")

toggle(uiSection, "Crosshair", CONFIG.Crosshair, function(value)
    CONFIG.Crosshair = value
    crosshair.Visible = value
end, "Small dot in the center of the screen")

local compact = false
buttonRow(uiSection, {
    { "Toggle Compact Window", function()
        compact = not compact
        tween(main, {
            Size = compact and UDim2.fromOffset(740, 470) or UDim2.fromOffset(840, 540),
        }, 0.2)
    end },
})

local appearanceSection = section(settingsPage, "APPEARANCE")

do
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, appearanceSection)
    round(row, 8)
    outline(row)

    local cap = text(row, "Accent Color", 12, C.white)
    cap.Position = UDim2.fromOffset(12, 0)
    cap.Size = UDim2.new(1, -200, 1, 0)

    local holder = make("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(150, 28),
        BackgroundTransparency = 1,
    }, row)

    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, holder)

    local strokes = {}
    for i, accent in ipairs(ACCENTS) do
        local swatch = make("TextButton", {
            Size = UDim2.fromOffset(26, 26),
            BackgroundColor3 = accent[2],
            Text = "",
            AutoButtonColor = false,
        }, holder)
        round(swatch, 13)

        local stroke = make("UIStroke", {
            Color = C.white,
            Thickness = 2,
            Transparency = i == 1 and 0 or 1,
        }, swatch)
        strokes[i] = stroke

        swatch.MouseButton1Click:Connect(function()
            setAccent(accent[2])
            for j, s in ipairs(strokes) do
                s.Transparency = j == i and 0 or 1
            end
            if checkpointPart then checkpointPart.Color = C.accent end
            notify("Accent: " .. accent[1])
        end)
    end
end

sliders.Opacity = slider(appearanceSection, "Window Opacity", 50, 100, 100, 1, function(value)
    baseTransparency = 1 - value / 100
    applyOpen()
end)

local keySection = section(settingsPage, "KEYBINDS  (click one, then press a key. Esc cancels)")
local keyChips = {}

for _, name in ipairs(KEY_ORDER) do
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, keySection)
    round(row, 8)
    outline(row)

    local cap = text(row, KEY_LABELS[name], 12, C.white)
    cap.Position = UDim2.fromOffset(12, 0)
    cap.Size = UDim2.new(1, -140, 1, 0)

    local chip = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(120, 26),
        BackgroundColor3 = C.hover,
        Text = KEYS[name].Name,
        TextColor3 = C.white,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
    }, row)
    round(chip, 6)

    keyChips[name] = chip

    chip.MouseButton1Click:Connect(function()
        if rebinding and keyChips[rebinding] then
            keyChips[rebinding].Text = KEYS[rebinding].Name
        end
        rebinding = name
        chip.Text = "press a key..."
    end)
end

-- Presets ---------------------------------------------------------------------

local function resetMovement()
    local old = suppressNotify
    suppressNotify = true

    for key in pairs(state) do
        if key ~= "TimeLock" and key ~= "Fullbright" and key ~= "NoFog"
            and key ~= "FpsBoost" and key ~= "AntiAfk" then
            setFeature(key, false)
        end
    end

    touched.Speed = false
    touched.Jump = false
    restoreHumanoid()

    SETTINGS.WalkSpeed = walkInit
    SETTINGS.SprintMultiplier = 1.75
    SETTINGS.JumpPower = jumpInit
    SETTINGS.FlySpeed = 55
    SETTINGS.AirControl = 0.16
    SETTINGS.DashPower = 80
    SETTINGS.DashCooldown = 1.2
    SETTINGS.GlideFall = 14
    SETTINGS.SpinSpeed = 360
    SETTINGS.FreecamSpeed = 50

    sliders.Spin(360, true)
    sliders.Freecam(50, true)
    sliders.Walk(walkInit, true)
    sliders.Sprint(1.75, true)
    sliders.Jump(jumpInit, true)
    sliders.Fly(55, true)
    sliders.Air(16, true)
    sliders.DashPower(80, true)
    sliders.DashCD(1.2, true)
    sliders.Glide(14, true)

    suppressNotify = old
end

local PRESETS = {
    {
        name = "Parkour",
        features = { "Sprint", "AirControl", "DoubleJump", "AutoWallHop", "WallRun", "Dash", "Glide", "VoidRescue" },
        values = { Sprint = 1.4, Air = 30, DashPower = 70 },
    },
    {
        name = "Explorer",
        features = { "Fly", "Sprint", "Fullbright", "Teleport" },
        values = { Fly = 80, Sprint = 2 },
    },
    {
        name = "Speedrun",
        features = { "Sprint", "AutoJump", "AirControl", "Dash", "VoidRescue" },
        values = { Sprint = 2, Air = 40, DashCD = 0.8 },
    },
    {
        name = "Builder",
        features = { "Fly", "Noclip", "Fullbright", "Teleport" },
        values = { Fly = 90 },
    },
}

local function applyPreset(preset)
    resetMovement()

    local old = suppressNotify
    suppressNotify = true

    for sliderName, value in pairs(preset.values) do
        if sliders[sliderName] then
            sliders[sliderName](value)
        end
    end

    for _, key in ipairs(preset.features) do
        setFeature(key, true)
    end

    suppressNotify = old
    notify("Preset: " .. preset.name)
end

local presetSection = section(settingsPage, "PRESETS")
do
    local defs = {}
    for _, preset in ipairs(PRESETS) do
        table.insert(defs, { preset.name, function() applyPreset(preset) end })
    end
    buttonRow(presetSection, defs)
end

local resetSection = section(settingsPage, "RESET")
buttonRow(resetSection, {
    { "Reset Movement Features", function()
        resetMovement()
        notify("Movement reset")
    end },
    { "Restore World Defaults", restoreWorld },
})

--==================================================
-- STATUS UPDATES / HUD
--==================================================

-- HUD updates every frame for smoothness.
connect(RunService.Heartbeat, function(dt)
    if not hasChar() then return end

    local speed = horizontal(root.AssemblyLinearVelocity).Magnitude
    smoothSpeed += (speed - smoothSpeed) * math.min(1, dt * 10)

    if hud.Visible then
        hudValue.Text = tostring(math.floor(smoothSpeed + 0.5))
        hudFill.Size = UDim2.new(math.clamp(smoothSpeed / 120, 0, 1), 0, 1, 0)

        if state.Dash then
            local left = dashReadyAt - os.clock()
            hudDash.Text = left > 0 and string.format("DASH %.1fs", left) or "DASH READY"
        else
            hudDash.Text = ""
        end
    end
end)

-- Slower tick for stats, labels and world enforcement.
do
    local acc, frames = 0, 0

    connect(RunService.Heartbeat, function(dt)
        acc += dt
        frames += 1
        if acc < 0.2 then return end

        local fps = frames / acc
        acc, frames = 0, 0

        enforceWorld()

        local names = {}
        for _, f in ipairs(FEATURES) do
            if state[f[1]] then table.insert(names, f[2]) end
        end
        featureStat.Text = tostring(#names)
        activeLabel.Text = "Active: " .. (#names > 0 and table.concat(names, ", ") or "None")

        fpsStat.Text = tostring(math.floor(fps + 0.5))

        local ok, ping = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        pingStat.Text = ok and (tostring(math.floor(ping + 0.5)) .. " ms") or "--"

        speedStat.Text = tostring(math.floor(smoothSpeed + 0.5))

        if coordsHud.Visible and hasChar() then
            local p = root.Position
            coordsLabel.Text = string.format("X %.0f    Y %.0f    Z %.0f", p.X, p.Y, p.Z)
        end
        if hasChar() then
            walkStat.Text = tostring(math.floor(humanoid.WalkSpeed + 0.5))
        end

        status.Text = state.Fly and "● FLYING"
            or state.Noclip and "● NOCLIP"
            or "● READY"
    end)
end

--==================================================
-- INPUT (rebinding + hotkeys)
--==================================================

connect(UIS.InputBegan, function(input, processed)
    -- Keybind capture takes priority over everything.
    if rebinding and input.UserInputType == Enum.UserInputType.Keyboard then
        local name = rebinding
        rebinding = nil

        if input.KeyCode ~= Enum.KeyCode.Escape then
            KEYS[name] = input.KeyCode
            notify(KEY_LABELS[name] .. ": " .. input.KeyCode.Name)
        end

        keyChips[name].Text = KEYS[name].Name
        updateFooter()
        return
    end

    if processed then return end

    local key = input.KeyCode

    if key == KEYS.Menu then
        setMenuOpen(not menuOpen)
    elseif CONFIG.UseHotkeys then
        if key == KEYS.Fly then
            setFeature("Fly", not state.Fly)
        elseif key == KEYS.Noclip then
            setFeature("Noclip", not state.Noclip)
        elseif key == KEYS.Dash then
            doDash()
        elseif key == KEYS.Teleport then
            teleportToCursor()
        elseif key == KEYS.SetCheckpoint then
            setCheckpoint()
        elseif key == KEYS.ReturnCheckpoint then
            returnToCheckpoint()
        elseif key == KEYS.Freecam then
            setFeature("Freecam", not state.Freecam)
        end
    end
end)

--==================================================
-- START
--==================================================

switchPage("Overview")

if player.Character then
    task.spawn(onCharacterAdded, player.Character)
end

openVal.Value = 0
applyOpen()

loader.step(0.95, "Finalizing")
loader.finish()

setMenuOpen(true)
notify("Loaded  ·  " .. KEYS.Menu.Name .. " hides menu")

print("NEXUS V6 loaded.")