local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TargetESP = {}
local targetModel
local gui
local renderConnection
local healthConnection
local angle = 0

local PURPLE = Color3.fromRGB(133, 98, 255)
local WHITE = Color3.fromRGB(245, 243, 255)
local MUTED = Color3.fromRGB(190, 184, 213)

local function clearVisual()
	if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
	if healthConnection then healthConnection:Disconnect(); healthConnection = nil end
	if gui then gui:Destroy(); gui = nil end
	targetModel = nil
end

local function getAdornee(model)
	if not model or not model:IsA("Model") then return nil end
	return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

function TargetESP.ClearTarget()
	clearVisual()
end

function TargetESP.SetTarget(model)
	clearVisual()
	if not model then return end
	local adornee = getAdornee(model)
	if not adornee then
		warn("[TargetESP] Target needs Head, HumanoidRootPart, or PrimaryPart")
		return
	end
	targetModel = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TargetESP"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(210, 116)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = billboard

	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(190, 52)
	card.Position = UDim2.new(0.5, -95, 0, 0)
	card.BackgroundColor3 = Color3.fromRGB(19, 17, 29)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = billboard
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = PURPLE
	cardStroke.Transparency = 0.18
	cardStroke.Thickness = 1.5
	cardStroke.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(12, 6)
	nameLabel.Size = UDim2.new(1, -24, 0, 19)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = WHITE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = model.Name
	nameLabel.Parent = card

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local healthLabel = Instance.new("TextLabel")
	healthLabel.BackgroundTransparency = 1
	healthLabel.Position = UDim2.fromOffset(12, 26)
	healthLabel.Size = UDim2.new(1, -24, 0, 16)
	healthLabel.Font = Enum.Font.Gotham
	healthLabel.TextSize = 10
	healthLabel.TextColor3 = MUTED
	healthLabel.TextXAlignment = Enum.TextXAlignment.Left
	healthLabel.Parent = card

	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromOffset(12, 44)
	barBack.Size = UDim2.new(1, -24, 0, 3)
	barBack.BackgroundColor3 = Color3.fromRGB(54, 48, 68)
	barBack.BorderSizePixel = 0
	barBack.Parent = card
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(100, 230, 155)
	bar.BorderSizePixel = 0
	bar.Parent = barBack

	local arrows = Instance.new("TextLabel")
	arrows.Name = "OrbitArrows"
	arrows.BackgroundTransparency = 1
	arrows.AnchorPoint = Vector2.new(0.5, 0.5)
	arrows.Position = UDim2.new(0.5, 0, 0, 91)
	arrows.Size = UDim2.fromOffset(54, 54)
	arrows.Font = Enum.Font.GothamBlack
	arrows.Text = "➤"
	arrows.TextSize = 39
	arrows.TextColor3 = Color3.fromRGB(105, 255, 55)
	arrows.TextStrokeColor3 = Color3.fromRGB(27, 80, 20)
	arrows.TextStrokeTransparency = 0.15
	arrows.Parent = billboard

	local function updateHealth()
		if not humanoid or humanoid.MaxHealth <= 0 then
			healthLabel.Text = "TARGET"
			bar.Size = UDim2.fromScale(0, 1)
			return
		end
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		healthLabel.Text = string.format("HP  %d / %d", math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth))
		bar.Size = UDim2.fromScale(ratio, 1)
		bar.BackgroundColor3 = Color3.fromRGB(240, 85, 105):Lerp(Color3.fromRGB(100, 230, 155), ratio)
	end
	updateHealth()
	if humanoid then healthConnection = humanoid.HealthChanged:Connect(updateHealth) end

	renderConnection = RunService.RenderStepped:Connect(function(dt)
		if not targetModel or not targetModel.Parent or not getAdornee(targetModel) then
			clearVisual()
			return
		end
		angle = (angle + dt * 150) % 360
		arrows.Rotation = angle
	end)
end

return TargetESP
