--!strict
-- features/TargetAura.lua
-- Модуль Target Aura для NOVA Mod Menu
-- Крутить гравця навколо цілі та завдає шкоди

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TargetAura = {}

-- ============ НАЛАШТУВАННЯ ============
local CONFIG = {
    Enabled = false,
    -- Крутіння
    SpinSpeed = 360,            -- градусів на секунду (360 = 1 оберт/сек)
    Radius = 4,                 -- радіус обертання навколо цілі (studs)
    Height = 1,                 -- вертикальний зсув (studs)
    -- Шкода
    Damage = 25,                -- шкода за удар
    Cooldown = 0.35,            -- інтервал між ударами (сек)
    -- Пошук цілі
    TargetPart = "HumanoidRootPart",  -- до якої частини тіла прив'язуватись
    MaxSearchDistance = 250,    -- максимальна дистанція пошуку
    TeamCheck = true,           -- ігнорувати союзників
    -- Візуал
    ShowRing = true,            -- кільце-індикатор навколо цілі
}
-- =====================================

local localPlayer = Players.LocalPlayer
local enabled = false
local angle = 0
local lastAttack = 0
local currentTarget = nil
local heartbeatConn = nil
local ringGui = nil
local savedPlatformStand = nil
local savedAutoRotate = nil

-- ---------- Допоміжні ----------

local function isAlly(player)
    if not CONFIG.TeamCheck then return false end
    return player.Team ~= nil and player.Team == localPlayer.Team
end

local function isValidTarget(player, character)
    if not player or not character then return false end
    if player == localPlayer then return false end
    if isAlly(player) then return false end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if not character:FindFirstChild("HumanoidRootPart") then return false end
    return true
end

local function getMyCharacter()
    local char = localPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return nil end
    return char, hrp, hum
end

local function pickTarget()
    local char, hrp = getMyCharacter()
    if not char then return nil end

    local closest, closestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        local pChar = player.Character
        if not isValidTarget(player, pChar) then continue end

        local pRoot = pChar:FindFirstChild("HumanoidRootPart")
        if not pRoot then continue end

        local dist = (pRoot.Position - hrp.Position).Magnitude
        if dist > CONFIG.MaxSearchDistance then continue end
        if dist < closestDist then
            closestDist = dist
            closest = { player = player, character = pChar }
        end
    end
    return closest
end

-- ---------- Позиціонування ----------

local function spinAround(targetChar, hrp, hum, dt)
    local targetPart = targetChar:FindFirstChild(CONFIG.TargetPart)
        or targetChar:FindFirstChild("HumanoidRootPart")
    if not targetPart then return end

    angle = angle + math.rad(CONFIG.SpinSpeed) * dt

    local offset = Vector3.new(
        math.cos(angle) * CONFIG.Radius,
        CONFIG.Height,
        math.sin(angle) * CONFIG.Radius
    )
    local newPos = targetPart.Position + offset

    -- Дивимось на ціль, знаходимось на колі
    hrp.CFrame = CFrame.lookAt(newPos, targetPart.Position)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end

-- ---------- Шкода ----------

local function tryDamage(targetChar)
    local now = tick()
    if now - lastAttack < CONFIG.Cooldown then return end

    local hum = targetChar:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    hum:TakeDamage(CONFIG.Damage)
    lastAttack = now

    -- ефект
    local root = targetChar:FindFirstChild("HumanoidRootPart")
    if root then
        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(255, 60, 60)
        hl.OutlineColor = Color3.fromRGB(255, 200, 200)
        hl.FillTransparency = 0.5
        hl.Parent = targetChar
        task.delay(0.12, function()
            if hl then hl:Destroy() end
        end)
    end
end

-- ---------- Візуал ----------

local function createRing()
    if not CONFIG.ShowRing then return end
    if ringGui then ringGui:Destroy() end

    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local old = playerGui:FindFirstChild("TargetAuraRing")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "TargetAuraRing"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.BackgroundTransparency = 1
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Visible = false
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 80, 80)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = frame

    ringGui = { gui = gui, frame = frame }
end

local function updateRing(targetChar)
    if not ringGui then return end
    local camera = Workspace.CurrentCamera
    if not targetChar or not camera then
        ringGui.frame.Visible = false
        return
    end

    local part = targetChar:FindFirstChild("HumanoidRootPart")
    if not part then
        ringGui.frame.Visible = false
        return
    end

    local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen then
        ringGui.frame.Visible = false
        return
    end

    ringGui.frame.Visible = true
    ringGui.frame.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
    local size = 40 + CONFIG.Radius * 6
    ringGui.frame.Size = UDim2.fromOffset(size, size)
end

local function destroyRing()
    if ringGui then
        ringGui.gui:Destroy()
        ringGui = nil
    end
end

-- ---------- Основний цикл ----------

local function onHeartbeat(dt)
    if not enabled then return end

    local char, hrp, hum = getMyCharacter()
    if not char then return end

    -- Перевірка/оновлення цілі
    if not currentTarget or not isValidTarget(currentTarget.player, currentTarget.character) then
        currentTarget = pickTarget()
        angle = 0
    end

    if not currentTarget then
        updateRing(nil)
        return
    end

    local targetChar = currentTarget.character
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHRP then
        currentTarget = nil
        updateRing(nil)
        return
    end

    spinAround(targetChar, hrp, hum, dt)
    tryDamage(targetChar)
    updateRing(targetChar)
end

-- ---------- Публічне API ----------

function TargetAura.Start()
    if enabled then return end
    enabled = true
    CONFIG.Enabled = true
    angle = 0
    lastAttack = 0
    currentTarget = nil

    -- Зупиняємо фізику персонажа, щоб не боровся з нашим CFrame
    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            savedPlatformStand = hum.PlatformStand
            savedAutoRotate = hum.AutoRotate
            hum.PlatformStand = true
            hum.AutoRotate = false
        end
    end

    createRing()
    heartbeatConn = RunService.Heartbeat:Connect(onHeartbeat)

    print("[TargetAura] Увімкнено")
end

function TargetAura.Stop()
    if not enabled then return end
    enabled = false
    CONFIG.Enabled = false

    if heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end

    -- Повертаємо фізику
    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = savedPlatformStand or false
            hum.AutoRotate = savedAutoRotate ~= false
        end
    end

    currentTarget = nil
    destroyRing()
    print("[TargetAura] Вимкнено")
end

function TargetAura.Toggle()
    if enabled then TargetAura.Stop() else TargetAura.Start() end
    return enabled
end

function TargetAura.IsEnabled()
    return enabled
end

function TargetAura.SetConfig(key, value)
    if CONFIG[key] == nil then
        warn(("[TargetAura] Невідомий параметр: %s"):format(tostring(key)))
        return false
    end
    CONFIG[key] = value

    if key == "ShowRing" and enabled then
        if value then createRing() else destroyRing() end
    end
    return true
end

function TargetAura.GetConfig()
    local copy = {}
    for k, v in pairs(CONFIG) do copy[k] = v end
    return copy
end

function TargetAura.GetTarget()
    return currentTarget and currentTarget.player or nil
end

-- Швидкі пресети швидкості
function TargetAura.SetSpinSpeed(degPerSec)
    CONFIG.SpinSpeed = degPerSec
end

return TargetAura
