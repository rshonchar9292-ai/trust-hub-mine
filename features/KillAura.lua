--!strict
-- features/KillAura.lua
-- Модуль Kill Aura для NOVA Mod Menu

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local KillAura = {}

-- ============ НАЛАШТУВАННЯ ============
local CONFIG = {
    Radius = 20,          -- радіус ураження (studs)
    Damage = 25,          -- шкода за один удар
    Cooldown = 0.35,      -- інтервал між ударами (сек)
    MaxParts = 30,        -- ліміт частин для перевірки
    TeamCheck = false,    -- true = не бити союзників по команді
    WallCheck = false,    -- true = не бити крізь стіни (повільніше)
    ShowIndicator = true, -- показувати індикатор радіусу
}
-- =====================================

local enabled = false
local lastAttack = 0
local heartbeatConn = nil
local indicator = nil

local localPlayer = Players.LocalPlayer

-- ---------- Допоміжні функції ----------

local function getCharacter()
    local char = localPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return nil end
    return char, hrp, hum
end

local function isAlly(player)
    if not CONFIG.TeamCheck then return false end
    return player.Team == localPlayer.Team and player.Team ~= nil
end

local function hasLineOfSight(origin, targetPart)
    if not CONFIG.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { localPlayer.Character }
    local result = Workspace:Raycast(origin, targetPart.Position - origin, params)
    return result == nil or result.Instance:IsDescendantOf(targetPart.Parent)
end

local function createIndicator()
    if not CONFIG.ShowIndicator then return end
    if indicator then indicator:Destroy() end

    local part = Instance.new("Part")
    part.Name = "KillAuraIndicator"
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(CONFIG.Radius * 2, CONFIG.Radius * 2, CONFIG.Radius * 2)
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = Enum.Material.ForceField
    part.Color = Color3.fromRGB(130, 104, 255)
    part.Transparency = 0.85
    part.Parent = Workspace

    indicator = part
end

local function updateIndicator(hrp)
    if indicator and hrp then
        indicator.Position = hrp.Position
    end
end

local function destroyIndicator()
    if indicator then
        indicator:Destroy()
        indicator = nil
    end
end

-- ---------- Основна логіка удару ----------

local function performAttack()
    local char, hrp, hum = getCharacter()
    if not char then return end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    params.MaxParts = CONFIG.MaxParts

    local parts = Workspace:GetPartBoundsInRadius(hrp.Position, CONFIG.Radius, params)
    local hitAny = false

    for _, part in ipairs(parts) do
        local model = part.Parent
        if not model then continue end

        local targetHum = model:FindFirstChildOfClass("Humanoid")
        if not targetHum or targetHum.Health <= 0 then continue end

        local targetPlayer = Players:GetPlayerFromCharacter(model)
        if not targetPlayer or targetPlayer == localPlayer then continue end
        if isAlly(targetPlayer) then continue end

        if CONFIG.WallCheck then
            local targetRoot = model:FindFirstChild("HumanoidRootPart")
            if not targetRoot or not hasLineOfSight(hrp.Position, targetRoot) then
                continue
            end
        end

        -- Завдаємо шкоди
        targetHum:TakeDamage(CONFIG.Damage)
        hitAny = true

        -- Візуальний ефект на цілі
        local targetRoot = model:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local highlight = Instance.new("Highlight")
            highlight.FillColor = Color3.fromRGB(255, 80, 80)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.FillTransparency = 0.4
            highlight.Parent = model
            task.delay(0.15, function()
                if highlight then highlight:Destroy() end
            end)
        end
    end

    if hitAny then
        lastAttack = tick()
    end
end

-- ---------- Публічне API ----------

function KillAura.Start()
    if enabled then return end
    enabled = true
    lastAttack = 0

    createIndicator()

    heartbeatConn = RunService.Heartbeat:Connect(function()
        if not enabled then return end

        local _, hrp = getCharacter()
        if not hrp then return end

        updateIndicator(hrp)

        local now = tick()
        if now - lastAttack < CONFIG.Cooldown then return end

        performAttack()
    end)

    print("[KillAura] Увімкнено")
end

function KillAura.Stop()
    if not enabled then return end
    enabled = false

    if heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end

    destroyIndicator()
    print("[KillAura] Вимкнено")
end

function KillAura.Toggle()
    if enabled then
        KillAura.Stop()
    else
        KillAura.Start()
    end
    return enabled
end

function KillAura.IsEnabled()
    return enabled
end

function KillAura.SetConfig(key, value)
    if CONFIG[key] == nil then
        warn(("[KillAura] Невідомий параметр: %s"):format(tostring(key)))
        return false
    end
    CONFIG[key] = value
    if key == "Radius" and enabled then
        createIndicator()
    end
    return true
end

function KillAura.GetConfig()
    local copy = {}
    for k, v in pairs(CONFIG) do copy[k] = v end
    return copy
end

return KillAura
