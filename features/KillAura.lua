--!strict
-- features/MinecraftKillAura.lua
-- Спеціально для PvP-ігор (MC PVP, Bedwars і т.д.)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser") -- Для емуляції кліків миші

local KillAura = {}

-- ============ НАЛАШТУВАННЯ ============
local CONFIG = {
    Enabled = false,
    Radius = 15,                -- Радіус атаки (studs)
    CPS = 12,                   -- Кліків на секунду (не ставте більше 15-20, буде бан)
    AutoAim = true,             -- Чи повертати камеру на ціль
    TeamCheck = false,          -- true = не бити союзників
    RequireTool = true,         -- Бити лише якщо в руках інструмент (меч)
}
-- =====================================

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local lastClick = 0
local currentTarget = nil
local heartbeatConn = nil

local mouse = localPlayer:GetMouse()

-- ---------- Допоміжні ----------

local function isAlly(player)
    if not CONFIG.TeamCheck then return false end
    return player.Team ~= nil and player.Team == localPlayer.Team
end

local function getEquippedTool()
    local char = localPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Tool")
end

local function pickTarget()
    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closest, closestDist = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        local pChar = player.Character
        if not pChar then continue end

        local pRoot = pChar:FindFirstChild("HumanoidRootPart")
        local pHum = pChar:FindFirstChildOfClass("Humanoid")
        if not pRoot or not pHum or pHum.Health <= 0 then continue end
        if isAlly(player) then continue end

        local dist = (pRoot.Position - hrp.Position).Magnitude
        if dist <= CONFIG.Radius and dist < closestDist then
            closestDist = dist
            closest = { player = player, character = pChar, root = pRoot }
        end
    end

    return closest
end

-- ---------- Основна логіка ----------

local function onHeartbeat()
    if not CONFIG.Enabled then return end

    local char = localPlayer.Character
    if not char then return end
    
    local tool = getEquippedTool()
    if CONFIG.RequireTool and not tool then
        return -- Чекаємо, поки візьмемо меч у руки
    end

    -- Оновлюємо ціль
    if not currentTarget or not currentTarget.root.Parent or currentTarget.root.Parent:FindFirstChildOfClass("Humanoid").Health <= 0 then
        currentTarget = pickTarget()
    end

    if not currentTarget then return end

    local targetRoot = currentTarget.root

    -- 1. Поворот камери (Aimbot)
    if CONFIG.AutoAim and camera then
        camera.CFrame = CFrame.new(camera.CFrame.Position, targetRoot.Position)
    end

    -- 2. Спам кліками
    local now = tick()
    local clickDelay = 1 / CONFIG.CPS

    if now - lastClick >= clickDelay then
        lastClick = now

        if tool then
            -- Спосіб 1: Активація інструменту (меча)
            pcall(function()
                tool:Activate()
            end)
        else
            -- Спосіб 2: Емуляція кліку миші (якщо інструмент не потрібен)
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton1(Vector2.new(mouse.X, mouse.Y))
            end)
        end
    end
end

-- ---------- Публічне API ----------

function KillAura.Start()
    if CONFIG.Enabled then return end
    CONFIG.Enabled = true
    lastClick = 0

    heartbeatConn = RunService.Heartbeat:Connect(onHeartbeat)
    print("[KillAura] Увімкнено (PvP Mode)")
end

function KillAura.Stop()
    if not CONFIG.Enabled then return end
    CONFIG.Enabled = false

    if heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end
    currentTarget = nil
    print("[KillAura] Вимкнено")
end

function KillAura.Toggle()
    if CONFIG.Enabled then KillAura.Stop() else KillAura.Start() end
    return CONFIG.Enabled
end

function KillAura.SetConfig(key, value)
    if CONFIG[key] ~= nil then
        CONFIG[key] = value
        return true
    end
    return false
end

return KillAura
