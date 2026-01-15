local bint = require(".bint")(256)
local json = require("json")

Balance = {}



Variant = "0.1.0"
Name = Name or nil
Identifer = Identifer or nil

TokenReq = {}





OrderBookReq = {}




















SupportedTokens = SupportedTokens or {}
OrderBooks = OrderBooks or {}

Balances = Balances or {}


local function isOwner(sender)
   return sender == Owner
end

local function addAuthority(id)
   local a = ao.authorities or {}
   for _, v in ipairs(a) do
      if v == id then return end
   end
   table.insert(a, id)
   ao.authorities = a
   if SyncState then
      SyncState(nil)
   end
end

local function respond(msg, payload)
   if msg.reply then
      msg.reply(payload)
   else
      payload.Target = msg.From
      Send(payload)
   end
end

local function getMsgId(msg)
   return msg.Id
end

local function findTagValue(tags, name)
   if not tags then
      return nil
   end
   local lower = string.lower(name)
   if tags[1] then
      for _, tag in ipairs(tags) do
         local tagName = tag.name or tag.Name
         if tagName and string.lower(tagName) == lower then
            return tag.value or tag.Value
         end
      end
   end
   if tags[name] ~= nil then
      return tags[name]
   end
   for k, v in pairs(tags) do
      if type(k) == "string" and string.lower(k) == lower then
         return v
      end
   end
   return nil
end

local function tagOrField(msg, name)
   local value = findTagValue(msg.Tags, name) or findTagValue(msg.TagArray, name)
   if value ~= nil then
      return value
   end
   return msg[name]
end

local function requireSupportedToken(address)
   assert(SupportedTokens[address], "token not supported")
end

local function requireSupportedOrderBook(address)
   assert(OrderBooks[address], "orderbook not supported")
end
