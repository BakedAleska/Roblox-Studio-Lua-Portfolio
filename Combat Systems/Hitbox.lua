--!strict
-- @author : BakedAleska
-- @date : 06/09/2025

--[[
  DISCLAIMER:
  This script is a modified version of code originally developed for a specific game project.
  It has been adapted for demonstration and portfolio purposes only.
  All rights to the original implementation are retained by the creator.
  Do not reuse, redistribute, or repurpose this script without explicit permission.
]]

-- This script was inspired by @Tekleed. And may contain modified code from within: "Bounding Hitboxes | How It Works | Roblox Studio".

----------
-- MAIN --
----------
local hitboxClass = {}
hitboxClass.__index = hitboxClass

-----------
-- FLAGS --
-----------
local VISUALIZE_FLAG = true
local VISUALIZE_LIFETIME = 0.1

--------------
-- SERVICES --
--------------
local serverScriptService = game:GetService("ServerScriptService")
local debrisService = game:GetService("Debris")

-----------
-- TYPES --
-----------
export type CONFIG = { -- Everything but the adornee is optional for ease of use.
	adornee: BasePart,
	offset: number?,
	damage: number?,
	duration: number?,
	size: Vector3?,
}

----------
-- HOLD --
----------
local FILTER_PARTS = { --> ONLY THESE PARTS ARE ALLOWED <
	"Head",
	"Left Arm",
	"Right Arm",
	"HumanoidRootPart",
	"Left Leg",
	"Right Leg",
	"Torso",
}



function hitboxClass.new(config: CONFIG): any
	local self = setmetatable({
		_connections = {}, -- : Holds RunService connections for easy cleanup.
		_inRange = {},
		adornee = config.adornee,
		offset = config.offset or 0,
		damage = config.damage or 0,
		duration = config.duration or 0,
		size = config.size or Vector3.new(1, 1, 1),
	}, hitboxClass)
	return self
end



----------------------
-- HELPER FUNCTIONS --
----------------------
local function _visualize(self: any, success: boolean)
	local blank = Color3.new(1, 1, 1)
	local red = Color3.new(1, 0, 0)
	local part = Instance.new("Part")
	local highlight = Instance.new("Highlight")
	local model = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")

	model.Parent = workspace.Temp
	humanoid.Parent = model

	part.Parent = model
	part.Color = success and red or blank
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = self.CF
	part.Size = self.size
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.9
	part.CastShadow = false

	highlight.Parent = model
	highlight.Adornee = model
	highlight.OutlineColor = success and red or blank
	highlight.FillTransparency = 1

	debrisService:AddItem(model, VISUALIZE_LIFETIME)
end



local function _filter(list: { BasePart }): { Model }
	if #list == 0 then
		return {}
	end
	local found: { Model } = {}
	for _, part in list do
		if table.find(FILTER_PARTS, part.Name) then
			local model = part:FindFirstAncestorOfClass("Model")
			if not model then
				continue
			end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				continue
			end

			local exists = table.find(found, model)
			if exists then
				continue
			end

			table.insert(found, model)
		end
	end
	return found
end



function hitboxClass:area(): { Model }
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = { self.adornee.Parent }
	params.FilterType = Enum.RaycastFilterType.Exclude

	self.CF = self.adornee:GetPivot() * CFrame.new(0, 0, -self.offset) --> Set a CFrame with offset X from the front of the adornee.
	self.partList = workspace:GetPartBoundsInBox(self.CF, self.size, params)
	local seenList = _filter(self.partList) --> LIST OF MODELS
	local success = #seenList > 0

	if VISUALIZE_FLAG then
		_visualize(self, success)
	end

	for _, model in pairs(seenList) do
		if model:IsA("Model") then
			_damage(self, model)
		end
	end

	return seenList
end

return hitboxClass
