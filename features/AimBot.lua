--!strict
-- features/AimBot.lua
-- Модуль Aimbot для NOVA Mod Menu

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local AimBot = {}

-- ============ НАЛАШТУВАННЯ ============
local CONFIG = {
    Enabled = false,
    -- Основне
    FOV = 120,                  -- радіус FOV у пікселях (0 = весь екран)
    Smoothness = 0.25,          -- 0 = миттєво, 1 = дуже повільно (інтерполяція)
    MaxDistance = 500,          -- максимальна дистанція до цілі (studs)
    -- Що наводити
    TargetPart = "Head",        -- "Head" | "HumanoidRootPart" | "UpperTorso" | "Torso"
    -- Фільтри
    TeamCheck = true,           -- ігнорувати союзників
    WallCheck = true,           -- не наводити крізь стіни
    IgnoreFriends = true,       -- ігнорувати друзів
    -- Активація
    ActivationMode = "Hold",    -- "Hold" (права кнопка миші) | "Toggle" | "Always"
    -- Prediction
    Prediction = true,          -- враховувати рух цілі
    PredictionFactor = 0.15,    -- коефіцієнт prediction (сек)
    -- Візуал
    ShowFOV = true,             -- показувати FOV-коло
    ShowTargetLine = true,      -- лінія до цілі
}
-- =====================================

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Стан
local isActive = false -- чи затиснута/увімкнена активація
local currentTarget = nil -- {player, character, part, humanoid}
local connections = {}
local fovGui = nil
local targetLine = nil

-- ---------- Допоміжні ----------

local function isAlly(player)
    if not CONFIG.TeamCheck then return false end
    return player.Team ~= nil and player.Team == localPlayer.Team
end

local function isFriend(player)
    if not CONFIG.IgnoreFriends then return false end
    local ok, isFriendResult = pcall(function()
        return localPlayer:IsFriendsWith(player.UserId)
    end)
    return ok and isFriendResult
end

local function hasLineOfSight(origin, targetPart)
    if not CONFIG.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        localPlayer.Character,
        targetPart.Parent,
    }
    local result = Workspace:Raycast(origin, targetPart.Position - origin, params)
    return result == nil
end

local function isValidTarget(player, character)
    if not player or not character then return false end
    if player == localPlayer then return false end
    if isAlly(player) or isFriend(player) then return false end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return true
end

local function getTargetPart(character)
    return character:FindFirstChild(CONFIG.TargetPart)
        or character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Head")
end

local function getTargetVelocity(part)
    if not CONFIG.Prediction or not part then return Vector3.zero end
    local ok, velocity = pcall(function()
        return part.AssemblyLinearVelocity
    end)
    return ok and velocity or Vector3.zero
end

-- ---------- Вибір цілі ----------

local function pickTarget()
    if not camera then return nil end

    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local fovRadius = CONFIG.FOV
    if fovRadius <= 0 then fovRadius = math.huge end

    local closest, closestDist = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        local character = player.Character
        if not isValidTarget(player, character) then continue end

        local part = getTargetPart(character)
        if not part then continue end

        local myChar = localPlayer.Character
        local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHRP then continue end

        local distance = (part.Position - myHRP.Position).Magnitude
        if distance > CONFIG.MaxDistance then continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local pixelDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if pixelDist > fovRadius then continue end

        if not hasLineOfSight(camera.CFrame.Position, part) then continue end

        -- Пріоритет: ближче до центру екрана, потім ближче фізично
        local score = pixelDist + distance * 0.1
        if score < closestDist then
            closestDist = score
            closest = {
                player = player,
                character = character,
                part = part,
                humanoid = character:FindFirstChildOfClass("Humanoid"),
            }
        end
    end

    return closest
end

-- ---------- Обертання камери ----------

local function lerpCFrame(a, b, t)
    local pos = a.Position:Lerp(b.Position, t)
    local rot = a.Rotation:Lerp(b.Rotation, t)
    return CFrame.new(pos) * rot
end

local function aimAt(target)
    if not target or not target.part or not camera then return end

    local part = target.part
    local aimPos = part.Position

    -- Prediction
    if CONFIG.Prediction then
        local velocity = getTargetVelocity(part)
        aimPos = aimPos + velocity * CONFIG.PredictionFactor
    end

    local desired = CFrame.new(camera.CFrame.Position, aimPos)
    local smooth = math.clamp(1 - CONFIG.Smoothness, 0.05, 1)
    camera.CFrame = lerpCFrame(camera.CFrame, desired, smooth)
end

-- ---------- Візуал ----------

local function createFOVGui()
    if not CONFIG.ShowFOV then return end
    if fovGui then fovGui:Destroy() end
    if CONFIG.FOV <= 0 then return end

    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        playerGui = localPlayer:WaitForChild("PlayerGui", 5)
        if not playerGui then return end
    end

    local old = playerGui:FindFirstChild("AimbotFOV")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AimbotFOV"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    local circle = Instance.new("Frame")
    circle.Size = UDim2.fromOffset(CONFIG.FOV * 2, CONFIG.FOV * 2)
    circle.Position = UDim2.new(0.5, -CONFIG.FOV, 0.5, -CONFIG.FOV)
    circle.BackgroundTransparency = 1
    circle.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circle

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(130, 104, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = circle

    fovGui = gui
end

local function createTargetLine()
    if not CONFIG.ShowTargetLine then return end

    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end

    local old = playerGui:FindFirstChild("AimbotTargetLine")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AimbotTargetLine"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    frame.BorderSizePixel = 0
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Visible = false
    frame.Parent = gui

    targetLine = { gui = gui, frame = frame }
end

local function updateTargetLine(target)
    if not targetLine then return end
    if not target or not camera then
        targetLine.frame.Visible = false
        return
    end

    local part = target.part
    if not part then
        targetLine.frame.Visible = false
        return
    end

    local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen then
        targetLine.frame.Visible = false
        return
    end

    targetLine.frame.Visible = true
    targetLine.frame.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
    targetLine.frame.Size = UDim2.fromOffset(10, 10)
    local corner = targetLine.frame:FindFirstChildOfClass("UICorner")
    if not corner then
        corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = targetLine.frame
    end
end

local function destroyVisuals()
    if fovGui then fovGui:Destroy() fovGui = nil end
    if targetLine then targetLine.gui:Destroy() targetLine = nil end
end

-- ---------- Активація ----------

local function shouldBeActive()
    if CONFIG.ActivationMode == "Always" then return true end
    if CONFIG.ActivationMode == "Toggle" then return isActive end
    return isActive -- Hold
end

local function bindActivation()
    local inputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if CONFIG.ActivationMode == "Hold" then
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                isActive = true
            end
        elseif CONFIG.ActivationMode == "Toggle" then
            if input.KeyCode == Enum.KeyCode.E then
                isActive = not isActive
            end
        end
    end)

    local inputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if CONFIG.ActivationMode == "Hold" then
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                isActive = false
            end
        end
    end)

    table.insert(connections, inputBeganConn)
    table.insert(connections, inputEndedConn)
end

-- ---------- Основний цикл ----------

local function onRenderStep()
    if not CONFIG.Enabled then return end
    if not shouldBeActive() then
        currentTarget = nil
        updateTargetLine(nil)
        return
    end

    if not camera then
        camera = Workspace.CurrentCamera
    end
    if not camera then return end

    if not currentTarget or not isValidTarget(currentTarget.player, currentTarget.character) then
        currentTarget = pickTarget()
    end

    if currentTarget then
        aimAt(currentTarget)
        updateTargetLine(currentTarget)
    else
        updateTargetLine(nil)
    end
end

-- ---------- Публічне API ----------

function AimBot.Start()
    if CONFIG.Enabled then return end
    CONFIG.Enabled = true

    camera = Workspace.CurrentCamera
    createFOVGui()
    createTargetLine()
    bindActivation()

    table.insert(connections, RunService.RenderStepped:Connect(onRenderStep))

    print("[AimBot] Увімкнено")
end

function AimBot.Stop()
    if not CONFIG.Enabled then return end
    CONFIG.Enabled = false
    isActive = false
    currentTarget = nil

    for _, conn in ipairs(connections) do
        if conn.Connected then conn:Disconnect() end
    end
    connections = {}

    destroyVisuals()
    print("[AimBot] Вимкнено")
end

function AimBot.Toggle()
    if CONFIG.Enabled then AimBot.Stop() else AimBot.Start() end
    return CONFIG.Enabled
end

function AimBot.IsEnabled()
    return CONFIG.Enabled
end

function AimBot.SetConfig(key, value)
    if CONFIG[key] == nil then
        warn(("[AimBot] Невідомий параметр: %s"):format(tostring(key)))
        return false
    end
    CONFIG[key] = value

    -- Оновлення візуалів при зміні FOV
    if key == "FOV" and CONFIG.Enabled then
        createFOVGui()
    end
    if key == "ShowFOV" and CONFIG.Enabled then
        if value then createFOVGui() else
            if fovGui then fovGui:Destroy() fovGui = nil end
        end
    end
    if key == "ShowTargetLine" and CONFIG.Enabled then
        if value then createTargetLine() else
            if targetLine then targetLine.gui:Destroy() targetLine = nil end
        end
    end

    return true
end

function AimBot.GetConfig()
    local copy = {}
    for k, v in pairs(CONFIG) do copy[k] = v end
    return copy
end

function AimBot.GetCurrentTarget()
    return currentTarget and currentTarget.player or nil
end

return AimBot
