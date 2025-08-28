--!nonstrict
-- @author : BakedAleska
-- @date : 08/23/2025

--[[
  DISCLAIMER:
  This script been adapted for demonstration and portfolio purposes only.
  All rights to the original implementation are retained by the creator.
  Do not reuse, redistribute, or repurpose this script without explicit permission.
]]

-----------
-- FLAGS --
-----------
local RULE_STATEMENTS = true

--------------
-- SERVICES --
--------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
------------
-- IMPORT --
------------
local Entity = require(ServerScriptService.Server.Classes.Entity)
local TransitionRules = require(ServerScriptService.Server.Classes.TransitionRules)
local Cooldowns = require(ServerScriptService.Server.Configs.Cooldowns)
local MarkerService = require(ServerScriptService.Server.Services.MarkerService)
local signal = require(ReplicatedStorage.Packages.signal)
local InterfaceService = require(ReplicatedStorage.Shared.Services.InterfaceService)

-----------------------
-- PRIVATE FUNCTIONS --
-----------------------
local function DEBUG(Character, Current: string)
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		InterfaceService.Handle(Player, "State", { Current = Current })
	end
end

----------------------
-- PUBLIC FUNCTIONS --
----------------------

--> Declare
local StateMachine = {}
StateMachine.__index = StateMachine
StateMachine.__name = "StateMachine"

function StateMachine.new(Entity: Model)
	local self = setmetatable({
		Entity = Entity,
		States = {},
		Current = nil,
		Last = nil,
		Queue = {} :: { { Name: string, Params: { Payload: {}?, Duration: number? }? } },
		StateChanged = signal.new(),
		Rules = TransitionRules.new(),
	}, StateMachine)

	return self
end

--> Call first, nothing will run without : Init. Moves the state machine into a current and a last to ensure no errors.
function StateMachine:Init(Initial: string, With: Folder)
	local function POPULATE(Folder: Folder)
		for _, Object in ipairs(Folder:GetChildren()) do
			if Object:IsA("ModuleScript") then
				local Success, Result = pcall(require, Object)
				if not Success then
					warn(`[FSM] Failed to require {Object.Name}: {Result}`)
					continue
				end

				if type(Result) == "table" and Result.new then
					local instance = Result.new(self)
					if typeof(instance.Name) ~= "string" then
						warn(`[FSM] State instance from {Object.Name} missing valid Name.`)
						continue
					end

					if self.States[instance.Name] then
						warn(`[FSM] Duplicate state '{instance.Name}' skipped.`)
						continue
					end

					self.States[instance.Name] = instance
				else
					warn(`[FSM] Module {Object.Name} did not return a valid state.`)
				end
			elseif Object:IsA("Folder") then
				POPULATE(Object)
			end
		end
	end

	POPULATE(With)

	POPULATE(ServerScriptService.Server.Components.States.Shared)

	local Target = self.States[Initial]
	if not Target then
		warn("[FiniteStateMachine] No such state exists. Cannot Init.")
		return
	end

	self.Current = Target
	self.Current.EnteredTime = workspace:GetServerTimeNow()
	self.Current:OnEnter()

	self.StateChanged:Fire(nil, Target.Name)
	DEBUG(self.Entity, self.Current.Name)

	RunService.Heartbeat:Connect(function()
		if not self.Current then
			return
		end

		local Duration = self.Current.Duration or 0
		local Elapsed = workspace:GetServerTimeNow() - self.Current.EnteredTime

		if Duration > 0 and Elapsed >= Duration then
			if #self.Queue > 0 then
				local Queued = table.remove(self.Queue, 1)
				if Queued then
					self:Transition(Queued.Name, Queued.Params)
				end
			else
				self:Transition("Idle")
			end
			return
		end

		if typeof(self.Current.Update) == "function" then
			pcall(function()
				self.Current:Update()
			end)
		end
	end)
end

--> Transition into X state with arguments. WILL NOT ADD TO QUEUE.
function StateMachine:Transition(Next: string, Params: { Payload: {}?, Duration: number? }?)
	local Now = workspace:GetServerTimeNow()
	--! V E R I F Y ! --
	local Target = self.States[Next]

	if not Target then
		warn("[StateMachine], Cannot enter invalid target. Are you sure this state exists?")
		return
	end

	if not self:Check(Next) then
		warn("[StateMachine], Failed check.")
		return
	end

	local EntityInstance = Entity.Get(self.Entity)
	if not EntityInstance then
		warn("[StateMachine], Failed entity fetch.")
		return
	end

	if EntityInstance.Components.Cooldown:Get(Next) then
		print("On Cooldown.")
		return
	end

	--> REFRESH
	if Target == self.Current then
		local Elapsed = Now - self.Current.EnteredTime
		if self.Current.Duration > 0 and Elapsed < self.Current.Duration then
			self:Refresh(Target.Name, Params)
			return
		end
	end

	if Next ~= "Idle" then
		MarkerService.Cancel(self.Entity)
	end

	self.Last = self.Current
	Target.EnteredTime = Now
	Target.Duration = Params and Params.Duration or 0

	--> RETURN IF ENTER FAILED.
	local Ok, Result = pcall(function()
		return Target:OnEnter(Params and Params.Payload)
	end)

	if not Ok or Result == false then
		local ErrorMessage = if Ok then "Transition returned false" else Result

		warn(`[FSM] Transition to {Next} failed. Restoring to {self.Current.Name}. Error: {ErrorMessage}`)

		local Success, RestoreError = pcall(function()
			self.Current:OnEnter()
		end)

		if not Success then
			warn(`[FSM] Error while restoring {self.Current.Name}: {RestoreError}`)
		end

		self.Last = nil
		return
	end

	self.StateChanged:Fire(self.Current.Name, Target.Name)
	self.Current = Target
	self.Last:OnExit()
	DEBUG(self.Entity, self.Current.Name)
end

--> Adds a state to the queue effectively making it go next, only this state will be added and the queue will be cleared.
function StateMachine:After(State: string, Params: { Payload: {}?, Duration: number? }?)
	table.clear(self.Queue)

	table.insert(self.Queue, {
		Name = State,
		Params = Params,
	})
end

--> Add a state to the queue.
function StateMachine:Queue(State: string, Params: { Payload: {}?, Duration: number? }?)
	table.insert(self.Queue, {
		Name = State,
		Params = Params,
	})
end

--> Refreshes the state calling both OnExit and OnEnter again. IGNORES RULES. Will always refresh.
function StateMachine:Refresh(Current: string, Params: { Payload: {}?, Duration: number? }?)
	local State = self.States[Current]
	if not State or State ~= self.Current then
		warn("[FiniteStateMachine] Cannot refresh. State invalid or not current.")
		return
	end

	self.Current.EnteredTime = workspace:GetServerTimeNow()
	self.Current.Duration = Params and Params.Duration
	self.Current:OnEnter(Params and Params.Payload)
	DEBUG(self.Entity, self.Current.Name)
end

--> Extends the current duration of a state without calling OnExit.
function StateMachine:Extend(Current: string, Extra: number)
	local State = self.States[Current]
	if not State or State ~= self.Current then
		warn("[FiniteStateMachine] Cannot extend. State invalid or not current.")
		return
	end

	if type(State.Duration) ~= "number" then
		State.Duration = 0
	end

	State.Duration += Extra
	DEBUG(self.Entity, self.Current.Name)
end

function StateMachine:Clear()
	if #self.Queue > 0 then
		table.clear(self.Queue)
	end
end

--> Returns a boolean when given a state name, lets other scripts know what states can be moved into and when.
function StateMachine:Check(Target: string): boolean
	--> VERIFY INIT
	if not self.Current then
		warn("[FiniteStateMachine] self.Current is invalid. Did you forget to call :Init()?")
		return false
	end
	--> RULES CHECK
	if not self.Rules:Can(self.Current.Name, Target) then
		if RULE_STATEMENTS then
			warn("[StateMachine] - Rules : Cannot move into: " .. Target .. " From: " .. self.Current.Name)
		end
		return false
	end

	return true
end

--> A less harsh exit, ensures that the state being exited from, is accurate and allows a movement into idle.
function StateMachine:Return(From: string)
	if self.Current and self.Current.Name == From then
		self:Transition("Idle")
	end
end

--> Forces the state machine into idle.
function StateMachine:Exit()
	if not self.Current then
		warn("[FiniteStateMachine] Cannot exit. No current state. Did you forget to call :Init()?")
		return
	end

	if self.Current.Entered then
		self.Current:OnExit()
		self.Current.Entered = false
	end

	self.Last = self.Current
	self.Current = nil
end

function StateMachine:Destroy()
	if self.Current then
		pcall(function()
			self.Current:OnExit()
		end)
	end

	for _, State in pairs(self.States) do
		pcall(function()
			if typeof(State.Destroy) == "function" then
				State:Destroy()
			end
		end)
	end

	table.clear(self.States)
	table.clear(self.Queue)
	self.Current = nil
	self.Last = nil
	self.Entity = nil
end

return StateMachine
