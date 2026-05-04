--[[
    ╔══════════════════════════════════════════╗
    ║     FREECAM HUB v2.0 (Public Release)   ║
    ║   Touch/Mouse Camera Rotation           ║
    ║   Roll Axis (Z rotation)                ║
    ║   Minimal Mobile UI                     ║
    ║   PC Hotkeys (F, Shift, R)              ║
    ║   Save/Load Settings                    ║
    ║   Coordinate Display                    ║
    ╚══════════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local VERSION = "2.0"

-- BAN
local BAN_API_URL = "https://ban-management-system.onrender.com/api/banlist"
local OnlineBanList = {}

-- PLATFORM
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
local IS_PC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
local PLATFORM = IS_MOBILE and "Mobile" or "PC"

-- WEBHOOK
local WEBHOOK_URL = "https://discord.com/api/webhooks/1446147402275749916/m5eZ12l6RKrjSGJKuVnxRyKBb4mQIqlVQJloX9dhfQ6Ue1lCNRwYwjJxGuqCdGh2MrDO"

-- CHARACTER
local function getChar() return Player.Character end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- HTTP
local function httpReq(opt)
    local fn = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
    if fn then local ok, r = pcall(fn, opt) if ok then return r end end
    return nil
end

local function httpGet(url)
    local ok, r = pcall(function() return game:HttpGet(url) end)
    if ok and r then return r end
    local resp = httpReq({Url = url, Method = "GET"})
    return resp and resp.Body
end

-- BAN CHECK
local function fetchBans()
    local raw = httpGet(BAN_API_URL)
    if not raw then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and data and data.bans then OnlineBanList = data.bans return true end
    return false
end

local function checkBan()
    local id = tostring(Player.UserId)
    if not OnlineBanList[id] then return false end
    local info = OnlineBanList[id]
    if info.expiresAt and info.expiresAt ~= "null" and info.expiresAt ~= "" then
        local ok, exp = pcall(function()
            local y,m,d,h,mn,s = info.expiresAt:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            if y then return os.time({year=tonumber(y),month=tonumber(m),day=tonumber(d),hour=tonumber(h),min=tonumber(mn),sec=tonumber(s)}) end
        end)
        if ok and exp and os.time() > exp then return false end
    end
    Player:Kick("\n🚫 BANNED 🚫\nReason: "..(info.reason or "N/A").."\nBy: "..(info.bannedBy or "Admin"))
    return true
end

pcall(fetchBans)
if checkBan() then return end
task.spawn(function() while true do task.wait(60) pcall(function() fetchBans() checkBan() end) end end)

-- RAYFIELD
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local function notify(t,c,d) pcall(function() Rayfield:Notify({Title=t or"",Content=c or"",Duration=d or 4}) end) end

-- SAVE/LOAD SETTINGS
local SAVE_KEY = "FreecamHub_v2_Settings"

local function saveSettings()
    pcall(function()
        local data = {
            FreecamSpeed = State.FreecamSpeed,
            FOV = State.FOV,
            WalkSpeed = State.WalkSpeedValue,
            JumpPower = State.JumpPowerValue,
            DynamicSpeed = State.DynamicSpeed,
            CinematicMode = State.CinematicMode,
            GhostMode = State.GhostMode,
            Noclip = State.NoclipEnabled,
            InfiniteJump = State.InfiniteJump,
            DynamicFOV = State.DynamicFOV,
            CameraShake = State.CameraShake,
            ShowCoords = State.ShowCoords,
            CameraRotSpeed = State.CameraRotSpeed,
            MouseSensitivity = State.PC_MouseSensitivity,
            TouchSensitivity = State.TouchSensitivity,
        }
        if writefile then
            writefile(SAVE_KEY .. ".json", HttpService:JSONEncode(data))
        end
    end)
end

local function loadSettings()
    local data = nil
    pcall(function()
        if isfile and isfile(SAVE_KEY .. ".json") then
            local raw = readfile(SAVE_KEY .. ".json")
            data = HttpService:JSONDecode(raw)
        end
    end)
    return data
end

-- STATE
local State = {
    FreecamEnabled = false,
    FreecamSpeed = 50,
    FreecamGoingUp = false,
    FreecamGoingDown = false,
    CinematicMode = false,
    GhostMode = false,
    DynamicSpeed = true,
    AutoAlignCamera = false,
    AutoAlignStrength = 0.03,
    AutoAlignPitch = false,

    FlyUIEnabled = true,
    RollUIEnabled = true,
    UIHidden = false,

    CameraRotSpeed = 2,
    RotatingUp = false,
    RotatingDown = false,
    RotatingLeft = false,
    RotatingRight = false,
    RollingLeft = false,
    RollingRight = false,

    FOV = 70,
    DynamicFOV = false,
    CameraShake = false,
    SmoothTeleport = false,

    NoclipEnabled = false,
    WalkSpeedValue = 16,
    JumpPowerValue = 50,
    InfiniteJump = false,

    FollowTarget = nil,
    LockTarget = nil,
    SavedCameraPos = nil,
    SavedCameraLook = nil,

    ChaosMode = false,
    ScanHighlights = {},
    ScanRange = 200,

    Connections = {},
    CameraPitch = 0,
    CameraYaw = 0,
    CameraRoll = 0,

    PC_Keys = {
        W = false, A = false, S = false, D = false,
        Space = false, LeftControl = false, LeftShift = false,
    },
    PC_MouseSensitivity = 0.3,
    PC_MouseLocked = false,
    PC_SpeedBoost = false,

    TouchSensitivity = 0.4,
    TouchRotating = false,
    TouchStartPos = nil,

    ShowCoords = true,

    LastFeedbackTime = 0,
    FeedbackCooldown = 600,
    FeedbackText = "",
    FeedbackAgreed = false,
}

-- Apply saved settings
local saved = loadSettings()
if saved then
    for k, v in pairs(saved) do
        if State[k] ~= nil then State[k] = v end
    end
end

local freecamPosition = Vector3.zero
local freecamVelocity = Vector3.zero

-- CONNECTIONS
local function disconnectKey(k)
    local c = State.Connections[k]
    if c and typeof(c) == "RBXScriptConnection" and c.Connected then c:Disconnect() end
    State.Connections[k] = nil
end

local function disconnectAll()
    for k,c in pairs(State.Connections) do
        if typeof(c) == "RBXScriptConnection" and c.Connected then c:Disconnect() end
    end
    State.Connections = {}
end

-- CHAR HELPERS
local function getMoveDir()
    local h = getHum()
    return h and h.MoveDirection or Vector3.zero
end

local function anchorChar(a)
    pcall(function()
        local c = getChar() if not c then return end
        for _,p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.Anchored = a end
        end
    end)
end

local function setCharVisible(v)
    pcall(function()
        local c = getChar() if not c then return end
        for _,p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.Transparency = v and 0 or 1
            elseif p:IsA("Decal") then p.Transparency = v and 0 or 1 end
        end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Transparency = 1 end
    end)
end

-- MATH
local function normAngle(a)
    while a > math.pi do a = a - 2*math.pi end
    while a < -math.pi do a = a + 2*math.pi end
    return a
end

local function shortAngleDiff(f,t) return normAngle(t-f) end
local function lerpAngle(f,t,a) return f + shortAngleDiff(f,t) * math.clamp(a,0,1) end

-- PC INPUT
local function setupPCInput()
    if not IS_PC then return end
    disconnectKey("PCKeyDown")
    disconnectKey("PCKeyUp")
    disconnectKey("PCMouse")

    State.Connections["PCKeyDown"] = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        local k = input.KeyCode

        -- Hotkey F = toggle freecam
        if k == Enum.KeyCode.F and not State.FreecamEnabled then
            enableFreecam()
            return
        elseif k == Enum.KeyCode.F and State.FreecamEnabled then
            disableFreecam()
            return
        end

        -- Hotkey R = reset camera rotation
        if k == Enum.KeyCode.R and State.FreecamEnabled then
            State.CameraPitch = 0
            State.CameraYaw = 0
            State.CameraRoll = 0
            notify("Camera", "Rotation reset", 2)
            return
        end

        if not State.FreecamEnabled then return end

        local name = k.Name
        if State.PC_Keys[name] ~= nil then State.PC_Keys[name] = true end

        -- Shift = speed boost
        if k == Enum.KeyCode.LeftShift then
            State.PC_SpeedBoost = true
        end
    end)

    State.Connections["PCKeyUp"] = UserInputService.InputEnded:Connect(function(input)
        local name = input.KeyCode.Name
        if State.PC_Keys[name] ~= nil then State.PC_Keys[name] = false end
        if input.KeyCode == Enum.KeyCode.LeftShift then
            State.PC_SpeedBoost = false
        end
    end)

    State.Connections["PCMouse"] = UserInputService.InputChanged:Connect(function(input, gp)
        if gp or not State.FreecamEnabled or not State.PC_MouseLocked then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Delta
            local s = State.PC_MouseSensitivity / 100
            State.CameraYaw = normAngle(State.CameraYaw - d.X * s)
            State.CameraPitch = math.clamp(State.CameraPitch - d.Y * s, -math.rad(89), math.rad(89))
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
    for k in pairs(State.PC_Keys) do State.PC_Keys[k] = false end
    State.PC_SpeedBoost = false
end

local function getPCMove()
    local f,r,u = 0,0,0
    if State.PC_Keys.W then f=f+1 end
    if State.PC_Keys.S then f=f-1 end
    if State.PC_Keys.D then r=r+1 end
    if State.PC_Keys.A then r=r-1 end
    if State.PC_Keys.Space then u=u+1 end
    if State.PC_Keys.LeftControl then u=u-1 end
    return f,r,u
end

-- TOUCH ROTATION (MOBILE - swipe to rotate)
local function setupTouchRotation()
    if not IS_MOBILE then return end
    disconnectKey("TouchBegan")
    disconnectKey("TouchMoved")
    disconnectKey("TouchEnded")

    local activeTouchId = nil

    State.Connections["TouchBegan"] = UserInputService.TouchStarted:Connect(function(touch, gp)
        if gp then return end
        if not State.FreecamEnabled then return end
        if activeTouchId then return end

        -- Only use right side of screen for rotation
        local screenSize = Camera.ViewportSize
        if touch.Position.X > screenSize.X * 0.3 then
            activeTouchId = touch
            State.TouchStartPos = touch.Position
        end
    end)

    State.Connections["TouchMoved"] = UserInputService.TouchMoved:Connect(function(touch, gp)
        if gp then return end
        if not State.FreecamEnabled then return end
        if touch ~= activeTouchId then return end

        local delta = touch.Position - State.TouchStartPos
        State.TouchStartPos = touch.Position

        local sens = State.TouchSensitivity / 100

        State.CameraYaw = normAngle(State.CameraYaw - delta.X * sens)
        State.CameraPitch = math.clamp(State.CameraPitch - delta.Y * sens, -math.rad(89), math.rad(89))
    end)

    State.Connections["TouchEnded"] = UserInputService.TouchEnded:Connect(function(touch)
        if touch == activeTouchId then
            activeTouchId = nil
        end
    end)
end

-- MOBILE UI ELEMENTS
local FreecamGuis = {}

local function destroyAllUI()
    State.FreecamGoingUp = false
    State.FreecamGoingDown = false
    State.RollingLeft = false
    State.RollingRight = false
    State.UIHidden = false

    for _, gui in pairs(FreecamGuis) do
        pcall(function() if gui and gui.Parent then gui:Destroy() end end)
    end
    FreecamGuis = {}
end

local function createCircleButton(parent, name, text, size, position, color, zindex)
    local btn = Instance.new("ImageButton")
    btn.Name = name
    btn.Size = size
    btn.Position = position
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.15
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Active = true
    btn.ZIndex = zindex or 10
    btn.Image = ""
    btn.Parent = parent

    Instance.new("UICorner", btn).CornerRadius = UDim.new(0.5, 0)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextSize = 28
    label.Font = Enum.Font.GothamBold
    label.ZIndex = (zindex or 10) + 1
    label.Parent = btn

    return btn
end

local function hookHold(btn, stateKey, pressColor, releaseColor)
    local holding = false

    local function startH()
        if holding then return end
        holding = true
        State[stateKey] = true
        btn.BackgroundColor3 = pressColor
    end

    local function endH()
        if not holding then return end
        holding = false
        State[stateKey] = false
        btn.BackgroundColor3 = releaseColor
    end

    btn.MouseButton1Down:Connect(startH)
    btn.MouseButton1Up:Connect(endH)

    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then startH() end
    end)

    btn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            endH()
        end
    end)

    btn.MouseLeave:Connect(endH)
end

local function createMobileUI()
    if IS_PC then return end
    destroyAllUI()

    -- GUI container
    local gui = Instance.new("ScreenGui")
    gui.Name = "FCMobileUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 110
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- ============================================
    -- RIGHT SIDE: Fly Up (like jump button) + Fly Down
    -- ============================================

    -- FLY UP - bottom right (like Roblox jump button position)
    local flyUpBtn = createCircleButton(gui, "FlyUp", "▲", 
        UDim2.new(0, 70, 0, 70),
        UDim2.new(1, -90, 1, -110),
        Color3.fromRGB(50, 130, 255), 10)
    hookHold(flyUpBtn, "FreecamGoingUp",
        Color3.fromRGB(80, 170, 255),
        Color3.fromRGB(50, 130, 255))

    -- FLY DOWN - left of fly up (flipped arrow)
    local flyDownBtn = createCircleButton(gui, "FlyDown", "▼",
        UDim2.new(0, 70, 0, 70),
        UDim2.new(1, -175, 1, -110),
        Color3.fromRGB(220, 60, 60), 10)
    hookHold(flyDownBtn, "FreecamGoingDown",
        Color3.fromRGB(255, 100, 100),
        Color3.fromRGB(220, 60, 60))

    -- ============================================
    -- LEFT SIDE: Roll buttons (curved arrows)
    -- ============================================

    -- ROLL LEFT
    local rollLeftBtn = createCircleButton(gui, "RollLeft", "↺",
        UDim2.new(0, 60, 0, 60),
        UDim2.new(0, 15, 0.5, -70),
        Color3.fromRGB(60, 60, 100), 10)
    hookHold(rollLeftBtn, "RollingLeft",
        Color3.fromRGB(100, 100, 160),
        Color3.fromRGB(60, 60, 100))

    -- ROLL RIGHT
    local rollRightBtn = createCircleButton(gui, "RollRight", "↻",
        UDim2.new(0, 60, 0, 60),
        UDim2.new(0, 15, 0.5, 10),
        Color3.fromRGB(60, 60, 100), 10)
    hookHold(rollRightBtn, "RollingRight",
        Color3.fromRGB(100, 100, 160),
        Color3.fromRGB(60, 60, 100))

    -- ============================================
    -- HIDE BUTTON (top center)
    -- ============================================
    local hideBtn = Instance.new("TextButton")
    hideBtn.Size = UDim2.new(0, 44, 0, 44)
    hideBtn.Position = UDim2.new(0.5, -22, 0, 8)
    hideBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    hideBtn.BackgroundTransparency = 0.3
    hideBtn.Text = "🙈"
    hideBtn.TextSize = 20
    hideBtn.TextColor3 = Color3.fromRGB(255,255,255)
    hideBtn.Font = Enum.Font.GothamBold
    hideBtn.BorderSizePixel = 0
    hideBtn.ZIndex = 15
    hideBtn.Active = true
    hideBtn.Parent = gui
    Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0.5, 0)

    hideBtn.MouseButton1Click:Connect(function()
        State.UIHidden = not State.UIHidden
        hideBtn.Text = State.UIHidden and "👁️" or "🙈"
        flyUpBtn.Visible = not State.UIHidden
        flyDownBtn.Visible = not State.UIHidden
        rollLeftBtn.Visible = not State.UIHidden
        rollRightBtn.Visible = not State.UIHidden
    end)

    gui.Parent = Player:FindFirstChildOfClass("PlayerGui")
    table.insert(FreecamGuis, gui)
end

-- COORDINATE DISPLAY
local CoordsGui = nil

local function createCoordsUI()
    if CoordsGui then CoordsGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "FCCoords"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 108

    local label = Instance.new("TextLabel")
    label.Name = "CoordsLabel"
    label.Size = UDim2.new(0, 200, 0, 30)
    label.Position = UDim2.new(0.5, -100, 0, IS_MOBILE and 55 or 5)
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.BackgroundTransparency = 0.6
    label.BorderSizePixel = 0
    label.Text = "X: 0 | Y: 0 | Z: 0"
    label.TextColor3 = Color3.fromRGB(200, 220, 255)
    label.TextSize = 12
    label.Font = Enum.Font.RobotoMono
    label.ZIndex = 5
    label.Parent = gui

    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)

    gui.Parent = Player:FindFirstChildOfClass("PlayerGui")
    CoordsGui = gui
    table.insert(FreecamGuis, gui)
end

local function updateCoords()
    if not CoordsGui then return end
    local label = CoordsGui:FindFirstChild("CoordsLabel")
    if not label then return end

    if not State.ShowCoords or not State.FreecamEnabled then
        label.Visible = false
        return
    end

    label.Visible = true
    local p = freecamPosition
    label.Text = string.format("X: %d | Y: %d | Z: %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
end

-- FREECAM
function enableFreecam()
    if State.FreecamEnabled then return end
    pcall(function() fetchBans() if checkBan() then return end end)

    State.FreecamEnabled = true
    disconnectKey("FCRender")

    local cf = Camera.CFrame
    freecamPosition = cf.Position
    freecamVelocity = Vector3.zero

    local look = cf.LookVector
    State.CameraYaw = math.atan2(-look.X, -look.Z)
    State.CameraPitch = math.asin(math.clamp(look.Y, -1, 1))
    State.CameraRoll = 0

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

    -- MAIN LOOP
    State.Connections["FCRender"] = RunService.RenderStepped:Connect(function(dt)
        if not State.FreecamEnabled then return end

        -- ROLL
        local rollSpeed = State.CameraRotSpeed * dt
        if State.RollingLeft then
            State.CameraRoll = State.CameraRoll + rollSpeed
        end
        if State.RollingRight then
            State.CameraRoll = State.CameraRoll - rollSpeed
        end

        -- Normalize roll to allow full 360
        State.CameraRoll = normAngle(State.CameraRoll)

        -- YAW/PITCH already handled by touch/mouse
        State.CameraYaw = normAngle(State.CameraYaw)

        -- CAMERA VECTORS (without roll for movement)
        local moveRot = CFrame.Angles(0, State.CameraYaw, 0) * CFrame.Angles(State.CameraPitch, 0, 0)
        local camLook = moveRot.LookVector
        local camRight = moveRot.RightVector
        local camUp = Vector3.new(0, 1, 0)

        -- MOVEMENT
        local moveVec = Vector3.zero
        local isMoving = false
        local inputMag = 1

        if IS_PC then
            local fw, rt, up = getPCMove()
            if fw ~= 0 or rt ~= 0 then
                moveVec = (camLook * fw) + (camRight * rt)
                isMoving = true
            end
            if up ~= 0 then moveVec = moveVec + camUp * up isMoving = true end
        else
            local hum2 = getHum()
            if hum2 then
                local md = hum2.MoveDirection
                if md.Magnitude > 0.01 then
                    isMoving = true
                    inputMag = math.clamp(md.Magnitude, 0.1, 1)

                    local cff = Vector3.new(camLook.X, 0, camLook.Z)
                    cff = cff.Magnitude > 0.001 and cff.Unit or Vector3.new(0,0,-1)
                    local crf = Vector3.new(camRight.X, 0, camRight.Z)
                    crf = crf.Magnitude > 0.001 and crf.Unit or Vector3.new(1,0,0)

                    moveVec = (camLook * md:Dot(cff)) + (camRight * md:Dot(crf))
                end
            end

            if State.FreecamGoingUp then moveVec = moveVec + camUp isMoving = true end
            if State.FreecamGoingDown then moveVec = moveVec - camUp isMoving = true end
        end

        if moveVec.Magnitude > 1 then moveVec = moveVec.Unit end

        -- SPEED
        local speed = State.FreecamSpeed
        if State.DynamicSpeed and IS_MOBILE then speed = speed * inputMag end
        if State.CinematicMode then speed = speed * 0.3 end
        if State.PC_SpeedBoost then speed = speed * 2.5 end

        local targetVel = moveVec * speed
        freecamVelocity = State.CinematicMode and freecamVelocity:Lerp(targetVel, 0.08) or targetVel
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
                    State.CameraPitch = math.clamp(State.CameraPitch + pd * State.AutoAlignStrength * 0.5, -math.rad(89), math.rad(89))
                end
            end
        end

        -- FOLLOW
        if State.FollowTarget then
            local tp = Players:FindFirstChild(State.FollowTarget)
            if tp and tp.Character then
                local thrp = tp.Character:FindFirstChild("HumanoidRootPart")
                if thrp then
                    freecamPosition = thrp.Position + Vector3.new(0,10,15)
                    local dir = (thrp.Position - freecamPosition)
                    if dir.Magnitude > 0.1 then
                        dir = dir.Unit
                        State.CameraYaw = lerpAngle(State.CameraYaw, math.atan2(-dir.X,-dir.Z), 0.1)
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
                        State.CameraYaw = lerpAngle(State.CameraYaw, math.atan2(-dir.X,-dir.Z), 0.15)
                        State.CameraPitch = math.clamp(State.CameraPitch + (math.asin(math.clamp(dir.Y,-1,1)) - State.CameraPitch) * 0.15, -math.rad(89), math.rad(89))
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
            shake = Vector3.new((math.random()-0.5)*i,(math.random()-0.5)*i,(math.random()-0.5)*i)
        end

        if State.ChaosMode then
            Camera.FieldOfView = math.random(40,110)
            shake = shake + Vector3.new((math.random()-0.5)*0.4,(math.random()-0.5)*0.4,0)
        end

        -- APPLY CAMERA (Yaw * Pitch * Roll - separate axes)
        State.CameraPitch = math.clamp(State.CameraPitch, -math.rad(89), math.rad(89))

        local yawCF = CFrame.Angles(0, State.CameraYaw, 0)
        local pitchCF = CFrame.Angles(State.CameraPitch, 0, 0)
        local rollCF = CFrame.Angles(0, 0, State.CameraRoll)

        Camera.CFrame = CFrame.new(freecamPosition + shake) * yawCF * pitchCF * rollCF

        -- UPDATE COORDS
        updateCoords()
    end)

    local ctrl = IS_PC and "WASD+Mouse | F=Toggle | Shift=Boost | R=Reset" or "Swipe=Rotate | Joystick=Move"
    notify("Freecam ON ✅", PLATFORM .. "\n" .. ctrl, 5)
end

function disableFreecam()
    if not State.FreecamEnabled then return end
    State.FreecamEnabled = false

    disconnectKey("FCRender")
    disconnectKey("TouchBegan")
    disconnectKey("TouchMoved")
    disconnectKey("TouchEnded")

    State.FreecamGoingUp = false
    State.FreecamGoingDown = false
    State.RollingLeft = false
    State.RollingRight = false
    freecamVelocity = Vector3.zero
    State.CameraRoll = 0

    anchorChar(false)

    local hum = getHum()
    if hum then hum.WalkSpeed = State.WalkSpeedValue end

    if State.GhostMode then setCharVisible(true) end

    Camera.CameraType = Enum.CameraType.Custom
    pcall(function() Camera.CameraSubject = getHum() end)
    if not State.DynamicFOV and not State.ChaosMode then Camera.FieldOfView = State.FOV end

    if IS_PC then unlockMouse() resetKeys() end

    destroyAllUI()

    -- Save settings on disable
    saveSettings()

    notify("Freecam", "OFF ❌", 3)
end

-- NOCLIP
local function enableNoclip()
    disconnectKey("NoclipStep")
    State.NoclipEnabled = true
    State.Connections["NoclipStep"] = RunService.Stepped:Connect(function()
        if not State.NoclipEnabled then return end
        local c = getChar() if not c then return end
        for _,p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
    notify("Noclip","ON ✅",3)
end

local function disableNoclip()
    State.NoclipEnabled = false
    disconnectKey("NoclipStep")
    pcall(function()
        local c = getChar() if not c then return end
        for _,p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
        end
    end)
    notify("Noclip","OFF ❌",3)
end

-- INFINITE JUMP
local function setupInfJump()
    disconnectKey("InfJump")
    State.Connections["InfJump"] = UserInputService.JumpRequest:Connect(function()
        if not State.InfiniteJump then return end
        local h = getHum() if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end
setupInfJump()

-- RESPAWN
Player.CharacterAdded:Connect(function()
    task.wait(0.5)
    pcall(function() fetchBans() checkBan() end)
    local h = getHum() if not h then return end
    if State.WalkSpeedValue ~= 16 then h.WalkSpeed = State.WalkSpeedValue end
    if State.JumpPowerValue ~= 50 then h.JumpPower = State.JumpPowerValue h.UseJumpPower = true end
    if State.NoclipEnabled then enableNoclip() end
    setupInfJump()
    if State.FreecamEnabled then disableFreecam() end
end)

-- SCAN
local function clearHL()
    for _,h in pairs(State.ScanHighlights) do pcall(function() if h and h.Parent then h:Destroy() end end) end
    State.ScanHighlights = {}
end

local function scanPlayers(range)
    clearHL()
    range = range or State.ScanRange
    local pos = State.FreecamEnabled and freecamPosition or ((getHRP() and getHRP().Position) or Vector3.zero)
    local count = 0
    for _,p in pairs(Players:GetPlayers()) do
        if p ~= Player and p.Character then
            local h = p.Character:FindFirstChild("HumanoidRootPart")
            if h and (h.Position - pos).Magnitude <= range then
                local hl = Instance.new("Highlight")
                hl.FillColor = Color3.fromRGB(255,255,0)
                hl.OutlineColor = Color3.fromRGB(255,100,0)
                hl.FillTransparency = 0.5
                hl.Adornee = p.Character
                hl.Parent = p.Character
                table.insert(State.ScanHighlights, hl)
                count = count + 1
            end
        end
    end
    notify("Scan","Found "..count.." players",3)
    task.delay(10, clearHL)
end

-- HELPERS
local function getPlayerList()
    local l = {"None"}
    for _,p in pairs(Players:GetPlayers()) do if p ~= Player then table.insert(l, p.Name) end end
    if #l == 1 then table.insert(l,"No Players") end
    return l
end

local function tpToCamera(safe)
    local hrp = getHRP() if not hrp then return end
    if State.FreecamEnabled then disableFreecam() task.wait(0.15) end
    local tp = freecamPosition + (safe and Vector3.new(0,5,0) or Vector3.zero)
    if State.SmoothTeleport then
        TweenService:Create(hrp,TweenInfo.new(1,Enum.EasingStyle.Quad),{CFrame=CFrame.new(tp)}):Play()
    else hrp.CFrame = CFrame.new(tp) end
    notify("Teleport",safe and "Safe ✅" or "Done ✅",2)
end

local function sendFeedback(text)
    if not text or #text < 3 then notify("❌","Min 3 chars!",3) return end
    if not State.FeedbackAgreed then notify("⚠️","Accept rules first!",4) return end
    local el = tick() - State.LastFeedbackTime
    if el < State.FeedbackCooldown then
        local r = math.ceil(State.FeedbackCooldown - el)
        notify("⏳","Wait "..math.floor(r/60).."m "..r%60 .."s",4) return
    end
    pcall(function()
        httpReq({Url=WEBHOOK_URL,Method="POST",Headers={["Content-Type"]="application/json"},
            Body=HttpService:JSONEncode({embeds={{title="📩 Feedback v"..VERSION,description=text,color=3447003,
                fields={{name="👤",value=Player.DisplayName.." (@"..Player.Name..")",inline=true},
                    {name="🆔",value=tostring(Player.UserId),inline=true},{name="📱",value=PLATFORM,inline=true}}}}})})
    end)
    State.LastFeedbackTime = tick()
    notify("✅","Sent! Next in 10 min.",5)
end

-- SETUP
setupPCInput()
if IS_MOBILE then setupTouchRotation() end

-- WINDOW
local Window = Rayfield:CreateWindow({
    Name = "🎮 Freecam Hub v"..VERSION.." ("..PLATFORM..")",
    LoadingTitle = "Freecam Hub v"..VERSION,
    LoadingSubtitle = PLATFORM,
    ConfigurationSaving = {Enabled = false},
    Discord = {Enabled = false},
    KeySystem = false,
})

-- MOVEMENT TAB
local MT = Window:CreateTab("🏃 Movement", 4483362458)
MT:CreateSection("✈️ Freecam")
MT:CreateToggle({Name="✈️ Enable Freecam",CurrentValue=false,Flag="FC",Callback=function(v) if v then enableFreecam() else disableFreecam() end end})
MT:CreateSlider({Name="🚀 Fly Speed",Range={5,300},Increment=5,Suffix=" studs/s",CurrentValue=State.FreecamSpeed,Flag="FS",Callback=function(v) State.FreecamSpeed=v end})
MT:CreateToggle({Name="📊 Dynamic Speed",CurrentValue=State.DynamicSpeed,Flag="DS",Callback=function(v) State.DynamicSpeed=v end})
MT:CreateToggle({Name="🎬 Cinematic Mode",CurrentValue=State.CinematicMode,Flag="CM",Callback=function(v) State.CinematicMode=v end})
MT:CreateToggle({Name="👻 Ghost Mode",CurrentValue=State.GhostMode,Flag="GM",Callback=function(v) State.GhostMode=v if State.FreecamEnabled then setCharVisible(not v) end end})

MT:CreateSection("🧭 Auto Align")
MT:CreateToggle({Name="🧭 Yaw Align",CurrentValue=false,Flag="AAY",Callback=function(v) State.AutoAlignCamera=v end})
MT:CreateToggle({Name="📐 Pitch Align",CurrentValue=false,Flag="AAP",Callback=function(v) State.AutoAlignPitch=v end})
MT:CreateSlider({Name="🧭 Strength",Range={1,15},Increment=1,Suffix="%",CurrentValue=3,Flag="AS",Callback=function(v) State.AutoAlignStrength=v/100 end})

MT:CreateSection("🔧 Character")
MT:CreateToggle({Name="👤 Noclip",CurrentValue=State.NoclipEnabled,Flag="NC",Callback=function(v) if v then enableNoclip() else disableNoclip() end end})
MT:CreateSlider({Name="🏃 WalkSpeed",Range={0,500},Increment=1,CurrentValue=State.WalkSpeedValue,Flag="WS",Callback=function(v) State.WalkSpeedValue=v if not State.FreecamEnabled then local h=getHum() if h then h.WalkSpeed=v end end end})
MT:CreateSlider({Name="⬆️ JumpPower",Range={0,500},Increment=1,CurrentValue=State.JumpPowerValue,Flag="JP",Callback=function(v) State.JumpPowerValue=v local h=getHum() if h then h.JumpPower=v h.UseJumpPower=true end end})
MT:CreateToggle({Name="♾️ Infinite Jump",CurrentValue=State.InfiniteJump,Flag="IJ",Callback=function(v) State.InfiniteJump=v end})

-- CAMERA TAB
local CT = Window:CreateTab("📷 Camera", 4483362458)
CT:CreateSection("🎮 Rotation")

if IS_MOBILE then
    CT:CreateSlider({Name="📱 Touch Sensitivity",Range={10,100},Increment=5,Suffix="%",CurrentValue=math.floor(State.TouchSensitivity*100),Flag="TS",Callback=function(v) State.TouchSensitivity=v/100 end})
    CT:CreateSlider({Name="🔄 Roll Speed",Range={5,50},Increment=1,CurrentValue=math.floor(State.CameraRotSpeed*10),Flag="RLS",Callback=function(v) State.CameraRotSpeed=v/10 end})
    CT:CreateParagraph({Title="📱 Controls",Content="• Swipe right side of screen to rotate\n• Left side: Roll buttons (↺ ↻)\n• Right side: Fly Up ▲ / Down ▼\n• Joystick: Move\n• 🙈/👁️: Hide/Show buttons"})
else
    CT:CreateSlider({Name="🖱️ Mouse Sensitivity",Range={5,100},Increment=5,Suffix="%",CurrentValue=math.floor(State.PC_MouseSensitivity*100),Flag="MS",Callback=function(v) State.PC_MouseSensitivity=v/100 end})
    CT:CreateParagraph({Title="🖥️ PC Controls",Content="Mouse = Yaw/Pitch\nWASD = Move | Space/Ctrl = Up/Down\nF = Toggle Freecam\nShift = Speed Boost (2.5x)\nR = Reset Camera Rotation"})
end

CT:CreateSection("🔭 FOV & Effects")
CT:CreateSlider({Name="🔭 FOV",Range={30,120},Increment=1,Suffix="°",CurrentValue=State.FOV,Flag="FOV",Callback=function(v) State.FOV=v if not State.DynamicFOV and not State.ChaosMode then Camera.FieldOfView=v end end})
CT:CreateToggle({Name="📐 Dynamic FOV",CurrentValue=State.DynamicFOV,Flag="DFOV",Callback=function(v) State.DynamicFOV=v if not v then Camera.FieldOfView=State.FOV end end})
CT:CreateToggle({Name="📳 Camera Shake",CurrentValue=State.CameraShake,Flag="CSH",Callback=function(v) State.CameraShake=v end})
CT:CreateToggle({Name="📍 Show Coordinates",CurrentValue=State.ShowCoords,Flag="SC",Callback=function(v) State.ShowCoords=v end})

CT:CreateSection("🎯 Target")
CT:CreateDropdown({Name="👁️ Follow",Options=getPlayerList(),CurrentOption={"None"},Flag="FP",Callback=function(v) local s=v[1] or v State.FollowTarget=(s=="None" or s=="No Players") and nil or s end})
CT:CreateDropdown({Name="🔒 Lock",Options=getPlayerList(),CurrentOption={"None"},Flag="LT",Callback=function(v) local s=v[1] or v State.LockTarget=(s=="None" or s=="No Players") and nil or s end})

CT:CreateSection("💾 Save / Load")
CT:CreateButton({Name="💾 Save Position",Callback=function()
    if State.FreecamEnabled then State.SavedCameraPos=freecamPosition State.SavedCameraLook={yaw=State.CameraYaw,pitch=State.CameraPitch,roll=State.CameraRoll}
    else State.SavedCameraPos=Camera.CFrame.Position local l=Camera.CFrame.LookVector State.SavedCameraLook={yaw=math.atan2(-l.X,-l.Z),pitch=math.asin(math.clamp(l.Y,-1,1)),roll=0} end
    notify("Save","Saved! ✅",3) end})
CT:CreateButton({Name="📂 Load Position",Callback=function()
    if not State.SavedCameraPos then notify("Load","Nothing saved!",3) return end
    if State.FreecamEnabled then freecamPosition=State.SavedCameraPos
        if State.SavedCameraLook then State.CameraYaw=State.SavedCameraLook.yaw State.CameraPitch=State.SavedCameraLook.pitch State.CameraRoll=State.SavedCameraLook.roll or 0 end
        notify("Load","Loaded! ✅",3)
    else notify("Load","Enable Freecam first!",3) end end})

-- PLAYER TAB
local PT = Window:CreateTab("👤 Player", 4483362458)
PT:CreateSection("🚀 Teleport")
PT:CreateButton({Name="📍 Teleport to Camera",Callback=function() tpToCamera(false) end})
PT:CreateButton({Name="🛡️ Safe Teleport",Callback=function() tpToCamera(true) end})
PT:CreateToggle({Name="🌊 Smooth Teleport",CurrentValue=false,Flag="STP",Callback=function(v) State.SmoothTeleport=v end})
PT:CreateSection("👤 Character")
PT:CreateButton({Name="💀 Reset Character",Callback=function() if State.FreecamEnabled then disableFreecam() end local h=getHum() if h then h.Health=0 end end})
PT:CreateButton({Name="📊 Info",Callback=function() local h=getHum() local hr=getHRP() if h and hr then notify("Info","Speed:"..math.floor(h.WalkSpeed).." Jump:"..math.floor(h.JumpPower).."\n"..PLATFORM,5) end end})

-- FUN TAB
local FT = Window:CreateTab("🎮 Fun", 4483362458)
FT:CreateToggle({Name="🌀 Chaos Mode",CurrentValue=false,Flag="CH",Callback=function(v) State.ChaosMode=v if not v then Camera.FieldOfView=State.FOV end end})
FT:CreateButton({Name="🔍 Scan Players",Callback=function() scanPlayers(State.ScanRange) end})
FT:CreateSlider({Name="📏 Range",Range={50,500},Increment=10,Suffix=" studs",CurrentValue=200,Flag="SR",Callback=function(v) State.ScanRange=v end})
FT:CreateButton({Name="❌ Clear",Callback=function() clearHL() end})

-- SETTINGS TAB
local ST = Window:CreateTab("⚙️ Settings", 4483362458)

ST:CreateSection("📩 Feedback")
ST:CreateParagraph({Title="⚠️ FEEDBACK RULES",Content="Feedback must be RELEVANT (bugs, suggestions).\n\n🔸 1st offense → 30 min ban\n🔸 2nd offense → 1 day ban\n🔸 3rd offense → PERMANENT ban\n\n✅ Good: 'Freecam lags on mobile'\n❌ Bad: Spam / trolling / insults"})
ST:CreateToggle({Name="✅ I agree to the rules",CurrentValue=false,Flag="FBA",Callback=function(v) State.FeedbackAgreed=v end})
ST:CreateInput({Name="✏️ Feedback",PlaceholderText="Bug or suggestion...",RemoveTextAfterFocusLost=false,Flag="FBI",Callback=function(t) State.FeedbackText=t end})
ST:CreateButton({Name="📨 Send",Callback=function() local t=State.FeedbackText if(not t or t=="") and Rayfield.Flags["FBI"] then t=Rayfield.Flags["FBI"].CurrentValue or "" end sendFeedback(t) end})

ST:CreateSection("💾 Save System")
ST:CreateButton({Name="💾 Save All Settings",Callback=function() saveSettings() notify("💾","Settings saved!",3) end})
ST:CreateButton({Name="📂 Load Settings",Callback=function()
    local d = loadSettings()
    if d then
        for k,v in pairs(d) do if State[k] ~= nil then State[k] = v end end
        notify("📂","Settings loaded!",3)
    else notify("❌","No saved settings found",3) end
end})

ST:CreateSection("🔧 System")
ST:CreateButton({Name="🔄 Reset All",Callback=function()
    if State.FreecamEnabled then disableFreecam() end
    if State.NoclipEnabled then disableNoclip() end
    State.InfiniteJump=false State.ChaosMode=false State.DynamicFOV=false State.CameraShake=false
    State.GhostMode=false State.CinematicMode=false State.AutoAlignCamera=false State.AutoAlignPitch=false
    State.DynamicSpeed=true State.SmoothTeleport=false State.FollowTarget=nil State.LockTarget=nil
    State.WalkSpeedValue=16 State.JumpPowerValue=50 State.FOV=70 State.CameraRoll=0
    local h=getHum() if h then h.WalkSpeed=16 h.JumpPower=50 end
    Camera.FieldOfView=70 Camera.CameraType=Enum.CameraType.Custom
    clearHL() if IS_PC then unlockMouse() resetKeys() end
    notify("Reset","Done ✅",4)
end})

ST:CreateSection("📜 Changelog")
ST:CreateParagraph({Title="📜 v2.0",Content=[[
🎮 New Camera System
• Mobile: Swipe to rotate (touch)
• PC: Mouse to rotate
• Roll axis: ↺ ↻ buttons (full 360°)
• Separate Yaw/Pitch/Roll

📱 Minimal Mobile UI
• Circle fly buttons (▲▼) like Roblox jump
• Roll buttons on left side
• No background panels
• 🙈/👁️ hide toggle

🖥️ PC Hotkeys
• F = Toggle Freecam
• Shift = 2.5x Speed Boost
• R = Reset Camera Rotation

📍 Coordinate Display
• Shows X/Y/Z position
• Toggle on/off in Camera tab

💾 Save/Load Settings
• Saves speed, FOV, toggles
• Auto-loads on next session
• File-based persistence

🛠️ All Previous Fixes
• Fixed mobile buttons
• Fixed joystick movement
• Fixed camera 180° bug
• Online ban system
]]})

ST:CreateParagraph({Title="Freecam Hub v"..VERSION,Content="Platform: "..PLATFORM.."\nBan: Online ✅\nDelta Optimized"})

-- CLEANUP
pcall(function()
    game:GetService("CoreGui").ChildRemoved:Connect(function(child)
        if child.Name == "Rayfield" then
            if State.FreecamEnabled then disableFreecam() end
            if State.NoclipEnabled then disableNoclip() end
            disconnectAll() destroyAllUI() clearHL()
            Camera.CameraType=Enum.CameraType.Custom Camera.FieldOfView=70
            anchorChar(false) setCharVisible(true)
            if IS_PC then unlockMouse() resetKeys() end
            pcall(function() local h=getHum() if h then h.WalkSpeed=16 h.JumpPower=50 end end)
        end
    end)
end)

-- INIT
Camera.FieldOfView = State.FOV
notify("✅ Freecam Hub v"..VERSION, PLATFORM.."\n"..(IS_MOBILE and "📱 Swipe=Rotate | ▲▼=Fly | ↺↻=Roll" or "🖥️ F=Freecam | WASD+Mouse | Shift=Boost"), 7)
