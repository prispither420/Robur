--[[
  Author: Prispither

  Resources:
    Champion Data: https://liquipedia.net/leagueoflegends/Amumu
	
  Basic Features:
    - Basic QWER
	- R in Combo if hit min champions
	- Auto W if in range of both minions and champs
]]

if Player.CharName ~= "Amumu" then return end

module("XDAmumu", package.seeall, log.setup)
clean.module("XDAmumu", clean.seeall, log.setup)
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local ScriptName, Version = "XDAmumu", "1.0"
--------------------------------------Imports--------------------------------------
local Menu = Libs.NewMenu
local Prediction = Libs.Prediction
local Orbwalker = Libs.Orbwalker
local CollisionLib = Libs.CollisionLib
local DamageLib = Libs.DamageLib
local SpellLib = Libs.Spell
local TargetSelector = Libs.TargetSelector

local ObjectManager = CoreEx.ObjectManager
local EventManager = CoreEx.EventManager
local Input = CoreEx.Input
local Enums = CoreEx.Enums
local Game = CoreEx.Game
local Geometry = CoreEx.Geometry
local Renderer = CoreEx.Renderer

local SpellSlots = Enums.SpellSlots
local SpellStates = Enums.SpellStates
local BuffTypes = Enums.BuffTypes
local Events = Enums.Events
local HitChance = Enums.HitChance
local HitChanceStrings = { "Collision", "OutOfRange", "VeryLow", "Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" };

local Player = ObjectManager.Player.AsHero
--------------------------------------Spells--------------------------------------


local Q = SpellLib.Skillshot({
		Slot = SpellSlots.Q,
		Range = 1100,
		Radius = 70,
		Speed = 1800,
		Delay = 0.25,
		Collisions = { Heroes = true, Minions = true, WindWall = true, Wall = false },
		UseHitbox = true,
		Type = "Linear"
    })
	
local W = SpellLib.Active({
		Slot = SpellSlots.W,
		Range = 300,
		Type = "Circular",
    })
	
local E = SpellLib.Active({
		Slot = SpellSlots.E,
        Range = 350,
		Delay = 0.25,
		Type = "Circular",
    })
	
local R = SpellLib.Active({
		Slot = SpellSlots.R,
		Range = 550,
		Delay = 0.65,
		Type = "Circular",
    })
	
--------------------------------------Other Variables--------------------------------------

local Utils = {}

local Amumu = {}

Amumu.Menu = nil
Amumu.TargetSelector = nil
Amumu.Logic = {}
Amumu.ClearLogic = {}

--------------------------------------Functions--------------------------------------

-- Checks if User has game chat open, game minimized or whether player is dead

function Utils.GameAvailable()
  return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

-- Checks if target distance is higher than min range

function Utils.WithinMinRange(Target, Min)
  local Distance = Player:EdgeDistance(Target.Position)
  if Distance >= Min then return true end
  return false
end

-- Checks if target distance is lower than max range
  
function Utils.WithinMaxRange(Target, Max)
  local Distance = Player:EdgeDistance(Target.Position)
  if Distance <= Max then return true end
  return false
end

-- Returns target count in range

function Utils.InRange(Range, Type)
  return #(Amumu.TargetSelector:GetValidTargets(Range, ObjectManager.Get("enemy", Type), false))
end

-- Checks if enemy is whitelisted

function Utils.IsWhitelisted(Target)
  Target = Target.AsHero
  return Menu.Get(Target.CharName .. Target.Handle, true)
end

-- Finds nearest minion / jungle monster

function Utils.GetMinions(Range)
  local Minions = ObjectManager.Get("all", "minions")
  
  for _, Minion in pairs(Minions) do
    Minion = Minion.AsMinion
	if
		Minion and
		Minion.IsTargetable and
		not Minion.IsJunglePlant and
		(Minion.IsEnemy or Minion.IsNeutral or Minion.IsMonster)
	then
      if Utils.WithinMaxRange(Minion, Range) then return Minion end
	end
  end

  return nil
end


--------------------------------------Spell Logic--------------------------------------


function Amumu.Logic.Q(MustUse, HitChance)
  if not MustUse then return false end
  local QTarget = Q:GetTarget()
  if
    (QTarget and
    Q:IsReady() and
    Utils.IsWhitelisted(QTarget) and
    Utils.WithinMinRange(QTarget, Orbwalker.GetTrueAutoAttackRange(QTarget)))
  then
    if Q:CastOnHitChance(QTarget, HitChance) then return true end
  end

  return false
end

function Amumu.Logic.W(MustUse)
  if not MustUse then return false end
  local WTarget = W:GetTarget()
  if not WTarget then -- Checks if any enemy in range if not then just turn W off.
    if W:GetToggleState() == 0 or W:GetToggleState() == 1 then
        return
    end
    return W:Cast()
  end
  if W:GetToggleState() == 2 then
      return
  end
  if (WTarget and W:IsReady()) then
    if W:Cast() then return true end
  end
end

function Amumu.Logic.E(MustUse)
  if not MustUse then return false end
  local ETarget = Orbwalker.GetTarget() 
  if (ETarget and E:IsReady()) then
    if E:Cast() then return true end
  end
  
end

function Amumu.Logic.R(MustUse, InRangeCount)
  if not MustUse then return false end
  local RTarget = R:GetTarget()
  if (RTarget and R:IsReady() and Utils.InRange(R.Range, "heroes") >= InRangeCount) then
    if R:Cast() then return true end
  end
end

--------------------------------------Combo Logic--------------------------------------
function Amumu.Logic.Combo()
  -- combo logic
  if (Amumu.Logic.Q(Menu.Get("Combo.Q.Use"), Menu.Get("Combo.Q.HitChance"))) then return true end
  if (Amumu.Logic.W(Menu.Get("Combo.W.Use"))) then return true end
  if (Amumu.Logic.E(Menu.Get("Combo.E.Use"))) then return true end
  if (Amumu.Logic.R(Menu.Get("Combo.R.Use"), Menu.Get("Combo.R.MinHit"))) then return true end
  return false
end

--------------------------------------Harass Logic--------------------------------------
function Amumu.Logic.Harass()
  -- combo logic
  if (Amumu.Logic.Q(Menu.Get("Harass.Q.Use"), Menu.Get("Harass.Q.HitChance"))) then return true end
  if (Amumu.Logic.W(Menu.Get("Harass.W.Use"))) then return true end
  if (Amumu.Logic.E(Menu.Get("Harass.E.Use"))) then return true end
  return false
end

--------------------------------------Jungle Logic--------------------------------------

function Amumu.ClearLogic.Q(MustUse)
  if not MustUse then return false end
  local Minion = Utils.GetMinions(Q.Range)
  if Minion and Q:IsReady() and Utils.WithinMaxRange(Minion, Q.Range) and Q:Cast(Minion) then return true end
  return false
end

function Amumu.ClearLogic.W(MustUse)
  if not MustUse then return false end
  local Minion = Utils.GetMinions(W.Range)
  if not Minion then -- Checks if any enemy in range if not then just turn W off.
    if W:GetToggleState() == 0 or W:GetToggleState() == 1 then
        return
    end
    return W:Cast()
  end
  if W:GetToggleState() == 2 then
      return
  end
  if Minion and W:IsReady() and Utils.WithinMaxRange(Minion, W.Range) and W:Cast() then return true end
  return false
end

function Amumu.ClearLogic.E(MustUse)
  if not MustUse then return false end
  local Minion = Utils.GetMinions(Q.Range)
  if Minion and E:IsReady() and Utils.WithinMaxRange(Minion, E.Range) and E:Cast() then return true end
  return false
end

function Amumu.Logic.Waveclear()

  if (Amumu.ClearLogic.Q(Menu.Get("Waveclear.Q.Use"))) then return true end
  if (Amumu.ClearLogic.W(Menu.Get("Waveclear.W.Use"))) then return true end
  if (Amumu.ClearLogic.E(Menu.Get("Waveclear.E.Use"))) then return true end

  return false
end


--------------------------------------Menu--------------------------------------

function Amumu.LoadMenu()
  Menu.RegisterMenu("XDAmumu", "XDAmumu", function ()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
      Menu.ColoredText("Combo", 0xB65A94FF, true)
      Menu.ColoredText("> Q", 0x0066CCFF, false)
      Menu.Checkbox("Combo.Q.Use", "Use", true)
      Menu.Dropdown("Combo.Q.HitChance", "HitChance", 5, HitChanceStrings)
      Menu.ColoredText("> W", 0x0066CCFF, false)
      Menu.Checkbox("Combo.W.Use", "Use", true)
      Menu.ColoredText("> E", 0x0066CCFF, false)
      Menu.Checkbox("Combo.E.Use", "Use", true)
      Menu.ColoredText("> R", 0x0066CCFF, false)
      Menu.Checkbox("Combo.R.Use", "Use", true)
      Menu.Slider("Combo.R.MinHit", "Min Hit", 2, 1, 5, 1)
      Menu.NextColumn()
      Menu.ColoredText("Harass", 0xB65A94FF, true)
      Menu.ColoredText("> Q", 0x0066CCFF, false)
      Menu.Checkbox("Harass.Q.Use", "Use", true)
      Menu.Dropdown("Harass.Q.HitChance", "HitChance", 5, HitChanceStrings)
      Menu.ColoredText("> W", 0x0066CCFF, false)
      Menu.Checkbox("Harass.W.Use", "Use", true)
      Menu.ColoredText("> E", 0x0066CCFF, false)
      Menu.Checkbox("Harass.E.Use", "Use", true)
	Menu.Separator()
		  Menu.ColoredText("Waveclear", 0xB65A94FF, true)
		  Menu.ColoredText("> Q", 0x0066CCFF, false)
		  Menu.Checkbox("Waveclear.Q.Use", "Use", true)
		  Menu.ColoredText("> W", 0x0066CCFF, false)
		  Menu.Checkbox("Waveclear.W.Use", "Use", true)
		  Menu.ColoredText("> E", 0x0066CCFF, false)
		  Menu.Checkbox("Waveclear.E.Use", "Use", true)
    end)
    Menu.Separator()
    Menu.ColumnLayout("Drawings", "Drawings", 2, true, function ()
      Menu.ColoredText("Whitelist", 0xB65A94FF, true)
      for _, Object in pairs(ObjectManager.Get("enemy", "heroes")) do
        local Handle = Object.Handle
        local Name = Object.AsHero.CharName
        Menu.Checkbox(Name .. Handle, Name, true)
      end
      Menu.NextColumn()
      Menu.ColoredText("Drawings", 0xB65A94FF, true)
      Menu.Checkbox("Drawings.Q", "Q", true)
	  Menu.Checkbox("Drawings.W", "W", true)
      Menu.Checkbox("Drawings.E", "E", true)
      Menu.Checkbox("Drawings.R", "R", true)
    end)
  end)
end

--------------------------------------Draws--------------------------------------

function Amumu.OnDraw()
  -- If player is not on screen than don't draw
  if not Player.IsOnScreen then return false end;

  -- Get spells ranges
  local Spells = { Q = Q, W = W, E = E, R = R }

  -- Draw them all
  for k, v in pairs(Spells) do
    if Menu.Get("Drawings." .. k) then
        Renderer.DrawCircle3D(Player.Position, v.Range, 30, 1, 0xFFFFFFFF)
    end
  end

  return true
end

--------------------------------------Are you in game?--------------------------------------

function Amumu.OnTick()
  -- Check if game is available to do anything
  if not Utils.GameAvailable() then return false end

  -- Get current orbwalker mode
  local OrbwalkerMode = Orbwalker.GetMode()

  -- Get the right logic func
  local OrbwalkerLogic = Amumu.Logic[OrbwalkerMode]

  -- Call it
  if OrbwalkerLogic then
    return OrbwalkerLogic()
  end

  return true
end

--------------------------------------Load Script--------------------------------------

function OnLoad()
  -- Load our menu
  Amumu.LoadMenu()

  -- Load our target selector
  Amumu.TargetSelector = TargetSelector()

  -- Register callback for func available in champion object
  for EventName, EventId in pairs(Events) do
    if Amumu[EventName] then
        EventManager.RegisterCallback(EventId, Amumu[EventName])
    end
  end

	return true
end