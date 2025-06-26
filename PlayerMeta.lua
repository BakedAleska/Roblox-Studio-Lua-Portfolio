--!strict
-- @author : BakedAleska
-- @date : 05/30/2025

--[[
  DISCLAIMER:
  This script is a modified version of code originally developed for a specific game project.
  It has been adapted for demonstration and portfolio purposes only.
  All rights to the original implementation are retained by the creator.
  Do not reuse, redistribute, or repurpose this script without explicit permission.
]]

----------
-- MAIN --
----------
local playerMeta = {}
playerMeta.__index = playerMeta

--------------
-- SERVICES --
--------------
local serverStorage = game:GetService("ServerStorage")
local serverScriptService = game:GetService("ServerScriptService")

function playerMeta.new(_player: Player): any --> Creates a new player object to be handled as a class.
	local self = setmetatable({
		_player = _player,
	}, playerMeta)
	return self
end

local function _appearance(_player: Player) --> Helper function to determine the starting appearance of a players character.
	local character = _player.Character
	if not character then
		return
	end
	_player:ClearCharacterAppearance()

	for _, forcefield in pairs(character:GetDescendants()) do
		if forcefield:IsA("ForceField") then
			forcefield:Destroy()
		end
	end
end


function playerMeta:onCharacterAdded(character: Model) --> Runs character specific functions on character added.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.Died:Once(
		function() --> This is called everytime a new character is added. No need for connect, Once() suffices.
			self._player:LoadCharacter()
		end
	)

	for _, config in pairs(serverStorage.HumanoidConfigs:GetChildren()) do
		if config:IsA("Configuration") then
			local clone = config:Clone()
			clone.Parent = humanoid
		end
	end

	self._player.CharacterAppearanceLoaded:Once(function() --> Same reasoning for Once() here.
		_appearance(self._player)
	end)
end



function playerMeta:onPlayerAdded() --> Runs player specific functions on player added.
	self._player.CharacterAdded:Connect(function(character)
		self:onCharacterAdded(character)
	end)

	if not self._player.Character then
		self._player:LoadCharacter() --> Initial load. This is needed to start the game. !REMOVE ON MAIN MENU CREATION!
	end
end

return playerMeta
