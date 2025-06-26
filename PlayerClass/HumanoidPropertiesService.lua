--!strict
-- @author : BakedAleska
-- @date : 06/20/2025

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
local humanoidProperties = {}
humanoidProperties.__index = humanoidProperties

----------
-- HOLD --
----------
local humanoidData = {}

-----------
-- TYPES --
-----------
type ALLOWED_PROPERTIES = "WalkSpeed" | "JumpPower" | "Health"

export type MODIFIER = {
	property: ALLOWED_PROPERTIES, --> Humanoid Property being affected.
	value: number, --> What is this property being set to?
	priority: number, --> 2 Takes priority over 1, If the priority is the same on two different modifiers it prefers the newer modifier.
	last: boolean?, --> If this is true or set at all, reset priorities on this property.
}

----------------------
-- HELPER FUNCTIONS --
----------------------
local propertySetters: { [ALLOWED_PROPERTIES]: (Humanoid, number) -> () } = {
	WalkSpeed = function(h, v)
		h.WalkSpeed = v
	end,
	JumpPower = function(h, v)
		h.JumpPower = v
	end,
	Health = function(h, v)
		h.Health = v
	end,
}

function humanoidProperties.bind(player: Player)
	local character = player.Character :: Model
	if not character then
		return
	end
	local _humanoid = character:FindFirstChildOfClass("Humanoid")
	if not _humanoid then
		return
	end

	humanoidData[player] = {
		humanoid = _humanoid, --> Reference to the actual humanoid to avoid grabbing it multiple times throughout the module.
		modifiers = {}, --> The list of modifiers
	}
end

--[[
@WARNING! DURATION IS INTENDED TO BE HANDLED INSIDE OF INDIVIDUAL ACTION RUNTIME.
MAKE SURE THIS FUNCTION IS RUN WITH A TASK.DELAY AFTER THAT INCLUDES A TRUE LAST FLAG.

@Param - player: The player who will be affected.

|--> @Param - modifier: --------------------------------|

@SubParam - property: The humanoid property affected, 
@SubParam - value: The value this property is set to, 
@SubParam - priority: Number that determines if other calls to this property will overwrite it

|---------------------------------------------------|
}
--]]
function humanoidProperties.applyModifier(player: Player, modifier: MODIFIER)
	local data = humanoidData[player]
	if not data then
		return
	end

	local current = data.modifiers[modifier.property]
	if current and current.priority > modifier.priority then
		return
	end

	data.modifiers[modifier.property] = modifier --> Set data.

	if modifier.last then
		data.modifiers[modifier.property] = nil
	end

	local setter = propertySetters[modifier.property] --> Actually set the humanoid.
	if setter then
		setter(data.humanoid, modifier.value)
	else
		warn("[HumanoidProperties] Missed setter.")
		return --> If the property cant be set, return here.
	end
end

function humanoidProperties.cleanup(player: Player)
	humanoidData[player] = nil
end

return humanoidProperties
