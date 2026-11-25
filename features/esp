local Players = game:GetService("Players")

local ESP = {}

local localPlayer = Players.LocalPlayer
local enabled = false
local highlights = {}

local function removeHighlight(player)
	local highlight = highlights[player]
	if highlight then
		highlight:Destroy()
		highlights[player] = nil
	end
end

local function addHighlight(player, character)
	removeHighlight(player)

	if not enabled or player == localPlayer or not character then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ModMenuHighlight"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(130, 104, 255)
	highlight.OutlineColor = Color3.fromRGB(220, 210, 255)
	highlight.FillTransparency = 0.72
	highlight.OutlineTransparency = 0.1
	highlight.Parent = character

	highlights[player] = highlight
end

function ESP.SetEnabled(value)
	enabled = value

	for _, player in ipairs(Players:GetPlayers()) do
		if enabled then
			if player.Character then
				addHighlight(player, player.Character)
			end
		else
			removeHighlight(player)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		addHighlight(player, character)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player ~= localPlayer then
		player.CharacterAdded:Connect(function(character)
			addHighlight(player, character)
		end)
	end
end

Players.PlayerRemoving:Connect(removeHighlight)

return ESP
