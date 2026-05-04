--[[
    FREECAM HUB v2.0
    Lag Fixed | No Coords
    Different Roll Icons
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local VERSION = "2.0"

local IS_MOBILE = UserInputService.TouchEnabled
    and not UserInputService.KeyboardEnabled
    and not UserInputService.MouseEnabled
local IS_PC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
local PLATFORM = IS_MOBILE and "Mobile" or "PC"

local WEBHOOK_URL = "https://discord.com/api/webhooks/1446147402275749916/m5eZ12l6RKrjSGJKuVnxRyKBb4mQIqlVQJloX9dhfQ6Ue1lCNRwYwjJxGuqCdGh2MrDO"
local BAN_API_URL = "https://ban-management-system.onrender.com/api/banlist"
local OnlineBanList = {}

local function httpReq(opt)
    local fn = request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
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
        local ok2, exp = pcall(function()
            local y,mo,d,h,mn,s = info.expiresAt:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
            if y then return os.time({year=tonumber(y),month=tonumber(mo),day=tonumber(d),hour=tonumber(h),min=tonumber(mn),sec=tonumber(s)}) end
        end)
        if ok2 and exp and os.time() > exp then return false end
    end
    Player:Kick("BANNED\nReason: "..(info.reason or "N/A").."\nBy: "..(info.bannedBy or "Admin"))
    return true
end

pcall(fetchBans)
if checkBan() then return end

task.spawn(function()
    while task.wait(60) do
        pcall(function() fetchBans() checkBan() end)
    end
end)

local RayfieldOk, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not RayfieldOk or not Rayfield then
    local ok2, rf2 = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source"))()
    end)
    if ok2 and rf2 then Rayfield = rf2
    else warn("Failed to load Rayfield") return end
end

local function notify(t, c, d)
    pcall(function() Rayfield:Notify({Title=t or"",Content=c or"",Duration=d or 4}) end)
end

local SAVE_KEY = "FCHub_v2"

local function saveSettings(S)
    pcall(function()
        if not writefile then return end
        writefile(SAVE_KEY..".json", HttpService:JSONEncode({
            FreecamSpeed=S.FreecamSpeed, FOV=S.FOV,
            WalkSpeedValue=S.WalkSpeedValue, JumpPowerValue=S.JumpPowerValue,
            DynamicSpeed=S.DynamicSpeed, CinematicMode=S.CinematicMode,
            GhostMode=S.GhostMode, NoclipEnabled=S.NoclipEnabled,
            InfiniteJump=S.InfiniteJump, DynamicFOV=S.DynamicFOV,
            CameraShake=S.CameraShake, CameraRotSpeed=S.CameraRotSpeed,
            PC_MouseSensitivity=S.PC_MouseSensitivity, TouchSensitivity=S.TouchSensitivity,
        }))
    end)
end

local function loadSettings()
    local d = nil
    pcall(function()
        if isfile and isfile(SAVE_KEY..".json") then
            d = HttpService:JSONDecode(readfile(SAVE_KEY..".json"))
        end
    end)
    return d
end

local State = {
    FreecamEnabled=false, FreecamSpeed=50,
    FreecamGoingUp=false, FreecamGoingDown=false,
    CinematicMode=false, GhostMode=false, DynamicSpeed=true,
    AutoAlignCamera=false, AutoAlignStrength=0.03, AutoAlignPitch=false,
    UIHidden=false,
    RollingLeft=false, RollingRight=false, CameraRotSpeed=2,
    CameraYaw=0, CameraPitch=0, CameraRoll=0,
    FOV=70, DynamicFOV=false, CameraShake=false, SmoothTeleport=false, ChaosMode=false,
    NoclipEnabled=false, WalkSpeedValue=16, JumpPowerValue=50, InfiniteJump=false,
    FollowTarget=nil, LockTarget=nil, SavedCameraPos=nil, SavedCameraLook=nil,
    ScanHighlights={}, ScanRange=200, Connections={},
    PC_Keys={W=false,A=false,S=false,D=false,Space=false,LeftControl=false,LeftShift=false},
    PC_MouseSensitivity=0.3, PC_MouseLocked=false, PC_SpeedBoost=false,
    TouchSensitivity=0.4,
    LastFeedbackTime=0, FeedbackCooldown=600, FeedbackText="", FeedbackAgreed=false,
}

local saved = loadSettings()
if saved then for k,v in pairs(saved) do if State[k] ~= nil then State[k] = v end end end

local freecamPosition = Vector3.zero
local freecamVelocity = Vector3.zero

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

local function getChar() return Player.Character end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end
local function getHRP() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end

local function anchorChar(a)
    pcall(function()
        local c = getChar() if not c then return end
        for _,p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = a end end
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

local function normAngle(a)
    return a - math.floor(a / (2*math.pi) + 0.5) * 2*math.pi
end

local function shortDiff(f, t) return normAngle(t - f) end
local function lerpAng(f, t, a) return f + shortDiff(f, t) * math.clamp(a, 0, 1) end

local function setupPCInput()
    if not IS_PC then return end
    disconnectKey("PCKDown")
    disconnectKey("PCKUp")
    disconnectKey("PCMouse")

    State.Connections["PCKDown"] = UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        local k = inp.KeyCode
        if k == Enum.KeyCode.F then
            if State.FreecamEnabled then disableFreecam() else enableFreecam() end
            return
        end
        if k == Enum.KeyCode.R and State.FreecamEnabled then
            State.CameraYaw = 0
            State.CameraPitch = 0
            State.CameraRoll = 0
            return
        end
        if not State.FreecamEnabled then return end
        local n = k.Name
        if State.PC_Keys[n] ~= nil then State.PC_Keys[n] = true end
        if k == Enum.KeyCode.LeftShift then State.PC_SpeedBoost = true end
    end)

    State.Connections["PCKUp"] = UserInputService.InputEnded:Connect(function(inp)
        local n = inp.KeyCode.Name
        if State.PC_Keys[n] ~= nil then State.PC_Keys[n] = false end
        if inp.KeyCode == Enum.KeyCode.LeftShift then State.PC_SpeedBoost = false end
    end)

    State.Connections["PCMouse"] = UserInputService.InputChanged:Connect(function(inp, gp)
        if gp or not State.FreecamEnabled or not State.PC_MouseLocked then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = inp.Delta
            local s = State.PC_MouseSensitivity / 100
            State.CameraYaw = normAngle(State.CameraYaw - d.X * s)
            State.CameraPitch = math.clamp(State.CameraPitch - d.Y * s, -1.55, 1.55)
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

local activeTouch = nil

local function setupTouch()
    if not IS_MOBILE then return end
    disconnectKey("TS")
    disconnectKey("TM")
    disconnectKey("TE")

    State.Connections["TS"] = UserInputService.TouchStarted:Connect(function(touch, gp)
        if gp or not State.FreecamEnabled or activeTouch then return end
        if touch.Position.X > Camera.ViewportSize.X * 0.3 then
            activeTouch = touch
        end
    end)

    State.Connections["TM"] = UserInputService.TouchMoved:Connect(function(touch, gp)
        if gp or not State.FreecamEnabled or touch ~= activeTouch then return end
        local d = touch.Delta
        local s = State.TouchSensitivity / 100
        State.CameraYaw = normAngle(State.CameraYaw - d.X * s)
        State.CameraPitch = math.clamp(State.CameraPitch - d.Y * s, -1.55, 1.55)
    end)

    State.Connections["TE"] = UserInputService.TouchEnded:Connect(function(touch)
        if touch == activeTouch then activeTouch = nil end
    end)
end

local FreecamGuis = {}

local function destroyAllUI()
    State.FreecamGoingUp = false
    State.FreecamGoingDown = false
    State.RollingLeft = false
    State.RollingRight = false
    State.UIHidden = false
    activeTouch = nil
    for _,g in pairs(FreecamGuis) do pcall(function() if g and g.Parent then g:Destroy() end end) end
    FreecamGuis = {}
end

local function makeBtn(parent, text, size, pos, color)
    local btn = Instance.new("TextButton")
    btn.Size = size
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.2
    btn.Text = text
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 28
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Active = true
    btn.ZIndex = 10
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0.5, 0)
    return btn
end

local function hookHold(btn, key, pClr, rClr)
    local held = false
    local function go()
        if held then return end
        held = true
        State[key] = true
        btn.BackgroundColor3 = pClr
    end
    local function stop()
        if not held then return end
        held = false
        State[key] = false
        btn.BackgroundColor3 = rClr
    end
    btn.MouseButton1Down:Connect(go)
    btn.MouseButton1Up:Connect(stop)
    btn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then go() end end)
    btn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then stop() end
    end)
    btn.MouseLeave:Connect(stop)
end

local function createMobileUI()
    if IS_PC then return end
    destroyAllUI()

    local gui = Instance.new("ScreenGui")
    gui.Name = "FCUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 110

    local SZ = UDim2.new(0, 70, 0, 70)
    local SM = UDim2.new(0, 60, 0, 60)
    local BLU = Color3.fromRGB(50, 130, 255)
    local BLU_P = Color3.fromRGB(90, 170, 255)
    local RED = Color3.fromRGB(220, 60, 60)
    local RED_P = Color3.fromRGB(255, 100, 100)
    local PUR = Color3.fromRGB(90, 60, 140)
    local PUR_P = Color3.fromRGB(130, 100, 180)
    local GRN = Color3.fromRGB(50, 130, 90)
    local GRN_P = Color3.fromRGB(80, 170, 120)

    -- FLY UP (bottom right like jump btn)
    local flyUp = makeBtn(gui, "^", SZ, UDim2.new(1, -90, 1, -110), BLU)
    hookHold(flyUp, "FreecamGoingUp", BLU_P, BLU)

    -- FLY DOWN (left of fly up)
    local flyDown = makeBtn(gui, "v", SZ, UDim2.new(1, -175, 1, -110), RED)
    hookHold(flyDown, "FreecamGoingDown", RED_P, RED)

    -- ROLL LEFT (left side upper) - PURPLE with left arrow
    local rollL = makeBtn(gui, "<)", SM, UDim2.new(0, 12, 0.5, -75), PUR)
    hookHold(rollL, "RollingLeft", PUR_P, PUR)

    -- ROLL RIGHT (left side lower) - GREEN with right arrow
    local rollR = makeBtn(gui, "(>", SM, UDim2.new(0, 12, 0.5, 5), GRN)
    hookHold(rollR, "RollingRight", GRN_P, GRN)

    -- HIDE BUTTON
    local hide = makeBtn(gui, "X", UDim2.new(0,40,0,40), UDim2.new(0.5,-20,0,8), Color3.fromRGB(40,40,60))
    hide.TextSize = 18
    hide.ZIndex = 15

    hide.MouseButton1Click:Connect(function()
        State.UIHidden = not State.UIHidden
        hide.Text = State.UIHidden and "O" or "X"
        flyUp.Visible = not State.UIHidden
        flyDown.Visible = not State.UIHidden
        rollL.Visible = not State.UIHidden
        rollR.Visible = not State.UIHidden
    end)

    gui.Parent = Player:FindFirstChildOfClass("PlayerGui")
    table.insert(FreecamGuis, gui)
end

function enableFreecam()
    if State.FreecamEnabled then return end
    pcall(function() fetchBans() if checkBan() then return end end)

    State.FreecamEnabled = true
    disconnectKey("FCR")

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

    if IS_PC then lockMouse() resetKeys()
    else createMobileUI() setupTouch() end

    State.Connections["FCR"] = RunService.RenderStepped:Connect(function(dt)
        if not State.FreecamEnabled then return end

        -- Roll
        local rs = State.CameraRotSpeed * dt
        if State.RollingLeft then State.CameraRoll = normAngle(State.CameraRoll + rs) end
        if State.RollingRight then State.CameraRoll = normAngle(State.CameraRoll - rs) end

        State.CameraYaw = normAngle(State.CameraYaw)
        State.CameraPitch = math.clamp(State.CameraPitch, -1.55, 1.55)

        -- Vectors for movement (no roll)
        local yawCF = CFrame.Angles(0, State.CameraYaw, 0)
        local pitchCF = CFrame.Angles(State.CameraPitch, 0, 0)
        local moveRot = yawCF * pitchCF
        local cL = moveRot.LookVector
        local cR = moveRot.RightVector
        local cU = Vector3.new(0,1,0)

        local mv = Vector3.zero
        local moving = false
        local mag = 1

        if IS_PC then
            local fw,rt,up = getPCMove()
            if fw ~= 0 or rt ~= 0 then mv = cL*fw + cR*rt moving = true end
            if up ~= 0 then mv = mv + cU*up moving = true end
        else
            local hum2 = getHum()
            if hum2 then
                local md = hum2.MoveDirection
                if md.Magnitude > 0.01 then
                    moving = true
                    mag = math.clamp(md.Magnitude, 0.1, 1)
                    local ff = Vector3.new(cL.X,0,cL.Z)
                    ff = ff.Magnitude > 0.001 and ff.Unit or Vector3.new(0,0,-1)
                    local rr = Vector3.new(cR.X,0,cR.Z)
                    rr = rr.Magnitude > 0.001 and rr.Unit or Vector3.new(1,0,0)
                    mv = cL * md:Dot(ff) + cR * md:Dot(rr)
                end
            end
            if State.FreecamGoingUp then mv = mv + cU moving = true end
            if State.FreecamGoingDown then mv = mv - cU moving = true end
        end

        if mv.Magnitude > 1 then mv = mv.Unit end

        local spd = State.FreecamSpeed
        if State.DynamicSpeed and IS_MOBILE then spd = spd * mag end
        if State.CinematicMode then spd = spd * 0.3 end
        if State.PC_SpeedBoost then spd = spd * 2.5 end

        local tv = mv * spd
        freecamVelocity = State.CinematicMode and freecamVelocity:Lerp(tv, 0.08) or tv
        freecamPosition = freecamPosition + freecamVelocity * dt

        -- Auto align
        if State.AutoAlignCamera and moving and not State.FollowTarget and not State.LockTarget then
            local hv = Vector3.new(freecamVelocity.X, 0, freecamVelocity.Z)
            if hv.Magnitude > 1 then
                local ty = math.atan2(-hv.X, -hv.Z)
                local yd = shortDiff(State.CameraYaw, ty)
                if math.abs(yd) > 0.01 then
                    State.CameraYaw = normAngle(State.CameraYaw + yd * State.AutoAlignStrength)
                end
            end
            if State.AutoAlignPitch and freecamVelocity.Magnitude > 1 then
                local tp = math.asin(math.clamp(freecamVelocity.Unit.Y, -1, 1))
                local pd = tp - State.CameraPitch
                if math.abs(pd) > 0.01 then
                    State.CameraPitch = math.clamp(State.CameraPitch + pd * State.AutoAlignStrength * 0.5, -1.55, 1.55)
                end
            end
        end

        -- Follow
        if State.FollowTarget then
            local tp = Players:FindFirstChild(State.FollowTarget)
            if tp and tp.Character then
                local th = tp.Character:FindFirstChild("HumanoidRootPart")
                if th then
                    freecamPosition = th.Position + Vector3.new(0,10,15)
                    local dir = (th.Position - freecamPosition)
                    if dir.Magnitude > 0.1 then
                        dir = dir.Unit
                        State.CameraYaw = lerpAng(State.CameraYaw, math.atan2(-dir.X,-dir.Z), 0.1)
                        State.CameraPitch = State.CameraPitch + (math.asin(math.clamp(dir.Y,-1,1)) - State.CameraPitch) * 0.1
                    end
                end
            end
        end

        -- Lock
        if State.LockTarget then
            local tp = Players:FindFirstChild(State.LockTarget)
            if tp and tp.Character then
                local th = tp.Character:FindFirstChild("HumanoidRootPart")
                if th then
                    local dir = (th.Position - freecamPosition)
                    if dir.Magnitude > 0.1 then
                        dir = dir.Unit
                        State.CameraYaw = lerpAng(State.CameraYaw, math.atan2(-dir.X,-dir.Z), 0.15)
                        State.CameraPitch = math.clamp(State.CameraPitch + (math.asin(math.clamp(dir.Y,-1,1)) - State.CameraPitch) * 0.15, -1.55, 1.55)
                    end
                end
            end
        end

        -- Effects
        if State.DynamicFOV then
            local tf = math.clamp(State.FOV + freecamVelocity.Magnitude * 0.3, 30, 120)
            Camera.FieldOfView = Camera.FieldOfView + (tf - Camera.FieldOfView) * 0.1
        end

        local sh = Vector3.zero
        if State.CameraShake and freecamVelocity.Magnitude > 5 then
            local i = math.clamp(freecamVelocity.Magnitude / State.FreecamSpeed, 0, 1) * 0.1
            sh = Vector3.new((math.random()-0.5)*i, (math.random()-0.5)*i, (math.random()-0.5)*i)
        end

        if State.ChaosMode then
            Camera.FieldOfView = math.random(40,110)
            sh = sh + Vector3.new((math.random()-0.5)*0.3, (math.random()-0.5)*0.3, 0)
        end

        -- Apply (Yaw * Pitch * Roll)
        local rollCF = CFrame.Angles(0, 0, State.CameraRoll)
        Camera.CFrame = CFrame.new(freecamPosition + sh) * yawCF * pitchCF * rollCF
    end)

    notify("Freecam ON", IS_PC and "WASD+Mouse | F=Toggle | Shift=Boost" or "Swipe=Rotate | Btns=Fly/Roll", 4)
end

function disableFreecam()
    if not State.FreecamEnabled then return end
    State.FreecamEnabled = false
    disconnectKey("FCR")
    disconnectKey("TS")
    disconnectKey("TM")
    disconnectKey("TE")
    State.FreecamGoingUp = false
    State.FreecamGoingDown = false
    State.RollingLeft = false
    State.RollingRight = false
    freecamVelocity = Vector3.zero
    State.CameraRoll = 0
    activeTouch = nil
    anchorChar(false)
    local hum = getHum()
    if hum then hum.WalkSpeed = State.WalkSpeedValue end
    if State.GhostMode then setCharVisible(true) end
    Camera.CameraType = Enum.CameraType.Custom
    pcall(function() Camera.CameraSubject = getHum() end)
    if not State.DynamicFOV and not State.ChaosMode then Camera.FieldOfView = State.FOV end
    if IS_PC then unlockMouse() resetKeys() end
    destroyAllUI()
    saveSettings(State)
    notify("Freecam", "OFF", 3)
end

local function enableNoclip()
    disconnectKey("NCS")
    State.NoclipEnabled = true
    State.Connections["NCS"] = RunService.Stepped:Connect(function()
        if not State.NoclipEnabled then return end
        local c = getChar() if not c then return end
        for _,p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
    end)
end

local function disableNoclip()
    State.NoclipEnabled = false
    disconnectKey("NCS")
    pcall(function()
        local c = getChar() if not c then return end
        for _,p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
        end
    end)
end

local function setupInfJump()
    disconnectKey("IJ")
    State.Connections["IJ"] = UserInputService.JumpRequest:Connect(function()
        if not State.InfiniteJump then return end
        local h = getHum() if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end
setupInfJump()

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

local function clearHL()
    for _,h in pairs(State.ScanHighlights) do pcall(function() if h and h.Parent then h:Destroy() end end) end
    State.ScanHighlights = {}
end

local function scanPlayers(range)
    clearHL()
    range = range or State.ScanRange
    local pos = State.FreecamEnabled and freecamPosition or (getHRP() and getHRP().Position or Vector3.zero)
    local cnt = 0
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
                cnt = cnt + 1
            end
        end
    end
    notify("Scan", cnt.." players found", 3)
    task.delay(10, clearHL)
end

local function getPlayerList()
    local l = {"None"}
    for _,p in pairs(Players:GetPlayers()) do if p ~= Player then table.insert(l, p.Name) end end
    if #l == 1 then table.insert(l,"No Players") end
    return l
end

local function tpToCam(safe)
    local hrp = getHRP() if not hrp then return end
    if State.FreecamEnabled then disableFreecam() task.wait(0.15) end
    local t = freecamPosition + (safe and Vector3.new(0,5,0) or Vector3.zero)
    if State.SmoothTeleport then
        TweenService:Create(hrp, TweenInfo.new(1, Enum.EasingStyle.Quad), {CFrame=CFrame.new(t)}):Play()
    else hrp.CFrame = CFrame.new(t) end
    notify("Teleport", "Done!", 2)
end

local function sendFeedback(text)
    if not text or #text < 3 then notify("Error","Min 3 chars!",3) return end
    if not State.FeedbackAgreed then notify("Warning","Accept rules first!",4) return end
    local el = tick() - State.LastFeedbackTime
    if el < State.FeedbackCooldown then
        local r = math.ceil(State.FeedbackCooldown - el)
        notify("Wait", math.floor(r/60).."m "..r%60 .."s", 4) return
    end
    pcall(function()
        httpReq({Url=WEBHOOK_URL,Method="POST",Headers={["Content-Type"]="application/json"},
            Body=HttpService:JSONEncode({embeds={{title="Feedback v"..VERSION,description=text,color=3447003,
                fields={{name="Player",value=Player.Name,inline=true},{name="ID",value=tostring(Player.UserId),inline=true},{name="Device",value=PLATFORM,inline=true}}}}})})
    end)
    State.LastFeedbackTime = tick()
    notify("Sent!", "Next in 10 min.", 4)
end

setupPCInput()
if IS_MOBILE then setupTouch() end

local W = Rayfield:CreateWindow({
    Name = "Freecam Hub v"..VERSION.." ("..PLATFORM..")",
    LoadingTitle = "Freecam Hub",
    LoadingSubtitle = "v"..VERSION,
    ConfigurationSaving = {Enabled=false},
    Discord = {Enabled=false},
    KeySystem = false,
})

local MT = W:CreateTab("Movement", 4483362458)
MT:CreateSection("Freecam")
MT:CreateToggle({Name="Enable Freecam",CurrentValue=false,Flag="FC",Callback=function(v) if v then enableFreecam() else disableFreecam() end end})
MT:CreateSlider({Name="Fly Speed",Range={5,300},Increment=5,Suffix=" st/s",CurrentValue=State.FreecamSpeed,Flag="FS",Callback=function(v) State.FreecamSpeed=v end})
MT:CreateToggle({Name="Dynamic Speed",CurrentValue=State.DynamicSpeed,Flag="DS",Callback=function(v) State.DynamicSpeed=v end})
MT:CreateToggle({Name="Cinematic",CurrentValue=State.CinematicMode,Flag="CM",Callback=function(v) State.CinematicMode=v end})
MT:CreateToggle({Name="Ghost Mode",CurrentValue=State.GhostMode,Flag="GM",Callback=function(v) State.GhostMode=v if State.FreecamEnabled then setCharVisible(not v) end end})
MT:CreateSection("Auto Align")
MT:CreateToggle({Name="Yaw Align",CurrentValue=false,Flag="AAY",Callback=function(v) State.AutoAlignCamera=v end})
MT:CreateToggle({Name="Pitch Align",CurrentValue=false,Flag="AAP",Callback=function(v) State.AutoAlignPitch=v end})
MT:CreateSlider({Name="Strength",Range={1,15},Increment=1,Suffix="%",CurrentValue=3,Flag="AS",Callback=function(v) State.AutoAlignStrength=v/100 end})
MT:CreateSection("Character")
MT:CreateToggle({Name="Noclip",CurrentValue=State.NoclipEnabled,Flag="NC",Callback=function(v) if v then enableNoclip() else disableNoclip() end end})
MT:CreateSlider({Name="WalkSpeed",Range={0,500},Increment=1,CurrentValue=State.WalkSpeedValue,Flag="WS",Callback=function(v) State.WalkSpeedValue=v if not State.FreecamEnabled then local h=getHum() if h then h.WalkSpeed=v end end end})
MT:CreateSlider({Name="JumpPower",Range={0,500},Increment=1,CurrentValue=State.JumpPowerValue,Flag="JP",Callback=function(v) State.JumpPowerValue=v local h=getHum() if h then h.JumpPower=v h.UseJumpPower=true end end})
MT:CreateToggle({Name="Infinite Jump",CurrentValue=State.InfiniteJump,Flag="IJT",Callback=function(v) State.InfiniteJump=v end})

local CT = W:CreateTab("Camera", 4483362458)
CT:CreateSection("Controls")
if IS_MOBILE then
    CT:CreateSlider({Name="Touch Sensitivity",Range={10,100},Increment=5,Suffix="%",CurrentValue=math.floor(State.TouchSensitivity*100),Flag="TS",Callback=function(v) State.TouchSensitivity=v/100 end})
    CT:CreateSlider({Name="Roll Speed",Range={5,50},Increment=1,CurrentValue=math.floor(State.CameraRotSpeed*10),Flag="RLS",Callback=function(v) State.CameraRotSpeed=v/10 end})
    CT:CreateParagraph({Title="Mobile",Content="Swipe right side = Rotate\nLeft: <) = Roll Left (purple)\nLeft: (> = Roll Right (green)\nRight: ^ = Fly Up | v = Fly Down\nJoystick = Move"})
else
    CT:CreateSlider({Name="Mouse Sensitivity",Range={5,100},Increment=5,Suffix="%",CurrentValue=math.floor(State.PC_MouseSensitivity*100),Flag="MS",Callback=function(v) State.PC_MouseSensitivity=v/100 end})
    CT:CreateParagraph({Title="PC",Content="Mouse = Rotate\nWASD = Move\nSpace/Ctrl = Up/Down\nShift = Boost x2.5\nF = Toggle Freecam\nR = Reset Rotation"})
end
CT:CreateSection("FOV")
CT:CreateSlider({Name="FOV",Range={30,120},Increment=1,Suffix=" deg",CurrentValue=State.FOV,Flag="FOV",Callback=function(v) State.FOV=v if not State.DynamicFOV and not State.ChaosMode then Camera.FieldOfView=v end end})
CT:CreateToggle({Name="Dynamic FOV",CurrentValue=State.DynamicFOV,Flag="DFOV",Callback=function(v) State.DynamicFOV=v if not v then Camera.FieldOfView=State.FOV end end})
CT:CreateToggle({Name="Camera Shake",CurrentValue=State.CameraShake,Flag="CSH",Callback=function(v) State.CameraShake=v end})
CT:CreateSection("Target")
CT:CreateDropdown({Name="Follow",Options=getPlayerList(),CurrentOption={"None"},Flag="FP",Callback=function(v) local s=v[1] or v State.FollowTarget=(s=="None" or s=="No Players") and nil or s end})
CT:CreateDropdown({Name="Lock",Options=getPlayerList(),CurrentOption={"None"},Flag="LT",Callback=function(v) local s=v[1] or v State.LockTarget=(s=="None" or s=="No Players") and nil or s end})
CT:CreateSection("Position")
CT:CreateButton({Name="Save Position",Callback=function()
    if State.FreecamEnabled then State.SavedCameraPos=freecamPosition State.SavedCameraLook={yaw=State.CameraYaw,pitch=State.CameraPitch,roll=State.CameraRoll}
    else State.SavedCameraPos=Camera.CFrame.Position local l=Camera.CFrame.LookVector State.SavedCameraLook={yaw=math.atan2(-l.X,-l.Z),pitch=math.asin(math.clamp(l.Y,-1,1)),roll=0} end
    notify("Saved","Position saved!",3) end})
CT:CreateButton({Name="Load Position",Callback=function()
    if not State.SavedCameraPos then notify("Error","Nothing saved!",3) return end
    if State.FreecamEnabled then freecamPosition=State.SavedCameraPos if State.SavedCameraLook then State.CameraYaw=State.SavedCameraLook.yaw State.CameraPitch=State.SavedCameraLook.pitch State.CameraRoll=State.SavedCameraLook.roll or 0 end notify("Loaded","Done!",3)
    else notify("Error","Enable Freecam first!",3) end end})

local PT = W:CreateTab("Player", 4483362458)
PT:CreateSection("Teleport")
PT:CreateButton({Name="Teleport to Camera",Callback=function() tpToCam(false) end})
PT:CreateButton({Name="Safe Teleport",Callback=function() tpToCam(true) end})
PT:CreateToggle({Name="Smooth Teleport",CurrentValue=false,Flag="STP",Callback=function(v) State.SmoothTeleport=v end})
PT:CreateSection("Character")
PT:CreateButton({Name="Reset Character",Callback=function() if State.FreecamEnabled then disableFreecam() end local h=getHum() if h then h.Health=0 end end})

local FT = W:CreateTab("Fun", 4483362458)
FT:CreateToggle({Name="Chaos Mode",CurrentValue=false,Flag="CH",Callback=function(v) State.ChaosMode=v if not v then Camera.FieldOfView=State.FOV end end})
FT:CreateButton({Name="Scan Players",Callback=function() scanPlayers(State.ScanRange) end})
FT:CreateSlider({Name="Range",Range={50,500},Increment=10,Suffix=" studs",CurrentValue=200,Flag="SR",Callback=function(v) State.ScanRange=v end})
FT:CreateButton({Name="Clear Highlights",Callback=clearHL})

local ST = W:CreateTab("Settings", 4483362458)
ST:CreateSection("Feedback")
ST:CreateParagraph({Title="FEEDBACK RULES",Content="RELEVANT feedback only.\n1st: 30min ban | 2nd: 1day | 3rd: Perm\nGood: Bug reports, suggestions\nBad: Spam, insults"})
ST:CreateToggle({Name="I agree to the rules",CurrentValue=false,Flag="FBA",Callback=function(v) State.FeedbackAgreed=v end})
ST:CreateInput({Name="Feedback",PlaceholderText="Bug or suggestion...",RemoveTextAfterFocusLost=false,Flag="FBI",Callback=function(t) State.FeedbackText=t end})
ST:CreateButton({Name="Send",Callback=function() local t=State.FeedbackText if(not t or t=="") and Rayfield.Flags["FBI"] then t=Rayfield.Flags["FBI"].CurrentValue or "" end sendFeedback(t) end})
ST:CreateSection("Save")
ST:CreateButton({Name="Save Settings",Callback=function() saveSettings(State) notify("Saved","Done!",3) end})
ST:CreateButton({Name="Load Settings",Callback=function() local d=loadSettings() if d then for k,v in pairs(d) do if State[k]~=nil then State[k]=v end end notify("Loaded","Done!",3) else notify("Error","No save found",3) end end})
ST:CreateSection("System")
ST:CreateButton({Name="Reset All",Callback=function()
    if State.FreecamEnabled then disableFreecam() end
    if State.NoclipEnabled then disableNoclip() end
    State.InfiniteJump=false State.ChaosMode=false State.DynamicFOV=false State.CameraShake=false
    State.GhostMode=false State.CinematicMode=false State.AutoAlignCamera=false State.AutoAlignPitch=false
    State.DynamicSpeed=true State.SmoothTeleport=false State.FollowTarget=nil State.LockTarget=nil
    State.WalkSpeedValue=16 State.JumpPowerValue=50 State.FOV=70 State.CameraRoll=0
    local h=getHum() if h then h.WalkSpeed=16 h.JumpPower=50 end
    Camera.FieldOfView=70 Camera.CameraType=Enum.CameraType.Custom
    clearHL() if IS_PC then unlockMouse() resetKeys() end
    notify("Reset","Done!",3) end})
ST:CreateSection("Changelog")
ST:CreateParagraph({Title="v2.0",Content="Touch/Mouse rotation\nRoll axis (360 deg)\nMinimal mobile UI\nDifferent roll button colors\nPC hotkeys (F/Shift/R)\nSave/Load settings\nLag optimized\nNo coordinate overlay"})
ST:CreateParagraph({Title="v1.1",Content="Online ban system\nHide UI\nDrag panels\nFixed mobile bugs"})
ST:CreateParagraph({Title="Info",Content="v"..VERSION.." | "..PLATFORM.."\nBan: Online | Delta Compatible"})

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

Camera.FieldOfView = State.FOV
notify("Freecam Hub v"..VERSION, PLATFORM..(IS_MOBILE and "\nSwipe=Rotate | ^v=Fly | <)(>=Roll" or "\nF=Freecam | Mouse=Rotate | Shift=Boost"), 5)
