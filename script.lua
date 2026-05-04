--[[
    FREECAM HUB v2.0
    Mobile + PC | Roll Axis | Touch Rotate
    Save Settings | Hotkeys | Coordinates
]]

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VERSION = "2.0"

-- PLATFORM
local IS_MOBILE = UserInputService.TouchEnabled
    and not UserInputService.KeyboardEnabled
    and not UserInputService.MouseEnabled
local IS_PC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
local PLATFORM = IS_MOBILE and "Mobile" or "PC"

-- WEBHOOK + BAN
local WEBHOOK_URL = "https://discord.com/api/webhooks/1446147402275749916/m5eZ12l6RKrjSGJKuVnxRyKBb4mQIqlVQJloX9dhfQ6Ue1lCNRwYwjJxGuqCdGh2MrDO"
local BAN_API_URL = "https://ban-management-system.onrender.com/api/banlist"
local OnlineBanList = {}

-- HTTP HELPER
local function httpReq(opt)
    local fn = request or http_request
        or (syn and syn.request)
        or (http and http.request)
        or (fluxus and fluxus.request)
    if not fn then return nil end
    local ok, r = pcall(fn, opt)
    return ok and r or nil
end

local function httpGet(url)
    local ok, r = pcall(function() return game:HttpGet(url) end)
    if ok and r then return r end
    local resp = httpReq({Url = url, Method = "GET"})
    return resp and resp.Body or nil
end

-- BAN SYSTEM
local function fetchBans()
    local raw = httpGet(BAN_API_URL)
    if not raw then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and data and data.bans then
        OnlineBanList = data.bans
        return true
    end
    return false
end

local function formatTime(expiresAt)
    if not expiresAt or expiresAt == "null" or expiresAt == "" then
        return "Permanent"
    end
    local ok, exp = pcall(function()
        local y,m,d,h,mn,s = expiresAt:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
        if y then
            return os.time({
                year=tonumber(y), month=tonumber(m), day=tonumber(d),
                hour=tonumber(h), min=tonumber(mn), sec=tonumber(s)
            })
        end
    end)
    if not ok or not exp then return "Unknown" end
    local rem = exp - os.time()
    if rem <= 0 then return "Expired" end
    local days = math.floor(rem / 86400)
    local hours = math.floor((rem % 86400) / 3600)
    local mins = math.floor((rem % 3600) / 60)
    if days > 0 then return days.."d "..hours.."h"
    elseif hours > 0 then return hours.."h "..mins.."m"
    else return mins.."m" end
end

local function checkBan()
    local id = tostring(Player.UserId)
    if not OnlineBanList[id] then return false end
    local info = OnlineBanList[id]
    if info.expiresAt and info.expiresAt ~= "null" and info.expiresAt ~= "" then
        local ok, exp = pcall(function()
            local y,m,d,h,mn,s = info.expiresAt:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            if y then
                return os.time({
                    year=tonumber(y), month=tonumber(m), day=tonumber(d),
                    hour=tonumber(h), min=tonumber(mn), sec=tonumber(s)
                })
            end
        end)
        if ok and exp and os.time() > exp then return false end
    end
    Player:Kick(
        "\n==============================\n"
        .."BANNED\n"
        .."==============================\n"
        .."Reason: "..(info.reason or "N/A").."\n"
        .."By: "..(info.bannedBy or "Admin").."\n"
        .."Time Left: "..formatTime(info.expiresAt).."\n"
        .."=============================="
    )
    return true
end

pcall(fetchBans)
if checkBan() then return end

task.spawn(function()
    while true do
        task.wait(60)
        pcall(function() fetchBans() checkBan() end)
    end
end)

-- LOAD RAYFIELD
local RayfieldOk, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not RayfieldOk or not Rayfield then
    -- Fallback: try alternative
    local ok2, rf2 = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source"))()
    end)
    if ok2 and rf2 then
        Rayfield = rf2
    else
        warn("Freecam Hub: Failed to load Rayfield UI")
        return
    end
end

-- NOTIFY HELPER
local function notify(title, content, duration)
    pcall(function()
        Rayfield:Notify({
            Title = title or "Info",
            Content = content or "",
            Duration = duration or 4,
        })
    end)
end

-- SAVE/LOAD
local SAVE_KEY = "FreecamHub_v2_Settings"

local function saveSettings(State)
    pcall(function()
        if not writefile then return end
        local data = {
            FreecamSpeed   = State.FreecamSpeed,
            FOV            = State.FOV,
            WalkSpeedValue = State.WalkSpeedValue,
            JumpPowerValue = State.JumpPowerValue,
            DynamicSpeed   = State.DynamicSpeed,
            CinematicMode  = State.CinematicMode,
            GhostMode      = State.GhostMode,
            NoclipEnabled  = State.NoclipEnabled,
            InfiniteJump   = State.InfiniteJump,
            DynamicFOV     = State.DynamicFOV,
            CameraShake    = State.CameraShake,
            ShowCoords     = State.ShowCoords,
            CameraRotSpeed = State.CameraRotSpeed,
            PC_MouseSensitivity = State.PC_MouseSensitivity,
            TouchSensitivity    = State.TouchSensitivity,
        }
        writefile(SAVE_KEY..".json", HttpService:JSONEncode(data))
    end)
end

local function loadSettings()
    local data = nil
    pcall(function()
        if isfile and isfile(SAVE_KEY..".json") then
            local raw = readfile(SAVE_KEY..".json")
            data = HttpService:JSONDecode(raw)
        end
    end)
    return data
end

-- STATE
local State = {
    -- Freecam
    FreecamEnabled   = false,
    FreecamSpeed     = 50,
    FreecamGoingUp   = false,
    FreecamGoingDown = false,
    CinematicMode    = false,
    GhostMode        = false,
    DynamicSpeed     = true,

    -- Auto align
    AutoAlignCamera  = false,
    AutoAlignStrength = 0.03,
    AutoAlignPitch   = false,

    -- UI
    UIHidden         = false,

    -- Roll buttons state
    RollingLeft      = false,
    RollingRight     = false,
    CameraRotSpeed   = 2,

    -- Camera angles (separate axes)
    CameraYaw   = 0,
    CameraPitch = 0,
    CameraRoll  = 0,

    -- FOV
    FOV        = 70,
    DynamicFOV = false,

    -- Effects
    CameraShake    = false,
    SmoothTeleport = false,
    ChaosMode      = false,

    -- Character
    NoclipEnabled  = false,
    WalkSpeedValue = 16,
    JumpPowerValue = 50,
    InfiniteJump   = false,

    -- Target
    FollowTarget   = nil,
    LockTarget     = nil,

    -- Save/Load camera
    SavedCameraPos  = nil,
    SavedCameraLook = nil,

    -- Scan
    ScanHighlights = {},
    ScanRange      = 200,

    -- Connections
    Connections = {},

    -- PC
    PC_Keys = {
        W = false, A = false, S = false, D = false,
        Space = false, LeftControl = false, LeftShift = false,
    },
    PC_MouseSensitivity = 0.3,
    PC_MouseLocked      = false,
    PC_SpeedBoost       = false,

    -- Touch
    TouchSensitivity = 0.4,

    -- Coords
    ShowCoords = true,

    -- Feedback
    LastFeedbackTime = 0,
    FeedbackCooldown = 600,
    FeedbackText     = "",
    FeedbackAgreed   = false,
}

-- Apply saved settings
local saved = loadSettings()
if saved then
    for k, v in pairs(saved) do
        if State[k] ~= nil then
            State[k] = v
        end
    end
end

local freecamPosition = Vector3.zero
local freecamVelocity = Vector3.zero

-- CONNECTIONS
local function disconnectKey(key)
    local conn = State.Connections[key]
    if conn and typeof(conn) == "RBXScriptConnection" and conn.Connected then
        conn:Disconnect()
    end
    State.Connections[key] = nil
end

local function disconnectAll()
    for key, conn in pairs(State.Connections) do
        if typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
        end
    end
    State.Connections = {}
end

-- CHARACTER HELPERS
local function getChar()
    return Player.Character
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function anchorChar(doAnchor)
    pcall(function()
        local c = getChar()
        if not c then return end
        for _, part in pairs(c:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = doAnchor
            end
        end
    end)
end

local function setCharVisible(visible)
    pcall(function()
        local c = getChar()
        if not c then return end
        for _, part in pairs(c:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = visible and 0 or 1
            elseif part:IsA("Decal") then
                part.Transparency = visible and 0 or 1
            end
        end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Transparency = 1 end
    end)
end

-- MATH HELPERS
local function normAngle(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end

local function shortAngleDiff(from, to)
    return normAngle(to - from)
end

local function lerpAngle(from, to, alpha)
    return from + shortAngleDiff(from, to) * math.clamp(alpha, 0, 1)
end

-- PC INPUT
local function setupPCInput()
    if not IS_PC then return end

    disconnectKey("PCKeyDown")
    disconnectKey("PCKeyUp")
    disconnectKey("PCMouse")

    State.Connections["PCKeyDown"] = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end

        local k = input.KeyCode

        -- F = toggle freecam
        if k == Enum.KeyCode.F then
            if State.FreecamEnabled then
                disableFreecam()
            else
                enableFreecam()
            end
            return
        end

        -- R = reset rotation
        if k == Enum.KeyCode.R and State.FreecamEnabled then
            State.CameraYaw   = 0
            State.CameraPitch = 0
            State.CameraRoll  = 0
            notify("Camera", "Rotation reset", 2)
            return
        end

        if not State.FreecamEnabled then return end

        local name = k.Name
        if State.PC_Keys[name] ~= nil then
            State.PC_Keys[name] = true
        end

        if k == Enum.KeyCode.LeftShift then
            State.PC_SpeedBoost = true
        end
    end)

    State.Connections["PCKeyUp"] = UserInputService.InputEnded:Connect(function(input)
        local name = input.KeyCode.Name
        if State.PC_Keys[name] ~= nil then
            State.PC_Keys[name] = false
        end
        if input.KeyCode == Enum.KeyCode.LeftShift then
            State.PC_SpeedBoost = false
        end
    end)

    State.Connections["PCMouse"] = UserInputService.InputChanged:Connect(function(input, gp)
        if gp or not State.FreecamEnabled or not State.PC_MouseLocked then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Delta
            local sens = State.PC_MouseSensitivity / 100
            State.CameraYaw   = normAngle(State.CameraYaw - delta.X * sens)
            State.CameraPitch = math.clamp(
                State.CameraPitch - delta.Y * sens,
                -math.rad(89), math.rad(89)
            )
        end
    end)
end

local function lockMouse()
    if not IS_PC then return end
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
        State.PC_MouseLocked = true
    end)
end

local function unlockMouse()
    if not IS_PC then return end
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        State.PC_MouseLocked = false
    end)
end

local function resetKeys()
    for key in pairs(State.PC_Keys) do
        State.PC_Keys[key] = false
    end
    State.PC_SpeedBoost = false
end

local function getPCMove()
    local f, r, u = 0, 0, 0
    if State.PC_Keys.W then f = f + 1 end
    if State.PC_Keys.S then f = f - 1 end
    if State.PC_Keys.D then r = r + 1 end
    if State.PC_Keys.A then r = r - 1 end
    if State.PC_Keys.Space then u = u + 1 end
    if State.PC_Keys.LeftControl then u = u - 1 end
    return f, r, u
end

-- TOUCH ROTATION
local activeTouchInput = nil

local function setupTouchRotation()
    if not IS_MOBILE then return end

    disconnectKey("TouchStart")
    disconnectKey("TouchMove")
    disconnectKey("TouchEnd")

    State.Connections["TouchStart"] = UserInputService.TouchStarted:Connect(function(touch, gp)
        if gp or not State.FreecamEnabled then return end
        if activeTouchInput then return end

        -- Only right 70% of screen for rotation
        local sw = Camera.ViewportSize.X
        if touch.Position.X > sw * 0.3 then
            activeTouchInput = touch
        end
    end)

    State.Connections["TouchMove"] = UserInputService.TouchMoved:Connect(function(touch, gp)
        if gp or not State.FreecamEnabled then return end
        if touch ~= activeTouchInput then return end

        local delta = touch.Delta
        local sens = State.TouchSensitivity / 100

        State.CameraYaw   = normAngle(State.CameraYaw - delta.X * sens)
        State.CameraPitch = math.clamp(
            State.CameraPitch - delta.Y * sens,
            -math.rad(89), math.rad(89)
        )
    end)

    State.Connections["TouchEnd"] = UserInputService.TouchEnded:Connect(function(touch)
        if touch == activeTouchInput then
            activeTouchInput = nil
        end
    end)
end

-- MOBILE UI
local FreecamGuis = {}

local function destroyAllUI()
    State.FreecamGoingUp   = false
    State.FreecamGoingDown = false
    State.RollingLeft      = false
    State.RollingRight     = false
    State.UIHidden         = false
    activeTouchInput       = nil

    for _, gui in pairs(FreecamGuis) do
        pcall(function()
            if gui and gui.Parent then gui:Destroy() end
        end)
    end
    FreecamGuis = {}
end

local function makeCircleBtn(parent, text, size, pos, color, zidx)
    local btn = Instance.new("TextButton")
    btn.Size = size
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.2
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 30
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Active = true
    btn.ZIndex = zidx or 10
    btn.Parent = parent

    Instance.new("UICorner", btn).CornerRadius = UDim.new(0.5, 0)

    return btn
end

local function hookHold(btn, stateKey, pressClr, releaseClr)
    local holding = false

    local function startH()
        if holding then return end
        holding = true
        State[stateKey] = true
        btn.BackgroundColor3 = pressClr
    end

    local function endH()
        if not holding then return end
        holding = false
        State[stateKey] = false
        btn.BackgroundColor3 = releaseClr
    end

    btn.MouseButton1Down:Connect(startH)
    btn.MouseButton1Up:Connect(endH)

    btn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then startH() end
    end)

    btn.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
            or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            endH()
        end
    end)

    btn.MouseLeave:Connect(endH)
end

local function createMobileUI()
    if IS_PC then return end
    destroyAllUI()

    local gui = Instance.new("ScreenGui")
    gui.Name = "FCMobileUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 110
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local BTN = UDim2.new(0, 72, 0, 72)
    local BTN_SM = UDim2.new(0, 62, 0, 62)
    local BLUE   = Color3.fromRGB(50, 130, 255)
    local BLUE_P = Color3.fromRGB(90, 170, 255)
    local RED    = Color3.fromRGB(220, 60, 60)
    local RED_P  = Color3.fromRGB(255, 100, 100)
    local ROLL   = Color3.fromRGB(70, 70, 110)
    local ROLL_P = Color3.fromRGB(110, 110, 170)

    -- FLY UP (bottom right, like Roblox jump)
    local flyUp = makeCircleBtn(gui, "▲", BTN,
        UDim2.new(1, -92, 1, -105), BLUE, 12)
    hookHold(flyUp, "FreecamGoingUp", BLUE_P, BLUE)

    -- FLY DOWN (left of fly up)
    local flyDown = makeCircleBtn(gui, "▼", BTN,
        UDim2.new(1, -178, 1, -105), RED, 12)
    hookHold(flyDown, "FreecamGoingDown", RED_P, RED)

    -- ROLL LEFT (left side, upper)
    local rollL = makeCircleBtn(gui, "↺", BTN_SM,
        UDim2.new(0, 12, 0.5, -75), ROLL, 12)
    hookHold(rollL, "RollingLeft", ROLL_P, ROLL)

    -- ROLL RIGHT (left side, lower)
    local rollR = makeCircleBtn(gui, "↻", BTN_SM,
        UDim2.new(0, 12, 0.5, 5), ROLL, 12)
    hookHold(rollR, "RollingRight", ROLL_P, ROLL)

    -- HIDE BUTTON (top center)
    local hideBtn = makeCircleBtn(gui, "🙈",
        UDim2.new(0, 44, 0, 44),
        UDim2.new(0.5, -22, 0, 8),
        Color3.fromRGB(40, 40, 60), 15)
    hideBtn.TextSize = 20

    hideBtn.MouseButton1Click:Connect(function()
        State.UIHidden = not State.UIHidden
        hideBtn.Text = State.UIHidden and "👁️" or "🙈"
        flyUp.Visible   = not State.UIHidden
        flyDown.Visible = not State.UIHidden
        rollL.Visible   = not State.UIHidden
        rollR.Visible   = not State.UIHidden
    end)

    gui.Parent = Player:FindFirstChildOfClass("PlayerGui")
    table.insert(FreecamGuis, gui)
end

-- COORDINATE DISPLAY
local CoordsGui = nil

local function createCoordsUI()
    if CoordsGui then
        CoordsGui:Destroy()
        CoordsGui = nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "FCCoords"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 108

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 210, 0, 28)
    frame.Position = UDim2.new(0.5, -105, 0, IS_MOBILE and 58 or 6)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.55
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Name = "Coords"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "X: 0  Y: 0  Z: 0"
    label.TextColor3 = Color3.fromRGB(180, 220, 255)
    label.TextSize = 13
    label.Font = Enum.Font.RobotoMono
    label.ZIndex = 5
    label.Parent = frame

    gui.Parent = Player:FindFirstChildOfClass("PlayerGui")
    CoordsGui = gui
    table.insert(FreecamGuis, gui)
end

local function updateCoords()
    if not CoordsGui then return end
    local label = CoordsGui:FindFirstDescendant("Coords")
    if not label then return end

    if not State.ShowCoords or not State.FreecamEnabled then
        CoordsGui.Enabled = false
        return
    end

    CoordsGui.Enabled = true
    local p = freecamPosition
    label.Text = string.format("X: %d  Y: %d  Z: %d",
        math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
end

-- FREECAM ENABLE
function enableFreecam()
    if State.FreecamEnabled then return end
    pcall(function()
        fetchBans()
        if checkBan() then return end
    end)

    State.FreecamEnabled = true
    disconnectKey("FCRender")

    local cf = Camera.CFrame
    freecamPosition = cf.Position
    freecamVelocity = Vector3.zero

    local look = cf.LookVector
    State.CameraYaw   = math.atan2(-look.X, -look.Z)
    State.CameraPitch = math.asin(math.clamp(look.Y, -1, 1))
    State.CameraRoll  = 0

    Camera.CameraType = Enum.CameraType.Scriptable
    anchorChar(true)

    local hum = getHum()
    if hum then hum.WalkSpeed = 0 end

    if State.GhostMode then setCharVisible(false) end

    if IS_PC then
        lockMouse()
        resetKeys()
    else
        createMobileUI()
        setupTouchRotation()
    end

    createCoordsUI()

    -- MAIN RENDER LOOP
    State.Connections["FCRender"] = RunService.RenderStepped:Connect(function(dt)
        if not State.FreecamEnabled then return end

        -- ROLL (Z axis, full 360)
        local rollSpd = State.CameraRotSpeed * dt
        if State.RollingLeft then
            State.CameraRoll = normAngle(State.CameraRoll + rollSpd)
        end
        if State.RollingRight then
            State.CameraRoll = normAngle(State.CameraRoll - rollSpd)
        end

        -- Normalize
        State.CameraYaw   = normAngle(State.CameraYaw)
        State.CameraPitch = math.clamp(State.CameraPitch, -math.rad(89), math.rad(89))

        -- Movement vectors (no roll for movement direction)
        local yawCF   = CFrame.Angles(0, State.CameraYaw, 0)
        local pitchCF = CFrame.Angles(State.CameraPitch, 0, 0)
        local moveRot = yawCF * pitchCF

        local camLook  = moveRot.LookVector
        local camRight = moveRot.RightVector
        local camUp    = Vector3.new(0, 1, 0)

        -- MOVEMENT INPUT
        local moveVec  = Vector3.zero
        local isMoving = false
        local inputMag = 1

        if IS_PC then
            local fw, rt, up = getPCMove()
            if fw ~= 0 or rt ~= 0 then
                moveVec  = (camLook * fw) + (camRight * rt)
                isMoving = true
            end
            if up ~= 0 then
                moveVec  = moveVec + camUp * up
                isMoving = true
            end
        else
            local hum2 = getHum()
            if hum2 then
                local md = hum2.MoveDirection
                if md.Magnitude > 0.01 then
                    isMoving  = true
                    inputMag  = math.clamp(md.Magnitude, 0.1, 1)

                    local cff = Vector3.new(camLook.X, 0, camLook.Z)
                    cff = cff.Magnitude > 0.001 and cff.Unit or Vector3.new(0,0,-1)

                    local crf = Vector3.new(camRight.X, 0, camRight.Z)
                    crf = crf.Magnitude > 0.001 and crf.Unit or Vector3.new(1,0,0)

                    moveVec = (camLook * md:Dot(cff)) + (camRight * md:Dot(crf))
                end
            end

            if State.FreecamGoingUp then
                moveVec  = moveVec + camUp
                isMoving = true
            end
            if State.FreecamGoingDown then
                moveVec  = moveVec - camUp
                isMoving = true
            end
        end

        if moveVec.Magnitude > 1 then
            moveVec = moveVec.Unit
        end

        -- SPEED
        local speed = State.FreecamSpeed
        if State.DynamicSpeed and IS_MOBILE then speed = speed * inputMag end
        if State.CinematicMode then speed = speed * 0.3 end
        if State.PC_SpeedBoost then speed = speed * 2.5 end

        -- VELOCITY + POSITION
        local targetVel = moveVec * speed
        if State.CinematicMode then
            freecamVelocity = freecamVelocity:Lerp(targetVel, 0.08)
        else
            freecamVelocity = targetVel
        end
        freecamPosition = freecamPosition + freecamVelocity * dt

        -- AUTO ALIGN
        if State.AutoAlignCamera and isMoving and not State.FollowTarget and not State.LockTarget then
            local hv = Vector3.new(freecamVelocity.X, 0, freecamVelocity.Z)
            if hv.Magnitude > 1 then
                local ty = math.atan2(-hv.X, -hv.Z)
                local yd = shortAngleDiff(State.CameraYaw, ty)
                if math.abs(yd) > 0.01 then
                    State.CameraYaw = normAngle(State.CameraYaw + yd * State.AutoAlignStrength)
                end
            end
            if State.AutoAlignPitch and freecamVelocity.Magnitude > 1 then
                local tp = math.asin(math.clamp(freecamVelocity.Unit.Y, -1, 1))
                local pd = tp - State.CameraPitch
                if math.abs(pd) > 0.01 then
                    State.CameraPitch = math.clamp(
                        State.CameraPitch + pd * State.AutoAlignStrength * 0.5,
                        -math.rad(89), math.rad(89))
                end
            end
        end

        -- FOLLOW
        if State.FollowTarget then
            local tp = Players:FindFirstChild(State.FollowTarget)
            if tp and tp.Character then
                local thrp = tp.Character:FindFirstChild("HumanoidRootPart")
                if thrp then
                    freecamPosition = thrp.Position + Vector3.new(0, 10, 15)
                    local dir = (thrp.Position - freecamPosition)
                    if dir.Magnitude > 0.1 then
                        dir = dir.Unit
                        State.CameraYaw   = lerpAngle(State.CameraYaw, math.atan2(-dir.X,-dir.Z), 0.1)
                        State.CameraPitch = State.CameraPitch + (math.asin(math.clamp(dir.Y,-1,1)) - State.CameraPitch) * 0.1
                    end
                end
            end
        end

        -- LOCK
        if State.LockTarget then
            local tp = Players:FindFirstChild(State.LockTarget)
            if tp and tp.Character then
                local thrp = tp.Character:FindFirstChild("HumanoidRootPart")
                if thrp then
                    local dir = (thrp.Position - freecamPosition)
                    if dir.Magnitude > 0.1 then
                        dir = dir.Unit
                        State.CameraYaw   = lerpAngle(State.CameraYaw, math.atan2(-dir.X,-dir.Z), 0.15)
                        State.CameraPitch = math.clamp(
                            State.CameraPitch + (math.asin(math.clamp(dir.Y,-1,1)) - State.CameraPitch) * 0.15,
                            -math.rad(89), math.rad(89))
                    end
                end
            end
        end

        -- EFFECTS
        if State.DynamicFOV then
            local tf = math.clamp(State.FOV + freecamVelocity.Magnitude * 0.3, 30, 120)
            Camera.FieldOfView = Camera.FieldOfView + (tf - Camera.FieldOfView) * 0.1
        end

        local shake = Vector3.zero
        if State.CameraShake and freecamVelocity.Magnitude > 5 then
            local i = math.clamp(freecamVelocity.Magnitude / State.FreecamSpeed, 0, 1) * 0.12
            shake = Vector3.new(
                (math.random()-0.5)*i,
                (math.random()-0.5)*i,
                (math.random()-0.5)*i)
        end

        if State.ChaosMode then
            Camera.FieldOfView = math.random(40, 110)
            shake = shake + Vector3.new(
                (math.random()-0.5)*0.4,
                (math.random()-0.5)*0.4, 0)
        end

        -- APPLY CAMERA (Yaw * Pitch * Roll)
        local rollCF = CFrame.Angles(0, 0, State.CameraRoll)
        Camera.CFrame = CFrame.new(freecamPosition + shake) * yawCF * pitchCF * rollCF

        updateCoords()
    end)

    local ctrl = IS_PC
        and "Mouse=Rotate | WASD=Move | F=Toggle | Shift=Boost | R=Reset"
        or  "Swipe=Rotate | Joystick=Move | Btns=Fly+Roll"
    notify("Freecam ON", PLATFORM.."\n"..ctrl, 5)
end

-- FREECAM DISABLE
function disableFreecam()
    if not State.FreecamEnabled then return end
    State.FreecamEnabled = false

    disconnectKey("FCRender")
    disconnectKey("TouchStart")
    disconnectKey("TouchMove")
    disconnectKey("TouchEnd")

    State.FreecamGoingUp   = false
    State.FreecamGoingDown = false
    State.RollingLeft      = false
    State.RollingRight     = false
    freecamVelocity        = Vector3.zero
    State.CameraRoll       = 0
    activeTouchInput       = nil

    anchorChar(false)

    local hum = getHum()
    if hum then hum.WalkSpeed = State.WalkSpeedValue end

    if State.GhostMode then setCharVisible(true) end

    Camera.CameraType = Enum.CameraType.Custom
    pcall(function() Camera.CameraSubject = getHum() end)

    if not State.DynamicFOV and not State.ChaosMode then
        Camera.FieldOfView = State.FOV
    end

    if IS_PC then unlockMouse() resetKeys() end

    destroyAllUI()
    saveSettings(State)

    notify("Freecam", "OFF", 3)
end

-- NOCLIP
local function enableNoclip()
    disconnectKey("NoclipStep")
    State.NoclipEnabled = true
    State.Connections["NoclipStep"] = RunService.Stepped:Connect(function()
        if not State.NoclipEnabled then return end
        local c = getChar() if not c then return end
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
    notify("Noclip", "ON", 3)
end

local function disableNoclip()
    State.NoclipEnabled = false
    disconnectKey("NoclipStep")
    pcall(function()
        local c = getChar() if not c then return end
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                p.CanCollide = true
            end
        end
    end)
    notify("Noclip", "OFF", 3)
end

-- INFINITE JUMP
local function setupInfJump()
    disconnectKey("InfJump")
    State.Connections["InfJump"] = UserInputService.JumpRequest:Connect(function()
        if not State.InfiniteJump then return end
        local h = getHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end
setupInfJump()

-- RESPAWN
Player.CharacterAdded:Connect(function()
    task.wait(0.5)
    pcall(function() fetchBans() checkBan() end)
    local h = getHum() if not h then return end
    if State.WalkSpeedValue ~= 16 then h.WalkSpeed = State.WalkSpeedValue end
    if State.JumpPowerValue ~= 50 then
        h.JumpPower = State.JumpPowerValue
        h.UseJumpPower = true
    end
    if State.NoclipEnabled then enableNoclip() end
    setupInfJump()
    if State.FreecamEnabled then disableFreecam() end
end)

-- SCAN
local function clearHL()
    for _, h in pairs(State.ScanHighlights) do
        pcall(function() if h and h.Parent then h:Destroy() end end)
    end
    State.ScanHighlights = {}
end

local function scanPlayers(range)
    clearHL()
    range = range or State.ScanRange
    local pos = State.FreecamEnabled and freecamPosition
        or (getHRP() and getHRP().Position or Vector3.zero)
    local count = 0
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - pos).Magnitude <= range then
                local hl = Instance.new("Highlight")
                hl.FillColor = Color3.fromRGB(255, 255, 0)
                hl.OutlineColor = Color3.fromRGB(255, 100, 0)
                hl.FillTransparency = 0.5
                hl.Adornee = p.Character
                hl.Parent = p.Character
                table.insert(State.ScanHighlights, hl)
                count = count + 1
            end
        end
    end
    notify("Scan", "Found "..count.." players", 3)
    task.delay(10, clearHL)
end

-- HELPERS
local function getPlayerList()
    local list = {"None"}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= Player then table.insert(list, p.Name) end
    end
    if #list == 1 then table.insert(list, "No Players") end
    return list
end

local function tpToCamera(safe)
    local hrp = getHRP()
    if not hrp then notify("Error", "No character", 3) return end
    if State.FreecamEnabled then disableFreecam() task.wait(0.15) end
    local tp = freecamPosition + (safe and Vector3.new(0,5,0) or Vector3.zero)
    if State.SmoothTeleport then
        TweenService:Create(hrp, TweenInfo.new(1, Enum.EasingStyle.Quad),
            {CFrame = CFrame.new(tp)}):Play()
    else
        hrp.CFrame = CFrame.new(tp)
    end
    notify("Teleport", safe and "Safe done!" or "Done!", 2)
end

-- FEEDBACK
local function sendFeedback(text)
    if not text or #text < 3 then notify("Error", "Min 3 chars!", 3) return end
    if not State.FeedbackAgreed then notify("Warning", "Accept rules first!", 4) return end
    local elapsed = tick() - State.LastFeedbackTime
    if elapsed < State.FeedbackCooldown then
        local rem = math.ceil(State.FeedbackCooldown - elapsed)
        notify("Cooldown", "Wait "..math.floor(rem/60).."m "..rem%60 .."s", 4)
        return
    end
    pcall(function()
        httpReq({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                embeds = {{
                    title = "Feedback v"..VERSION,
                    description = text,
                    color = 3447003,
                    fields = {
                        {name = "Player", value = Player.DisplayName.." (@"..Player.Name..")", inline = true},
                        {name = "UserID", value = tostring(Player.UserId), inline = true},
                        {name = "Platform", value = PLATFORM, inline = true},
                    },
                }}
            }),
        })
    end)
    State.LastFeedbackTime = tick()
    notify("Sent!", "Thank you! Next in 10 min.", 5)
end

-- SETUP
setupPCInput()
if IS_MOBILE then setupTouchRotation() end

-- WINDOW
local Window = Rayfield:CreateWindow({
    Name = "Freecam Hub v"..VERSION.." ("..PLATFORM..")",
    LoadingTitle = "Freecam Hub v"..VERSION,
    LoadingSubtitle = "Loading...",
    ConfigurationSaving = {Enabled = false},
    Discord = {Enabled = false},
    KeySystem = false,
})

-- MOVEMENT TAB
local MT = Window:CreateTab("Movement", 4483362458)

MT:CreateSection("Freecam")
MT:CreateToggle({
    Name = "Enable Freecam",
    CurrentValue = false,
    Flag = "FC",
    Callback = function(v)
        if v then enableFreecam() else disableFreecam() end
    end,
})
MT:CreateSlider({
    Name = "Fly Speed",
    Range = {5, 300}, Increment = 5, Suffix = " st/s",
    CurrentValue = State.FreecamSpeed, Flag = "FS",
    Callback = function(v) State.FreecamSpeed = v end,
})
MT:CreateToggle({
    Name = "Dynamic Speed",
    CurrentValue = State.DynamicSpeed, Flag = "DS",
    Callback = function(v) State.DynamicSpeed = v end,
})
MT:CreateToggle({
    Name = "Cinematic Mode",
    CurrentValue = State.CinematicMode, Flag = "CM",
    Callback = function(v) State.CinematicMode = v end,
})
MT:CreateToggle({
    Name = "Ghost Mode",
    CurrentValue = State.GhostMode, Flag = "GM",
    Callback = function(v)
        State.GhostMode = v
        if State.FreecamEnabled then setCharVisible(not v) end
    end,
})

MT:CreateSection("Auto Align")
MT:CreateToggle({
    Name = "Auto Align Yaw",
    CurrentValue = false, Flag = "AAY",
    Callback = function(v) State.AutoAlignCamera = v end,
})
MT:CreateToggle({
    Name = "Auto Align Pitch",
    CurrentValue = false, Flag = "AAP",
    Callback = function(v) State.AutoAlignPitch = v end,
})
MT:CreateSlider({
    Name = "Align Strength",
    Range = {1, 15}, Increment = 1, Suffix = "%",
    CurrentValue = 3, Flag = "AS",
    Callback = function(v) State.AutoAlignStrength = v / 100 end,
})

MT:CreateSection("Character")
MT:CreateToggle({
    Name = "Noclip",
    CurrentValue = State.NoclipEnabled, Flag = "NC",
    Callback = function(v)
        if v then enableNoclip() else disableNoclip() end
    end,
})
MT:CreateSlider({
    Name = "WalkSpeed",
    Range = {0, 500}, Increment = 1,
    CurrentValue = State.WalkSpeedValue, Flag = "WS",
    Callback = function(v)
        State.WalkSpeedValue = v
        if not State.FreecamEnabled then
            local h = getHum()
            if h then h.WalkSpeed = v end
        end
    end,
})
MT:CreateSlider({
    Name = "JumpPower",
    Range = {0, 500}, Increment = 1,
    CurrentValue = State.JumpPowerValue, Flag = "JP",
    Callback = function(v)
        State.JumpPowerValue = v
        local h = getHum()
        if h then h.JumpPower = v h.UseJumpPower = true end
    end,
})
MT:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = State.InfiniteJump, Flag = "IJ",
    Callback = function(v) State.InfiniteJump = v end,
})

-- CAMERA TAB
local CT = Window:CreateTab("Camera", 4483362458)

CT:CreateSection("Controls")
if IS_MOBILE then
    CT:CreateSlider({
        Name = "Touch Sensitivity",
        Range = {10, 100}, Increment = 5, Suffix = "%",
        CurrentValue = math.floor(State.TouchSensitivity * 100), Flag = "TS",
        Callback = function(v) State.TouchSensitivity = v / 100 end,
    })
    CT:CreateSlider({
        Name = "Roll Speed",
        Range = {5, 50}, Increment = 1,
        CurrentValue = math.floor(State.CameraRotSpeed * 10), Flag = "RLS",
        Callback = function(v) State.CameraRotSpeed = v / 10 end,
    })
    CT:CreateParagraph({
        Title = "Mobile Controls",
        Content = "Swipe (right 70%) = Rotate camera\nLeft side buttons = Roll (full 360)\nRight bottom = Fly Up / Down\nJoystick = Move\nTop center = Hide/Show UI",
    })
else
    CT:CreateSlider({
        Name = "Mouse Sensitivity",
        Range = {5, 100}, Increment = 5, Suffix = "%",
        CurrentValue = math.floor(State.PC_MouseSensitivity * 100), Flag = "MS",
        Callback = function(v) State.PC_MouseSensitivity = v / 100 end,
    })
    CT:CreateParagraph({
        Title = "PC Controls",
        Content = "Mouse = Rotate (Yaw/Pitch)\nWASD = Move\nSpace / Ctrl = Up / Down\nShift = Speed Boost x2.5\nF = Toggle Freecam\nR = Reset Camera Rotation",
    })
end

CT:CreateSection("FOV and Effects")
CT:CreateSlider({
    Name = "FOV",
    Range = {30, 120}, Increment = 1, Suffix = "deg",
    CurrentValue = State.FOV, Flag = "FOV",
    Callback = function(v)
        State.FOV = v
        if not State.DynamicFOV and not State.ChaosMode then
            Camera.FieldOfView = v
        end
    end,
})
CT:CreateToggle({
    Name = "Dynamic FOV",
    CurrentValue = State.DynamicFOV, Flag = "DFOV",
    Callback = function(v)
        State.DynamicFOV = v
        if not v then Camera.FieldOfView = State.FOV end
    end,
})
CT:CreateToggle({
    Name = "Camera Shake",
    CurrentValue = State.CameraShake, Flag = "CSH",
    Callback = function(v) State.CameraShake = v end,
})
CT:CreateToggle({
    Name = "Show Coordinates",
    CurrentValue = State.ShowCoords, Flag = "SC",
    Callback = function(v) State.ShowCoords = v end,
})

CT:CreateSection("Target")
CT:CreateDropdown({
    Name = "Follow Player",
    Options = getPlayerList(), CurrentOption = {"None"}, Flag = "FP",
    Callback = function(v)
        local s = v[1] or v
        State.FollowTarget = (s == "None" or s == "No Players") and nil or s
    end,
})
CT:CreateDropdown({
    Name = "Lock Target",
    Options = getPlayerList(), CurrentOption = {"None"}, Flag = "LT",
    Callback = function(v)
        local s = v[1] or v
        State.LockTarget = (s == "None" or s == "No Players") and nil or s
    end,
})

CT:CreateSection("Save and Load Position")
CT:CreateButton({
    Name = "Save Camera Position",
    Callback = function()
        if State.FreecamEnabled then
            State.SavedCameraPos  = freecamPosition
            State.SavedCameraLook = {
                yaw   = State.CameraYaw,
                pitch = State.CameraPitch,
                roll  = State.CameraRoll,
            }
        else
            State.SavedCameraPos  = Camera.CFrame.Position
            local lk = Camera.CFrame.LookVector
            State.SavedCameraLook = {
                yaw   = math.atan2(-lk.X, -lk.Z),
                pitch = math.asin(math.clamp(lk.Y, -1, 1)),
                roll  = 0,
            }
        end
        notify("Save", "Position saved!", 3)
    end,
})
CT:CreateButton({
    Name = "Load Camera Position",
    Callback = function()
        if not State.SavedCameraPos then
            notify("Load", "Nothing saved!", 3)
            return
        end
        if State.FreecamEnabled then
            freecamPosition   = State.SavedCameraPos
            if State.SavedCameraLook then
                State.CameraYaw   = State.SavedCameraLook.yaw
                State.CameraPitch = State.SavedCameraLook.pitch
                State.CameraRoll  = State.SavedCameraLook.roll or 0
            end
            notify("Load", "Position loaded!", 3)
        else
            notify("Load", "Enable Freecam first!", 3)
        end
    end,
})

-- PLAYER TAB
local PT = Window:CreateTab("Player", 4483362458)

PT:CreateSection("Teleport")
PT:CreateButton({
    Name = "Teleport to Camera",
    Callback = function() tpToCamera(false) end,
})
PT:CreateButton({
    Name = "Safe Teleport",
    Callback = function() tpToCamera(true) end,
})
PT:CreateToggle({
    Name = "Smooth Teleport",
    CurrentValue = false, Flag = "STP",
    Callback = function(v) State.SmoothTeleport = v end,
})

PT:CreateSection("Character")
PT:CreateButton({
    Name = "Reset Character",
    Callback = function()
        if State.FreecamEnabled then disableFreecam() end
        local h = getHum()
        if h then h.Health = 0 end
    end,
})
PT:CreateButton({
    Name = "Player Info",
    Callback = function()
        local h = getHum()
        local hrp = getHRP()
        if h and hrp then
            local p = hrp.Position
            notify("Info",
                "Speed: "..math.floor(h.WalkSpeed)
                .." | Jump: "..math.floor(h.JumpPower)
                .."\nHP: "..math.floor(h.Health).."/"..math.floor(h.MaxHealth)
                .."\nPos: "..math.floor(p.X)..", "..math.floor(p.Y)..", "..math.floor(p.Z)
                .."\n"..PLATFORM, 6)
        end
    end,
})

-- FUN TAB
local FT = Window:CreateTab("Fun", 4483362458)

FT:CreateToggle({
    Name = "Chaos Mode",
    CurrentValue = false, Flag = "CH",
    Callback = function(v)
        State.ChaosMode = v
        if not v then Camera.FieldOfView = State.FOV end
    end,
})
FT:CreateButton({
    Name = "Scan Players",
    Callback = function() scanPlayers(State.ScanRange) end,
})
FT:CreateSlider({
    Name = "Scan Range",
    Range = {50, 500}, Increment = 10, Suffix = " studs",
    CurrentValue = 200, Flag = "SR",
    Callback = function(v) State.ScanRange = v end,
})
FT:CreateButton({
    Name = "Clear Highlights",
    Callback = function() clearHL() end,
})

-- SETTINGS TAB
local ST = Window:CreateTab("Settings", 4483362458)

ST:CreateSection("Feedback")
ST:CreateParagraph({
    Title = "FEEDBACK RULES",
    Content = "Send RELEVANT feedback only (bugs, suggestions).\n\n"
        .."1st offense: 30 min ban\n"
        .."2nd offense: 1 day ban\n"
        .."3rd offense: Permanent ban\n\n"
        .."Good: 'Freecam lags on mobile'\n"
        .."Bad: Spam or insults",
})
ST:CreateToggle({
    Name = "I agree to the rules",
    CurrentValue = false, Flag = "FBA",
    Callback = function(v) State.FeedbackAgreed = v end,
})
ST:CreateInput({
    Name = "Feedback",
    PlaceholderText = "Bug or suggestion...",
    RemoveTextAfterFocusLost = false,
    Flag = "FBI",
    Callback = function(t) State.FeedbackText = t end,
})
ST:CreateButton({
    Name = "Send Feedback",
    Callback = function()
        local t = State.FeedbackText
        if (not t or t == "") and Rayfield.Flags["FBI"] then
            t = Rayfield.Flags["FBI"].CurrentValue or ""
        end
        sendFeedback(t)
    end,
})

ST:CreateSection("Save System")
ST:CreateButton({
    Name = "Save All Settings",
    Callback = function()
        saveSettings(State)
        notify("Save", "Settings saved!", 3)
    end,
})
ST:CreateButton({
    Name = "Load Settings",
    Callback = function()
        local d = loadSettings()
        if d then
            for k, v in pairs(d) do
                if State[k] ~= nil then State[k] = v end
            end
            notify("Load", "Settings loaded!", 3)
        else
            notify("Load", "No saved settings found", 3)
        end
    end,
})

ST:CreateSection("System")
ST:CreateButton({
    Name = "Reset All Settings",
    Callback = function()
        if State.FreecamEnabled then disableFreecam() end
        if State.NoclipEnabled then disableNoclip() end
        State.InfiniteJump    = false
        State.ChaosMode       = false
        State.DynamicFOV      = false
        State.CameraShake     = false
        State.GhostMode       = false
        State.CinematicMode   = false
        State.AutoAlignCamera = false
        State.AutoAlignPitch  = false
        State.DynamicSpeed    = true
        State.SmoothTeleport  = false
        State.FollowTarget    = nil
        State.LockTarget      = nil
        State.WalkSpeedValue  = 16
        State.JumpPowerValue  = 50
        State.FOV             = 70
        State.CameraRoll      = 0
        local h = getHum()
        if h then h.WalkSpeed = 16 h.JumpPower = 50 end
        Camera.FieldOfView    = 70
        Camera.CameraType     = Enum.CameraType.Custom
        clearHL()
        if IS_PC then unlockMouse() resetKeys() end
        notify("Reset", "Done!", 4)
    end,
})

ST:CreateSection("Changelog")
ST:CreateParagraph({
    Title = "v2.0 - Current",
    Content = "New Camera System\n"
        .."- Mobile: Swipe to rotate\n"
        .."- PC: Mouse to rotate\n"
        .."- Roll axis (full 360 deg)\n\n"
        .."New Mobile UI\n"
        .."- Circle fly buttons bottom right\n"
        .."- Roll buttons left side\n"
        .."- No background panels\n\n"
        .."PC Hotkeys\n"
        .."- F = Toggle, Shift = Boost, R = Reset\n\n"
        .."Coordinate Display\n"
        .."Save and Load Settings",
})
ST:CreateParagraph({
    Title = "v1.1 - Previous",
    Content = "Online ban system\n"
        .."Hide UI button\n"
        .."Drag UI panels\n"
        .."Fixed mobile buttons\n"
        .."Fixed joystick movement",
})
ST:CreateParagraph({
    Title = "Freecam Hub v"..VERSION,
    Content = "Platform: "..PLATFORM.."\nBan System: Online\nDelta Executor Compatible",
})

-- CLEANUP
pcall(function()
    game:GetService("CoreGui").ChildRemoved:Connect(function(child)
        if child.Name == "Rayfield" then
            if State.FreecamEnabled then disableFreecam() end
            if State.NoclipEnabled then disableNoclip() end
            disconnectAll()
            destroyAllUI()
            clearHL()
            Camera.CameraType  = Enum.CameraType.Custom
            Camera.FieldOfView = 70
            anchorChar(false)
            setCharVisible(true)
            if IS_PC then unlockMouse() resetKeys() end
            pcall(function()
                local h = getHum()
                if h then h.WalkSpeed = 16 h.JumpPower = 50 end
            end)
        end
    end)
end)

-- INIT
Camera.FieldOfView = State.FOV

notify(
    "Freecam Hub v"..VERSION,
    PLATFORM.."\n"
    ..(IS_MOBILE
        and "Swipe = Rotate | Fly btns = Right | Roll = Left"
        or  "F = Freecam | Mouse = Rotate | Shift = Boost | R = Reset"),
    7
)
