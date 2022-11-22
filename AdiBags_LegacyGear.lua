--[[
AdiBags_Lowlevel - Adds Lowlevel filters to AdiBags.
Copyright 2016 seirl
All rights reserved.
--]]

local _, ns = ...

local addon = LibStub('AceAddon-3.0'):GetAddon('AdiBags')
local L = setmetatable({}, {__index = addon.L})
local _G = _G
local GameTooltip = _G.GameTooltip
local GetItemInfo = _G.GetItemInfo

local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetContainerItemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
local UseContainerItem = C_Container and C_Container.UseContainerItem or UseContainerItem
local SetInventoryItem = C_Container and C_Container.SetInventoryItem or SetInventoryItem

local LEGENDARY = 5
local EPIC = 4
local RARE = 3
local UNCOMMON = 2

local function create()
  local tip, leftside = CreateFrame("GameTooltip"), {}
  for i = 1,6 do
    local L,R = tip:CreateFontString(), tip:CreateFontString()
    L:SetFontObject(GameFontNormal)
    R:SetFontObject(GameFontNormal)
    tip:AddFontStrings(L,R)
    leftside[i] = L
  end
  tip.leftside = leftside
  return tip
end

-- The filter itself

local setFilter = addon:RegisterFilter("LegacyGear", 62, 'ABEvent-1.0')
setFilter.uiName = L['LegacyGear']
setFilter.uiDesc = L['Put legacy items in their own sections.']

function setFilter:OnInitialize()
  self.db = addon.db:RegisterNamespace('LegacyGear', {
    profile = { enable = true, level = 252 },
    char = {  },
  })
end

function setFilter:Update()
  self:SendMessage('AdiBags_FiltersChanged')
end

function setFilter:OnEnable()
  addon:UpdateFilters()
end

function setFilter:OnDisable()
  addon:UpdateFilters()
end

local setNames = {}

function setFilter:Filter(slotData)
  tooltip = tooltip or create()
  tooltip:SetOwner(UIParent,"ANCHOR_NONE")
  tooltip:ClearLines()

  if slotData.bag == BANK_CONTAINER then
    GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(slotData.slot, nil))
  else
    GameTooltip:SetBagItem(slotData.bag, slotData.slot)
  end

  item = GetContainerItemLink(slotData.bag, slotData.slot)
  itemInfo = ItemInfoAsDict(item)
  if self.db.profile.enable then
    if (
      (isEpicGearOrLower(itemInfo) or isTierToken(itemInfo)) and
       itemInfo.ilvl and itemInfo.ilvl < self.db.profile.level
    ) then
        return "Legacy"
    end
  end
end

function setFilter:GetOptions()
  return {
    enable = {
      name = L['Enable LegacyGear'],
      desc = L['Check this if you want a section for legacy gear items.'],
      type = 'toggle',
      order = 10,
    },
    level = {
      name = L['Item level'],
      desc = L['Minimum item level matched'],
      type = 'range',
      min = 0,
      max = 500,
      step = 1,
      order = 20,
    },
    autoSell = {
      name = L['Auto Sell Legacy Gear'],
      desc = L['Check this is you want to automatically sell legacy items.'],
      type = 'toggle',
      order = 30,
    }
  }, addon:GetOptionHandler(self, false, function() return self:Update() end)
end


--- Auto Sell Functionality
function isTierToken(itemInfo)
  if (
    itemInfo.rarity and itemInfo.rarity == EPIC and 
    itemInfo.Type and itemInfo.Type == 'Miscellaneous' and 
    itemInfo.subtype and itemInfo.subtype == 'Junk' and
    itemInfo.ilvl
  ) then
    return true
  end
  return false
end

function isEpicGearOrLower(itemInfo)
  if (
    itemInfo.rarity and itemInfo.rarity <= EPIC and
    itemInfo.Type and (itemInfo.Type == 'Armor' or itemInfo.Type == 'Weapon')
  ) then
    return true
  end
  return false
end

local function sellItem(bag, bagSlot)
  UseContainerItem(bag, bagSlot)
  PickupMerchantItem()
end

function shouldSell(itemInfo)
  if setFilter.db.profile.autoSell then
    -- Filter for epic and lower quality gear and for a specific ilvl set by the user
    if isEpicGearOrLower(itemInfo) or isTierToken(itemInfo) then
      if ilvl and itemInfo.ilvl < setFilter.db.profile.level and
       itemInfo.sellPrice and itemInfo.sellPrice >= 0 then
        return true
      end
    end
  end
  return false
end

function ItemInfoAsDict(item) 
  name, link, rarity, ilvl, minUsableLevel, Type, subtype, stackCount, equipLoc, texture, sellPrice =
   GetItemInfo(item)

  return {
    name = name,
    link = link,
    rarity = rarity,
    ilvl = ilvl,
    minUsableLevel = minUsableLevel,
    Type = Type,
    subtype = subtype,
    stackCount = stackCount,
    equipLoc = equipLoc,
    texture = texture,
    sellPrice = sellPrice
  }
end

function AutoSellItems(self, event)
	-- Auto Sell Items
  itemsSold = 0
	totalPrice = 0	
	for bag = 0,4 do
		for bagSlot = 1, GetContainerNumSlots(bag) do
			item = GetContainerItemLink(bag, bagSlot)
      if item then
        itemInfo = ItemInfoAsDict(item)
			  if shouldSell(itemInfo) then
          sellItem(bag, bagSlot)
          totalPrice = totalPrice + (itemInfo.sellPrice)
          itemsSold = itemsSold + 1
        end
			end
		end
	end
	if totalPrice ~= 0 then
		DEFAULT_CHAT_FRAME:AddMessage(itemsSold.." Items were sold for "..GetCoinTextureString(totalPrice), 255, 255, 255)
	end
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", AutoSellItems);
f:RegisterEvent("MERCHANT_SHOW");