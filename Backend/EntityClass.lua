--!strict
-- @author : BakedAleska
-- @date : 08/23/2025

--[[
  DISCLAIMER:
  This script has been adapted for demonstration and portfolio purposes only.
  All rights to the original implementation are retained by the creator.
  Do not reuse, redistribute, or repurpose this script without explicit permission.
]]


--------------
-- SERVICES --
--------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
------------
-- IMPORT --
------------
local maid = require(ReplicatedStorage.Packages.maid)

-----------
-- TYPES --
-----------
export type ENTITY_PARAMS = {
	Entity: Model,
	Controller: any,
}

export type ENTITY = {
	Entity: Model,
	Controller: any,
	Components: {},
	GiveComponent: (self: ENTITY, Component: any) -> (),
	RemoveComponent: (self: ENTITY, Component: any) -> (),
	Destroy: (self: ENTITY) -> (),
}

--> Declare
local Entity = {}
Entity.__index = Entity

local _Registry = {} :: { [Model]: any }

--> Create a new entity. Entity will practically be unusable until AddComponent is called for each component.
function Entity.new(Params: ENTITY_PARAMS)
	local self = setmetatable({
		Entity = Params.Entity,
		Maid = maid.new(),
		Controller = Params.Controller,
		Components = {},
	}, Entity)

	_Registry[self.Entity] = self

	return self
end

--> Returns an entity instance.
function Entity.Get(Model: Model): ENTITY?
	if _Registry[Model] then
		return _Registry[Model]
	end

	return nil
end

--> Adds a given component module to an entity.
function Entity:GiveComponent(Component: any)
	if typeof(Component) ~= "table" then
		warn("[Entity] Attempted to give invalid component (not a table).")
		return
	end

	if self.Components[Component.__name] then
		warn("[Entity] Component already exits. Will not return, but be mindful.")
	end

	self.Components[Component.__name] = Component

	self.Maid:GiveTask(Component)
end

--> Takes away a given component module from an entity.
function Entity:RemoveComponent(Component: any)
	if typeof(Component) ~= "table" then
		warn("[Entity] Attempted to remove invalid component (not a table).")
		return
	end

	if not self.Components[Component.__name] then
		warn("[Entity] Can not remove nonexistent component. Are you sure you added it?")
		return
	end

	self.Maid[Component.__name] = nil

	self.Components[Component.__name] = nil
end

--> Cleanup
function Entity:Destroy()
	if _Registry[self.Entity] then
		_Registry[self.Entity] = nil
	end

	self.Maid:Destroy()
	self.Maid = nil

	self.Controller:Destroy()
	self.Controller = nil

	self.Entity:Destroy()
	warn("[Entity], When cleaning up; Destroy is being called on the entity instance. This might be an issue.")
	self.Entity = nil
end

return Entity
