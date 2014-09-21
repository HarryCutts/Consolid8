--[[
	Consolid8, a World of Warcraft chat frame addon
	Copyright 2010 Harry Cutts

	This file is part of Consolid8.

	Consolid8 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Consolid8 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Consolid8.  If not, see <http://www.gnu.org/licenses/>.
]]--
--[[Consolid8_Settings MEMBERS
	loot  : True if loot consolidation is enabled; else false.
	scale : Stores the scale of the button.
]]

local addOnName, L = ...	-- Local locale table

-- [[ Data ]]--
local originalHonor
local originalXP
local data = {}
local specialData = {
	-- Money : money looted
}
Consolid8 = { data = data, specialData = specialData, }

--[[ Utility Functions ]]--

local function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cFF0080FF" .. addOnName .. ":|r " .. tostring(msg))
end

local lootMsgInfo = ChatTypeInfo["LOOT"]
local function LootPrint(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg, lootMsgInfo.r, lootMsgInfo.g, lootMsgInfo.b)
end

local function CoppersToString(copper)
	-- Returns: a formatted money string, e.g. "1g 56s 20c" when copper = 15620
	local gold 		= math.floor(copper / 10000)
	copper 			= copper % 10000
	local silver 	= math.floor(copper / 100)
	copper 			= copper % 100
	return format("%dg %ds %dc", gold, silver, copper)
end

local function StringToCoppers(str)
	-- Returns: the amount of money in str, in coppers.
	local gold   = str:match(L["MONEY_GOLD"]) 	or 0
	local silver = str:match(L["MONEY_SILVER"]) or 0
	local copper = str:match(L["MONEY_COPPER"]) or 0
	return (gold * 10000) + (silver * 100) + copper
end

--[[ Public Functions ]]--

StaticPopupDialogs.Consolid8_Report = {
	text         	= "|cFF0080FF" .. addOnName .. ":|r " .. L["REPORT"] .. ":\n",
	button1      	= RESET,	-- Accept button
	button2			= OKAY,		-- Cancel button
	
	OnShow			= function(self)
		local namesStr  = ""
		local valuesStr = ""
		
		for key, value in pairs(data) do
			namesStr  = namesStr  .. key .. "\n"
			valuesStr = valuesStr .. value .. "\n"
		end
		
		-- Money, Honor, and XP
		if specialData.money then
			namesStr  = namesStr  .. "\n|TInterface\\Icons\\INV_Misc_Coin_01:16|t " .. MONEY
			valuesStr = valuesStr .. "\n" .. CoppersToString(specialData.money)
		end
		
		local honorGain = GetHonorCurrency() - originalHonor
		if honorGain ~= 0 then
			namesStr  = namesStr  .. "\n" .. HONOR
			valuesStr = valuesStr .. "\n" .. honorGain
		end
		
		local namesFS = self:CreateFontString(nil, "ARTWORK", "Consolid8NameStyle")
		self.namesFS = namesFS;
		namesFS:SetPoint("LEFT", self, "LEFT", 15, 0)
		namesFS:SetText(namesStr)
		
		local valuesFS = self:CreateFontString(nil, "ARTWORK", "Consolid8ValueStyle")
		self.valuesFS = valuesFS;
		valuesFS:SetPoint("RIGHT", self, "RIGHT", -15, 0)
		valuesFS:SetText(valuesStr)
		
		self.height = self:GetHeight() + namesFS:GetStringHeight()
	end,
	
	OnUpdate		= function(self)
		self:SetHeight(self.height)
	end,
	
	OnAccept		= function()
		Consolid8.Reset()
	end,
	
	OnHide			= function(self)
		self.namesFS:Hide()
		self.valuesFS:Hide()
	end,
	
	whileDead = 1, hideOnEscape = 1, notClosableByLogout = 1, timeout = 0,
};

function Consolid8.Report()
	-- Displays the report dialog.
	local popup = StaticPopup_Show("Consolid8_Report")
end

function Consolid8.Reset()
	-- Clears all stored data.
	for key, value in pairs(data) do
		data[key] = nil
	end
	for key, value in pairs(specialData) do
		specialData[key] = nil
	end
	originalHonor	= GetHonorCurrency()
	originalXP		= UnitXP("player")
	print(RESET)
end

--[[ Event Handling ]]--

local frame

-- Loot message consolidation
local looting 	  = false					-- True if the loot frame is open; else false.
local lootString

local inInstance = false					-- Instance tracking. Initialized on frame load.

local function ChangeData(faction, change)
	-- Changes the data in the data table to reflect the change of reputation.
	data[faction] = (data[faction] or 0) + change
end

local function ChangeSpecialData(key, change)
	-- Changes the data in the data table to reflect the change of reputation.
	specialData[key] = (specialData[key] or 0) + change
end

local function LogLoot(msg)
	local str = msg:match(L["LOOT"])
	if str then
		lootString = ( lootString and (lootString .. ", " .. str) ) or str
	else
		LootPrint(msg)
	end
end

local function StopLogging()
	looting = false
	if lootString then
		LootPrint(format(LOOT_ITEM_SELF, lootString))
		lootString = nil
	end
end

local eventHandlers
eventHandlers = {
	CHAT_MSG_COMBAT_FACTION_CHANGE = function(msg)	-- Reputation
		-- Attempt to match the increased pattern string
		local faction, change = msg:match(L["REP_INC"])
		
		if change then
			ChangeData(faction, change)
		else
			-- Attempt to match the decreased pattern string
			faction, change = msg:match(L["REP_DEC"])
			
			if change --[[a match has been found]] then ChangeData(faction, -change) end
		end
	end,
	
	CHAT_MSG_MONEY = function(msg)					-- Money
		ChangeSpecialData("money", StringToCoppers(msg))
		
		if Consolid8_Settings.loot and type(looting) == "number" then -- Money loot is counted as an item for GetNumLootItems()
			looting = looting - 1
			if looting == 0 then
				StopLogging()
			end
		end
	end,
	
	--[[ Looting ]]--
	LOOT_OPENED = function(autolooting)				-- Loot: start logging
		-- autolooting: 1 if autolooting, else 0 (NOT NIL!)
		if not Consolid8_Settings.loot then return end
		if looting then
			StopLogging()
			return
		end
		if arg1 == 1 then
			looting = GetNumLootItems()
		else 
			looting = true
		end
	end,
	
	CHAT_MSG_LOOT = function(msg)						  -- log message
		if not Consolid8_Settings.loot then return end
		
		if not looting then	-- Pass the message on as normal
			LootPrint(msg)
		else
			LogLoot(msg)
			
			if type(looting) == "number" then	-- See whether this was the last item
				looting = looting - 1
				if looting == 0 then
					StopLogging()
				end
				
			elseif not LootFrame:IsShown() then	-- See if the loot frame has been closed
				StopLogging()
			end
		end
	end,

	UI_ERROR_MESSAGE = function(msg)					-- check for full inventory etc.
		if type(looting) == "number" and (msg == ERR_INV_FULL or msg == ERR_LOOT_CANT_LOOT_THAT
				or msg == ERR_LOOT_CANT_LOOT_THAT_NOW or msg == ERR_LOOT_ROLL_PENDING) then
			looting = looting - 1
			if looting == 0 then
				StopLogging()
			end
		end
	end,
	
	--[[  ]]--
	PLAYER_ENTERING_WORLD = function()				-- Check for leaving an instance
		if IsInInstance() then
			inInstance = true
		else
			if inInstance and not UnitIsDeadOrGhost("player") then
				Consolid8.Report()
				inInstance = false
			end
		end
	end,
	
	ADDON_LOADED = function(name)					-- Load saved variables (self-destructs)
		if name ~= addOnName then return end
		
		if not Consolid8_Settings then
			Consolid8_Settings = { loot = true, visible = true }
		end
		if not Consolid8_Settings.visible then
			frame:Hide()
		end
		
		-- Self-destruct
		frame:UnregisterEvent("ADDON_LOADED")
		eventHandlers.ADDON_LOADED = nil
	end,
	
	PLAYER_LOGIN = function()						-- Initialization stuff
		-- Set the scale to be the same as the other chat buttons
		frame:SetScale(Consolid8_Settings.scale or ChatFrameMenuButton:GetScale())
		
		-- Record the starting honor and XP
		originalHonor 	= GetHonorCurrency()
		originalXP		= UnitXP("player")
	end,
}

function Consolid8.OnLoad()
	-- Initialize local and public variables
	frame = Consolid8_Frame
	Consolid8.frame = frame
	inInstance = IsInInstance()
	
	-- Register events
	for event in pairs(eventHandlers) do
		frame:RegisterEvent(event)
	end
end

function Consolid8.OnEvent(event, ...)
	local handler = eventHandlers[event]
	if handler then	handler(...) end
end

--[[ Slash handler ]]--

SLASH_CONSOLID1 = "/consolid8"
SlashCmdList["CONSOLID"] = function(msg)
	msg = string.lower(msg)
	if msg == string.lower(L["REPORT"]) then
		Consolid8.Report()
	elseif msg == string.lower(RESET) then
		Consolid8.Reset()
	elseif msg == string.lower(L["SHOW"]) then
		Consolid8.Show()
	elseif msg == string.lower(L["HIDE"]) then
		Consolid8.Hide()
	else
		print(SLASH_CONSOLID1 .. format(" %s, %s, %s, %s", L["REPORT"], RESET, L["SHOW"], L["HIDE"]))
	end
end

--[[ Show/hide button ]]--

function Consolid8.Show()
	frame:Show()
	Consolid8_Settings.visible = true
end

function Consolid8.Hide()
	frame:Hide()
	Consolid8_Settings.visible = false
end

--[[ Tooltip ]]--

local tooltip;

function Consolid8.ShowTooltip()
	-- Create the tooltip if need be
	if not tooltip then
		tooltip = CreateFrame("GameTooltip", "Consolid8_Tooltip", UIParent, "GameTooltipTemplate")
		GameTooltip_SetDefaultAnchor(tooltip, UIParent)
	end
	
	tooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
	tooltip:ClearLines()
	
	-- Header
	tooltip:AddLine(addOnName, 0, 0.5, 1)	-- Will be title line. Color the same as used in print method.
	tooltip:AddLine(" ")
	
	-- Faction changes
	tooltip:AddDoubleLine(FACTION, L["CHANGE"])	-- Column headers
	
	for key, value in pairs(data) do
		tooltip:AddDoubleLine(key, value, 0.5, 0.5, 1,	0.5, 0.5, 1)
	end
	
	tooltip:AddLine(" ")
	-- Money
	if specialData.money then
		tooltip:AddDoubleLine("|TInterface\\Icons\\INV_Misc_Coin_01:16|t " .. MONEY,
			CoppersToString(specialData.money))
	end
	
	-- Honor & XP
	local honorGain = GetHonorCurrency() - originalHonor
	if honorGain ~= 0 then
		tooltip:AddDoubleLine(HONOR, honorGain)
	end
	local xpGain	= UnitXP("player") - originalXP
	if xpGain ~= 0 then
		tooltip:AddDoubleLine(COMBAT_XP_GAIN, xpGain)
	end
	
    tooltip:Show()
end

function Consolid8.HideTooltip()
	tooltip:Hide()
end

--[[ Menu ]]--

local menuList =
{
	{	--[[ Consolid8 ]]--
		text	= addOnName,
		isTitle = true,
	},
	{	-- Reset
		text 	= RESET,
		func 	= Consolid8.Reset,
	},
	{	-- Report
		text	= L["REPORT"],
		func	= Consolid8.Report,
	},
	{	--[ ] Loot
		text	= LOOT,
		update	= function(tbl)
			if Consolid8_Settings then tbl.checked = Consolid8_Settings.loot end
		end,
		func	= function()
			Consolid8_Settings.loot = not Consolid8_Settings.loot
		end,
	},
}

function Consolid8.MenuFunction()
	for key, value in pairs(menuList) do
		if value.update then value:update()	end
		UIDropDownMenu_AddButton(value)
	end
end

function Consolid8.ShowMenu()
	ToggleDropDownMenu(1, nil, Consolid8_Menu, "cursor", 0, 0)
end

--[[ Broker plugin ]]--

local dataObj = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("Consolid8",
	{
		type 	= "data source",
		icon 	= [[Interface\AddOns\Consolid8\Broker]],
		label 	= addOnName,
		
		-- Scripts
		OnClick = Consolid8.ShowMenu,
		OnEnter	= Consolid8.ShowTooltip,
		OnLeave = Consolid8.HideTooltip,
	})