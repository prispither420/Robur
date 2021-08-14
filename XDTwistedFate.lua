--[[
  Author: Prispither

  Resources:
    Champion Data: https://liquipedia.net/leagueoflegends/TwistedFate
	
  Basic Features:
    - Basic QW
	- Wait W stun then Q 
	- Auto Q if CC-ed
	- Auto W for selected Card
	- Auto R Gold Card 
  TODO:

]]

if Player.CharName ~= "TwistedFate" then return end

module("XDTwistedFate", package.seeall, log.setup)
clean.module("XDTwistedFate", clean.seeall, log.setup)
local CoreEx = _G.CoreEx
local Libs = _G.Libs
local ScriptName = "XDTwistedFate"
local VERSION = "1.0.1"
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
local HitChanceStrings = {"Low", "Medium", "High", "VeryHigh", "Dashing", "Immobile" };
local CardColors = { "Blue", "Red", "Gold"};
local curTime = Game.GetTime()
local Player = ObjectManager.Player.AsHero
--------------------------------------Spells--------------------------------------


local Q = SpellLib.Skillshot({
		Slot = SpellSlots.Q,
		Range = 1450,
		Radius = 40,
		Speed = 1000,
		Delay = 0.25,
		Collisions = { Heroes = false, Minions = false, WindWall = true, Wall = false },
		UseHitbox = true,
		Type = "Linear"
    })
	
local W = SpellLib.Active({
		Slot = SpellSlots.W,
		Radius = 100,
		Speed = 1500,
    })
	
local R = SpellLib.Skillshot({
		Slot = SpellSlots.R,
		Range = 5500,
    })	

--------------------------------------Other Variables--------------------------------------

local Utils = {}
local blockList = {}

local TwistedFate = {}
TwistedFate.Events = {}
TwistedFate.Debug = {}
TwistedFate.Menu = nil
TwistedFate.TargetSelector = nil
TwistedFate.Logic = {}
TwistedFate.ClearLogic = {}
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
  return #(TwistedFate.TargetSelector:GetValidTargets(Range, ObjectManager.Get("enemy", Type), false))
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

-- Gets the card buff
function Utils.PickACard()
	local card_choice = W:GetName()
	return card_choice
end

-- Gets the card buff
function Utils.GetRPhase()
	local telport_phase = R:GetName()
	return telport_phase
end

--------------------------------------Spell Logic--------------------------------------

function TwistedFate.Logic.Q(MustUse, HitChance, cardChoice)
  if not MustUse then return false end
  local QTarget = Q:GetTarget()
  --local QTarget = Orbwalker.GetTarget() or TS:GetTarget(Q.Range + Player.BoundingRadius, true)
  local cardColor = "GoldCardLock"
  if(cardChoice == 0) then
	cardColor = "BlueCardLock" end
  if(cardChoice == 1) then
	cardColor = "RedCardLock" end
  if(cardChoice == 2) then
	cardColor = "GoldCardLock" end
  local cardGacha = Utils.PickACard()
	if
    (QTarget and
    Q:IsReady() and 
    Utils.WithinMinRange(QTarget, Orbwalker.GetTrueAutoAttackRange(QTarget)))
  then
    if Q:CastOnHitChance(QTarget, HitChance) then return true end
  end

  return false
end

function TwistedFate.Logic.W(MustUse, cardChoice)
  if not MustUse then return false end

  --local cardChoice = Menu.Get("Combo.CardColor")
  local cardColor = "GoldCardLock"
  if(cardChoice == 0) then
	cardColor = "BlueCardLock" end
  if(cardChoice == 1) then
	cardColor = "RedCardLock" end
  if(cardChoice == 2) then
	cardColor = "GoldCardLock" end
   
  local cardGacha = Utils.PickACard()
-- Checks if W is already being cast and if so check for chosen card color.
  if (cardGacha == cardColor) then
    W:Cast()
  end
-- Checks if W is not being cast for 1st time.
  if (cardGacha == "PickACard" and W:IsReady() and Game.GetTime() - curTime > 0.25) then
    W:Cast()
	curTime = Game.GetTime() 
	if (cardGacha == cardColor) then
		W:Cast() 
		curTime = Game.GetTime() return true end
  end
end

-- Checks if enemy in TF range is CC-ed and will Auto Q is option is set
function TwistedFate.OnHeroImmobilized(source, endT)
    if not source.IsEnemy then return end

    if not blockList[source.Handle] and Q:IsReady() and Menu.Get("Auto.Q.Use") then
        if Q:CastOnHitChance(source, Enums.HitChance.VeryHigh) then
            blockList[source.Handle] = Game.GetTime()
            return
        end
    end
    if Q:IsReady() and Menu.Get("Auto.Q.Use") then
        if Q:CastOnHitChance(source, Enums.HitChance.VeryHigh) then
            return
        end
    end
end






--------------------------------------Combo Logic--------------------------------------
function TwistedFate.Logic.Combo()
  -- combo logic
  if (TwistedFate.Logic.Q(Menu.Get("Combo.Q.Use"), Menu.Get("Combo.Q.HitChance"), Menu.Get("Combo.CardColor"))) then return true end
  if (TwistedFate.Logic.W(Menu.Get("Combo.W.Use"), Menu.Get("Combo.CardColor"))) then return true end

  return false
end

--------------------------------------LastHit Logic--------------------------------------
function TwistedFate.Logic.Lasthit()
  -- Harass logic
  if (TwistedFate.Logic.W(Menu.Get("LastHit.W.Use"), Menu.Get("LastHit.CardColor"))) then return true end

  return false
end



--------------------------------------Harass Logic--------------------------------------
function TwistedFate.Logic.Harass()
  -- Harass logic
  if (TwistedFate.Logic.Q(Menu.Get("Harass.Q.Use"), Menu.Get("Harass.Q.HitChance"))) then return true end
  if (TwistedFate.Logic.W(Menu.Get("Harass.W.Use"), Menu.Get("Harass.CardColor"))) then return true end

  return false
end

--------------------------------------WaveClear Logic--------------------------------------

function TwistedFate.ClearLogic.Q(MustUse)
  if not MustUse then return false end
  local Minion = Utils.GetMinions(Q.Range)
  if Minion and Q:IsReady() and Utils.WithinMaxRange(Minion, Q.Range) and Q:Cast(Minion) then return true end
  return false
end

function TwistedFate.ClearLogic.W(MustUse, cardChoice)
  if not MustUse then return false end
  local cardColor = "GoldCardLock"
  if(cardChoice == 0) then
	cardColor = "BlueCardLock" end
  if(cardChoice == 1) then
	cardColor = "RedCardLock" end
  if(cardChoice == 2) then
	cardColor = "GoldCardLock" end

  local cardGacha = Utils.PickACard()
  local Minion = Utils.GetMinions(Q.Range)
 
  if (Minion and cardGacha == "PickACard" and W:IsReady() and Game.GetTime() - curTime > 0.25) then
    W:Cast()
	curTime = Game.GetTime() 
  end
  if (Minion and cardGacha == cardColor and W:IsReady() and Game.GetTime() - curTime > 0.25) then
    W:Cast()
	curTime = Game.GetTime() 
	return true end

end

function TwistedFate.Logic.Waveclear()
 -- WaveClear logic
 if (TwistedFate.ClearLogic.Q(Menu.Get("WaveClear.Q.Use"))) then return true end
 if (TwistedFate.ClearLogic.W(Menu.Get("WaveClear.W.Use"), Menu.Get("WaveClear.CardColor"))) then return true end

  return false
end



--------------------------------------Menu--------------------------------------

function TwistedFate.LoadMenu()
  Menu.RegisterMenu("XDTwistedFate", "XDTwistedFate", function ()
    Menu.ColumnLayout("Casting", "Casting", 2, true, function ()
      Menu.ColoredText("Combo", 0xB65A94FF, true)
      Menu.ColoredText("> Q", 0x0066CCFF, false)
      Menu.Checkbox("Combo.Q.Use", "Use", true)
      Menu.Dropdown("Combo.Q.HitChance", "HitChance", 4, HitChanceStrings)
      Menu.ColoredText("> W", 0x0066CCFF, false)
      Menu.Checkbox("Combo.W.Use", "Use", true)
      Menu.Dropdown("Combo.CardColor", "Card", 2, CardColors)
      Menu.ColoredText("LastHit", 0xB65A94FF, true)
      Menu.ColoredText("W", 0x0066CCFF, false)
      Menu.Checkbox("LastHit.W.Use", "Use", true)
      Menu.Dropdown("LastHit.CardColor", "Card", 2, CardColors)
      Menu.NextColumn()
      Menu.ColoredText("Harass", 0xB65A94FF, true)
      Menu.ColoredText("> Q", 0x0066CCFF, false)
      Menu.Checkbox("Harass.Q.Use", "Use", true)
      Menu.Dropdown("Harass.Q.HitChance", "HitChance", 4, HitChanceStrings)
      Menu.ColoredText("> W", 0x0066CCFF, false)
      Menu.Checkbox("Harass.W.Use", "Use", true)
      Menu.Dropdown("Harass.CardColor", "Card", 2, CardColors)
	  Menu.ColoredText("WaveClear", 0xB65A94FF, true)
	  Menu.ColoredText("> Q", 0x0066CCFF, false)
	  Menu.Checkbox("WaveClear.Q.Use", "Use", true)
	  Menu.ColoredText("> W", 0x0066CCFF, false)
	  Menu.Checkbox("WaveClear.W.Use", "Use", true)
      Menu.Dropdown("WaveClear.CardColor", "Card", 2, CardColors)

    end)
    Menu.Separator()
    Menu.ColumnLayout("Drawings", "Drawings", 2, true, function ()
      Menu.ColoredText("Auto", 0xB65A94FF, true)
	  Menu.Checkbox("Auto.Q.Use", "Auto Q", true)
	  Menu.Checkbox("Auto.W.Use", "Auto W Card", true)
      Menu.Dropdown("Auto.CardColor", "Card", 2, CardColors)
	  Menu.Checkbox("Auto.R.Use", "Auto R", true)
      Menu.NextColumn()
      Menu.ColoredText("Drawings", 0xB65A94FF, true)
      Menu.Checkbox("Drawings.Q", "Q", true)
      Menu.ColorPicker("Drawings.Q.Color", "Draw [Q] Color", 0xFFFFFFFF)

	  Menu.Checkbox("Drawings.R", "R", true)
      Menu.ColorPicker("Drawings.R.Color", "Draw [R] Color", 0xFFD166FF)

    end)
  end)
end

--------------------------------------Draws--------------------------------------

function TwistedFate.OnDraw()
  -- If player is not on screen than don't draw
  if not Player.IsOnScreen then return false end;

  -- Get spells ranges
  local Spells = { Q = Q, R = R}
  local playerPos = Player.Position

  if Menu.Get("Drawings.R") then
       Renderer.DrawCircleMM(playerPos, R.Range, 2, Menu.Get("Drawings.R.Color")) 
  end
  -- Draw them all
  for k, v in pairs(Spells) do
    if Menu.Get("Drawings." .. k) then
        Renderer.DrawCircle3D(playerPos, v.Range, 30, 1, Menu.Get("Drawings."..k..".Color")) 
    end
  end

  return true
end

--------------------------------------Are you in game?--------------------------------------

function TwistedFate.OnTick()
  -- Check if game is available to do anything
  if not Utils.GameAvailable() then return false end

  -- Get current orbwalker mode
  local OrbwalkerMode = Orbwalker.GetMode()

  -- Get the right logic func
  local OrbwalkerLogic = TwistedFate.Logic[OrbwalkerMode]

  local gameTime = Game.GetTime()

  for k, v in pairs(blockList) do
      if gameTime > v + 2 then
          blockList[k] = nil
      end
  end


  -- Call it
  if OrbwalkerLogic then
    return OrbwalkerLogic()
  end

  if TwistedFate.Auto() then return end


  return true
end

--------------------------------------Auto Function--------------------------------------

function TwistedFate.Auto()
  local useAutoR = Menu.Get("Auto.R.Use")
  local useAutoW = Menu.Get("Auto.W.Use")

  if (useAutoR) then

      local RPhase = Utils.GetRPhase()
	  local cardGacha = Utils.PickACard()

	  if(RPhase == "Gate") then
		if(cardGacha == "PickACard") then
		W:Cast()  
		curTime = Game.GetTime()
		end
	  useAutoW = false 
	  if (useAutoW == false) then
		 local cardColor = "GoldCardLock"
			   
			if (cardGacha == cardColor and Game.GetTime() - curTime > 1) then
				W:Cast()
				curTime = Game.GetTime()
			  end
		  end 

	  end
  end 


  if (useAutoW) then
	  local cardChoice = Menu.Get("Auto.CardColor")
	  local cardColor = "GoldCardLock"
	  if(cardChoice == 0) then
		cardColor = "BlueCardLock" end
	  if(cardChoice == 1) then
		cardColor = "RedCardLock" end
	  if(cardChoice == 2) then
		cardColor = "GoldCardLock" end
	   
	  local cardGacha = Utils.PickACard()
	
	  if (cardGacha == cardColor and Game.GetTime() - curTime > 1) then
		W:Cast()
		curTime = Game.GetTime()
	  end
  end 



end


--------------------------------------Load Script--------------------------------------

function OnLoad()
  -- Load our menu
  TwistedFate.LoadMenu()

  -- Load our target selector
  TwistedFate.TargetSelector = TargetSelector()

  -- Register callback for func available in champion object
  for EventName, EventId in pairs(Events) do
    if TwistedFate[EventName] then
        EventManager.RegisterCallback(EventId, TwistedFate[EventName])
    end
  end

	return true
end
