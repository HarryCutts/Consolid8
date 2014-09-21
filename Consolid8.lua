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

local addOnName, L = ...	-- Local locale table

local data = {}
local specialData = {
	-- Money : money looted
}
Consolid8 = {
	data = data,
	specialData = specialData,
}

--[[ Local Functions ]]--

local function print(message)
	-- Writes a message to the chat frame, prefixed by "Consolid8: " in color.
	-- message: The string to print in the chat frame
	DEFAULT_CHAT_FRAME:AddMessage("|cFF0080FF" .. addOnName .. ":|r " .. message)
end

local function CoppersToString(copper)
	-- Formats a money string from a given number of coppers
	--  copper: the number of coppers
	-- Returns: a formatted money string, e.g. "1g 56s 20c" when copper = 15620
	local gold 		= math.floor(copper / 10000)
	copper 			= copper % 10000
	local silver 	= math.floor(copper / 100)
	copper 			= copper % 100
	return format("%dg %ds %dc", gold, silver, copper)
end

local function StringToCoppers(str)
	-- Returns: the amount of money in str, in coppers.
	--     str: the string to match.
	local gold   = str:match(L["MONEY_GOLD"]) 	or 0
	local silver = str:match(L["MONEY_SILVER"]) or 0
	local copper = str:match(L["MONEY_COPPER"]) or 0
	return (gold * 10000) + (silver * 100) + copper
end

local function ChangeData(faction, change)
	-- Changes the data in the data table to reflect the change of reputation.
	-- faction: The faction with whom reputation has changed.
	--  change: The amount by which reputation has changed. Negative values decrement the reputation.
	data[faction] = (data[faction] or 0) + change
end

local function ChangeSpecialData(key, change)
	-- Changes the data in the data table to reflect the change of reputation.
	--     key: The data to change.
	--  change: The amount by which the data has changed. Negative values decrement the data.
	specialData[key] = (specialData[key] or 0) + change
end

--[[ Public Functions ]]--

function Consolid8.Report()
	-- Dumps the contents of the data table to the default chat frame.
	print(L["REPORT"] .. ":")
	for key, value in pairs(data) do
		print(format("%s = %d", key, value))
	end
	for key, value in pairs(specialData) do
		print(format("%s = %d", key, value))
	end
end

function Consolid8.Reset()
	-- Clears all stored data.
	for key, value in pairs(data) do
		data[key] = nil
	end
	for key, value in pairs(specialData) do
		specialData[key] = nil
	end
	print(RESET)
end

--[[ AddOn Methods ]]--

local frame
local originalHonor

function Consolid8.OnLoad()
	-- Initialize local and public variables
	frame = Consolid8_Frame;
	Consolid8.frame = frame;
	
	-- Register events
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
	frame:RegisterEvent("CHAT_MSG_MONEY")
end

function Consolid8.OnEvent(self, event, arg1, ...)
	if event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
		-- arg1: the message to be printed to the chat frame.
		-- Attempt to match the increased pattern string
		local faction, change = arg1:match(L["REP_INC"])
		
		if change --[[a match has been found]] then
			ChangeData(faction, change)
			
		else
			-- Attempt to match the decreased pattern string
			faction, change = arg1:match(L["REP_DEC"])
			
			if change --[[a match has been found]] then
				ChangeData(faction, -change)
			end
		end
		
	elseif event == "CHAT_MSG_MONEY" then
		ChangeSpecialData("Money", StringToCoppers(arg1))
	
	elseif event == "PLAYER_LOGIN" then
		-- arg1: the name of the addOn which has been loaded.
		-- Set the scale to be the same as the other chat buttons
		frame:SetScale(Consolid8_Scale or ChatFrameMenuButton:GetScale())
		
		-- Record the starting honor
		originalHonor = GetHonorCurrency()
	end -- if event
end

--[[ Slash handler ]]--

SLASH_CONSOLID1 = "/consolid8"
SlashCmdList["CONSOLID"] = function(msg)
	msg = string.lower(msg)
	if msg == string.lower(L["REPORT"]) then
		Consolid8.Report()
	elseif msg == string.lower(RESET) then
		Consolid8.Reset()
	end
end

--[[ Broker plugin ]]--

local watch 	= nil
local dataObj 	= LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("Consolid8",
	{
		type 	= "data source",
		icon 	= "Interface\\AddOns\\Consolid8\\Broker",
		label 	= addOnName,
	})
	
function dataObj.OnClick(self --[[, button]])
	Consolid8.ShowMenu(self)
end

function dataObj.OnEnter(self)
	Consolid8.ShowTooltip()
end

function dataObj.OnLeave(self)
	Consolid8.HideTooltip()
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
		tooltip:AddDoubleLine(key, value, --[[Left]]0.5, 0.5, 1,	--[[Right]]0.5, 0.5, 1)
	end
	
	tooltip:AddLine(" ")
	-- Money
	if specialData.Money then
		tooltip:AddDoubleLine(MONEY, CoppersToString(specialData.Money))
	end
	
	-- Honor
	local honorGain = GetHonorCurrency() - originalHonor
	if honorGain ~= 0 then
		tooltip:AddDoubleLine(HONOR, honorGain)
	end
	
    tooltip:Show()
end

function Consolid8.HideTooltip()
	tooltip:Hide()
end

--[[ Menu ]]--

local menuFrame
local menuList =
{
	{	--[[ Consolid8 ]]--
		text	= addOnName,
		isTitle = true
	},
	{	-- Reset
		text 	= RESET,
		func 	= Consolid8.Reset
	},
	{	-- Report
		text	= L["REPORT"],
		func	= Consolid8.Report
	},
}

function Consolid8.ShowMenu(anchorTo)
	-- Shows the menu documented in menuList.
	-- anchorTo: If set, the menu will be anchored to this frame; else, it will be anchored to Consolid8_Frame.
	-- Create the menu frame if need be
	if not menuFrame then
		menuFrame = CreateFrame("Frame", "Consolid8_Menu", Consolid8_Frame, "UIDropDownMenuTemplate")
	end
	
	-- Set the anchor
	menuFrame:SetPoint("TOPRIGHT", (anchorTo or Consolid8_Frame), "TOPLEFT")
	
	EasyMenu(menuList, menuFrame, "Consolid8_Menu", 0, 0, "MENU")
end