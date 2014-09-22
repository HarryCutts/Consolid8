--[[Consolid8, a World of Warcraft chat frame addon
	Copyright 2010 Harry Cutts

	This work by Harry Cutts is licensed under a
	Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
	To read this license, please see http://creativecommons.org/licenses/by-nc-sa/3.0/.
]]--
--[[Consolid8_Settings members
	auto	: True if autoreporting is enabled; else false.
	loot	: True if loot consolidation is enabled; else false.
	scale	: Stores the scale of the button.
	visible	: True if the button should be visible; else false.
]]

local addOnName, L = ...	-- Local locale table

-- [[ Data ]]--
local originalHonor
local originalXP
local data = {}
local specialData = {
	-- money	: money looted
	-- greyValue: value of looted poor quality items
}
Consolid8 = { data = data, specialData = specialData, }

--[[ Utility Functions ]]--

local function print(msg)
	return DEFAULT_CHAT_FRAME:AddMessage("|cFF0080FF" .. addOnName .. ":|r " .. tostring(msg))
end

local function CoppersToString(copper)
	-- Returns: a formatted money string
	local gold	 = math.floor(copper / 10000)
	copper		 = copper % 10000
	local silver = math.floor(copper / 100)
	copper		 = copper % 100
	return format(L["MONEY_FORMAT"], gold, silver, copper)
end

local function StringToCoppers(str)
	-- Returns: the amount of money in str, in coppers.
	local gold	 = str:match(L["MONEY_GOLD"])	or 0
	local silver = str:match(L["MONEY_SILVER"])	or 0
	local copper = str:match(L["MONEY_COPPER"])	or 0
	return (gold * 10000) + (silver * 100) + copper
end

local function ChangeData(faction, change)
	data[faction] = (data[faction] or 0) + change
end

local function ChangeSpecialData(key, change)
	specialData[key] = (specialData[key] or 0) + change
end

-- Thanks to Slakah of WoWInterface.com for these two functions
local function ConcatKeys(tbl, key, ...)
	local newKey, newValue = next(tbl, key)

	if not newValue then return strjoin("\n", ...) end

	return ConcatKeys(tbl, newKey, newKey, ...)
end

local function ConcatValues(tbl, key, ...)
	local newKey, newValue = next(tbl, key)

	if not newValue then return strjoin("\n", ...) end

	return ConcatValues(tbl, newKey, newValue, ...)
end

--[[ Loot handling ]]--

local looting = false	-- True if the loot frame is open; else false.
local lootString
local printing = false	-- True if Consolid8 is sending a loot message; else false.

local chatFrames

local function UpdateChatFramesArray()
	local i
	local function receives(...)
		for i = 1, select('#', ...) do
			if select(i, ...) == "LOOT" then
				return true
			end
		end
		return false
	end
	chatFrames = {}
	for i = 1, NUM_CHAT_WINDOWS do
		if receives(GetChatWindowMessages(i)) then
			tinsert(chatFrames, getglobal("ChatFrame"..i))
		end
	end
end

local function LootPrint(msg)
	-- Sends CHAT_MSG_LOOT events to all chat frames which are registered for LOOT messages.
	printing = true
	local i

	arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9 = msg, "", "", "", "", "", "", "", ""
	for key, chatFrame in ipairs(chatFrames) do
		ChatFrame_OnEvent(chatFrame, "CHAT_MSG_LOOT", msg, "", "", "", "", "", "", "", "")
	end
	printing = false
end

local function LogLoot(msg)
	local link, quantity = msg:match("(.*)x(%d*)$")
	if not link then
		link = msg
	end
	
	local _, _, rarity, _, _, _, _, _, _, _, sellPrice = GetItemInfo(link)
	if rarity > ITEM_QUALITY_POOR then -- the item is not poor quality
		lootString = ( lootString and (lootString .. ", " .. msg) ) or msg
	else
		ChangeSpecialData("greyValue", sellPrice * (quantity or 1))
	end
end

local function StopLogging()
	looting = false
	if lootString then
		LootPrint(format(LOOT_ITEM_SELF, lootString))
		lootString = nil
	end
end

local function LootFilter(chatFrame, event, arg1)	-- Discard args 2-11
	if not printing and (arg1:match(L["LOOT"]) or arg1:match(L["LOOT_OTHER"])) then
		return true
	end
end

-- Settings functions
local ToggleLoot; do

function ToggleLoot()
	Consolid8.SetLootSetting(not Consolid8_Settings.loot)
end

function Consolid8.SetLootSetting(loot)
	Consolid8_Settings.loot = loot
	if loot then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", LootFilter)
	else
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_LOOT", LootFilter)
	end
end

end

do--[[ Public functions ]]--

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
end

--[[ Event Handling ]]--

local frame
local inInstance = false	-- Instance tracking. Initialized on frame load.
local original_ChatConfigFrameOkayButton_OnClick

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

		if autolooting == 1 then
			looting = GetNumLootItems()
		else
			looting = true
		end
	end,

	CHAT_MSG_LOOT = function(msg)							-- log message
		if not Consolid8_Settings.loot then return end

		local str = msg:match(L["LOOT"])
		if str then
			LogLoot(str)

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

	UI_ERROR_MESSAGE = function(msg)						-- check for full inventory etc.
		if type(looting) == "number" and (msg == ERR_INV_FULL or msg == ERR_LOOT_CANT_LOOT_THAT
				or msg == ERR_LOOT_CANT_LOOT_THAT_NOW or msg == ERR_LOOT_ROLL_PENDING) then
			looting = looting - 1
			if looting == 0 then
				StopLogging()
			end
		end
	end,

	--[[ ]]--
	ADDON_LOADED = function(name)					-- Load saved variables (self-destructs)
		if name ~= addOnName then return end

		if not Consolid8_Settings then
			Consolid8_Settings = { loot = true, visible = true, auto = true }
		end
		if not Consolid8_Settings.visible then
			frame:Hide()
		end
		Consolid8.SetLootSetting	(Consolid8_Settings.loot)

		-- Self-destruct
		frame:UnregisterEvent("ADDON_LOADED")
		eventHandlers.ADDON_LOADED = nil
	end,

	UPDATE_CHAT_WINDOWS = UpdateChatFramesArray,	-- Update chatFrames array

	PLAYER_ENTERING_WORLD = function()				-- Check for leaving an instance
		if IsInInstance() then
			inInstance = true
		else
			if Consolid8_Settings.auto and inInstance and not UnitIsDeadOrGhost("player") then
				Consolid8.Report()
			end
			inInstance = false
		end
	end,

	PLAYER_LOGIN = function()						-- Scale frame, initialize variables
		-- Set the scale to be the same as the other chat buttons
		frame:SetScale(Consolid8_Settings.scale or ChatFrameMenuButton:GetScale())

		-- Record the starting honor and XP
		originalHonor 	= GetHonorCurrency()
		originalXP		= UnitXP("player")
	end,
}

function Consolid8.OnEvent(event, ...)
	local handler = eventHandlers[event]
	if handler then	return handler(...) end
end

function Consolid8.OnLoad()
	-- Initialize local and public variables
	frame = Consolid8_Frame
	Consolid8.frame = frame
	inInstance = IsInInstance()

	-- Hook ChatConfigFrameOkayButton's OnClick script
	original_ChatConfigFrameOkayButton_OnClick = ChatConfigFrameOkayButton:GetScript("OnClick")
	ChatConfigFrameOkayButton:SetScript("OnClick", function(...)
		original_ChatConfigFrameOkayButton_OnClick(...)
		UpdateChatFramesArray()
	end)

	-- Register events
	for event in pairs(eventHandlers) do
		frame:RegisterEvent(event)
	end
end

do --[[ UI ]]--

-- Grey color
local r, g, b = GetItemQualityColor(0)
local greyText = format("|cff%02x%02x%02x", r * 255, g * 255, b * 255 ) .. "%s|r"
r, g, b = nil, nil, nil

-- Report dialog
StaticPopupDialogs.Consolid8 = {
	text		= "|cFF0080FF" .. addOnName .. ":|r " .. L["REPORT"] .. ":\n",
	button1		= RESET,	-- Accept button
	button2		= OKAY,		-- Cancel button

	OnShow = function(self)
		local namesStr, valuesStr = ConcatKeys(data, nil), ConcatValues(data, nil)

		-- Money, Honor, and XP
		if specialData.money then
			namesStr  = namesStr .. "\n" .. MONEY
			valuesStr = valuesStr .. "\n" .. CoppersToString(specialData.money)
		end
		if specialData.greyValue then
			namesStr  = namesStr .. "\n"
			valuesStr = valuesStr .. "\n" .. format(greyText, CoppersToString(specialData.greyValue))
		end

		local honorGain = GetHonorCurrency() - originalHonor
		if honorGain ~= 0 then
			namesStr  = namesStr  .. "\n" .. HONOR
			valuesStr = valuesStr .. "\n" .. honorGain
		end

		local xpGain	= UnitXP("player") - originalXP
		if xpGain ~= 0 then
			namesStr  = namesStr  .. "\n" .. COMBAT_XP_GAIN
			valuesStr = valuesStr .. "\n" .. xpGain
		end

		-- Custom popup frames
		local namesFS, valuesFS, autoCB
		if not self.namesFS then
			namesFS		= self:CreateFontString(nil, "ARTWORK", "Consolid8NameStyle")
			namesFS:SetPoint("LEFT", self, "LEFT", 15, 0)
			self.namesFS = namesFS

			valuesFS	= self:CreateFontString(nil, "ARTWORK", "Consolid8ValueStyle")
			valuesFS:SetPoint("RIGHT", self, "RIGHT", -15, 0)
			self.valuesFS = valuesFS

			autoCB 		= CreateFrame("CheckButton", nil, self, "Consolid8_CBTemplate")
			autoCB:SetText(L["AUTO"])
			autoCB:SetPoint("BOTTOMLEFT", self.button1, "TOPLEFT", 0, 0)
			self.autoCB = autoCB
		else
			namesFS		= self.namesFS
			valuesFS	= self.valuesFS
			autoCB		= self.autoCB
		end
		
		namesFS:SetText(namesStr)
		namesFS:SetWidth(namesFS:GetStringWidth())

		valuesFS:SetText(valuesStr)
		valuesFS:SetWidth(valuesFS:GetStringWidth())

		-- Automatic report checkbox
		autoCB:SetChecked(Consolid8_Settings.auto)
		autoCB:Show()

		self.height = self:GetHeight() + namesFS:GetStringHeight()
	end,

	OnUpdate = function(self)
		return self:SetHeight(self.height)
	end,

	OnAccept = Consolid8.Reset,

	OnHide = function(self)
		self.namesFS:Hide()
		self.valuesFS:Hide()
		self.autoCB:Hide()
		Consolid8.SetReportSetting(self.autoCB:GetChecked() and true or false)	-- Store a boolean, not 1/nil
	end,

	whileDead = 1, hideOnEscape = 1, notClosableByLogout = 1, timeout = 0,
}

-- Report settings
local function ToggleReport()
	return Consolid8.SetReportSetting(not Consolid8_Settings.auto)
end

function Consolid8.SetReportSetting(auto)
	Consolid8_Settings.auto = auto
end

function Consolid8.Report()
	return StaticPopup_Show("Consolid8")
end

-- Slash handler
SLASH_CONSOLID1 = "/consolid8"
SlashCmdList["CONSOLID"] = function(msg)
	msg = string.lower(msg)
	if msg == string.lower(L["REPORT"]) then
		return Consolid8.Report()
	elseif msg == string.lower(RESET) then
		return Consolid8.Reset()
	elseif msg == string.lower(L["SHOW"]) then
		return Consolid8.Show()
	elseif msg == string.lower(L["HIDE"]) then
		return Consolid8.Hide()
	else
		return print(SLASH_CONSOLID1 .. format(" %s, %s, %s, %s", L["REPORT"], RESET, L["SHOW"], L["HIDE"]))
	end
end

-- Show/hide button
function Consolid8.Show()
	frame:Show()
	Consolid8_Settings.visible = true
end

function Consolid8.Hide()
	frame:Hide()
	Consolid8_Settings.visible = false
end

-- Tooltip
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
	tooltip:AddLine(addOnName, 0, 0.5, 1)	-- Title line. Color the same as used in print method.
	tooltip:AddLine(" ")

	-- Faction changes
	tooltip:AddDoubleLine(FACTION, L["CHANGE"])	-- Column headers

	for key, value in pairs(data) do
		tooltip:AddDoubleLine(key, value, 0.5, 0.5, 1,	0.5, 0.5, 1)
	end

	tooltip:AddLine(" ")
	-- Money
	if specialData.money then
		tooltip:AddDoubleLine(MONEY, CoppersToString(specialData.money))
	end
	if specialData.greyValue then
		tooltip:AddDoubleLine(" ", format(greyText, CoppersToString(specialData.greyValue)))
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
	return tooltip:Hide()
end

-- Menu
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
		func	= ToggleLoot,
	},
}

function Consolid8.MenuFunction()
	for key, value in pairs(menuList) do
		if value.update then value:update()	end
		UIDropDownMenu_AddButton(value)
	end
end

function Consolid8.ShowMenu()
	return ToggleDropDownMenu(1, nil, Consolid8_Menu, "cursor", 0, 0)
end

-- Broker Plugin
local dataObj = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(addOnName,
	{
		type	= "data source",
		icon	= [[Interface\AddOns\Consolid8\Broker]],
		label	= addOnName,

		-- Scripts
		OnClick	= Consolid8.ShowMenu,
		OnEnter	= Consolid8.ShowTooltip,
		OnLeave	= Consolid8.HideTooltip,
	})
end