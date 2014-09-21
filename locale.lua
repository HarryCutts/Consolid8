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

--[[Blizzard Localization used (not included in locale table):
	RESET
	FACTION
	MONEY
	
	Blizzard Localization processed (in-file):
	FACTION_STANDING_DECREASED
	FACTION_STANDING_INCREASED
	GOLD_AMOUNT
	SILVER_AMOUNT
	COPPER_AMOUNT
]]

local function CreateFactionPattern(str)
	-- Returns: a pattern string used to process reputation gain messages.
	-- 	   str: the format string from which to create the pattern string.
	local returnStr = str:replace("%s", "(.*)",  0, true)
	returnStr = returnStr:replace("%d", "(%d*)", 0, true)
	return returnStr
end

local function CreateIntegerPattern(str)
	-- Returns: a pattern string used to process honor and money messages.
	--     str: the format string from which to create the pattern string.
	return str:replace("%d", "(%d*)", 0, true)
end

-- Locale

local name, L = ...

--[[ Localised strings ]]--
L["CHANGE"]			= "Change"
L["REPORT"]			= "Report"
	
--[[ Processed Blizzard Localisation ]]--
-- Pattern strings
L["REP_DEC"]  		= CreateFactionPattern	(FACTION_STANDING_DECREASED)
L["REP_INC"]		= CreateFactionPattern	(FACTION_STANDING_INCREASED)

L["MONEY_GOLD"]		= CreateIntegerPattern	(GOLD_AMOUNT)
L["MONEY_SILVER"]	= CreateIntegerPattern	(SILVER_AMOUNT)
L["MONEY_COPPER"]	= CreateIntegerPattern	(COPPER_AMOUNT)

L["HONOR_1"]		= CreateIntegerPattern	(COMBATLOG_HONORGAIN)
L["HONOR_2"]		= CreateIntegerPattern	(COMBATLOG_HONORAWARD)
L["HONOR_3"]		= CreateIntegerPattern	(COMBATLOG_HONORGAIN_NO_RANK)


local loc = GetLocale()

if loc == "frFR" then
	L["CHANGE"] = "Changement"
	L["REPORT"] = "Rapport"
	
elseif loc == "deDE" then
	L["CHANGE"] = "Änderung"
	L["REPORT"] = "Report"
	
elseif (loc == "esES") or (loc == "esMX") then
	L["CHANGE"] = "Cambio"
	L["REPORT"] = "Informe"
	
elseif loc == "ruRU" then
	L["CHANGE"] = "Изменение"
	L["REPORT"] = "Рапорт"
	
elseif loc == "zhCN" then
	L["CHANGE"] = "变动"
	L["REPORT"] = "报告"
	
elseif loc == "zhTW" then
	L["CHANGE"] = "變動"
	L["REPORT"] = "報告"
	
end