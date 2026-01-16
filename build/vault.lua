local bint = require(".bint")(256)
local json = require("json")

Balance = {}



Variant = "0.1.0"
Name = Name or nil
Identifier = Identifier or nil

TokenReq = {}





OrderBookReq = {}





OrderEscrowReq = {}























SupportedTokens = SupportedTokens or {}

OrderBooks = OrderBooks or {}

AvailableBalances = AvailableBalances or {}
LockedBalances = LockedBalances or {}

OrderEscrow = OrderEscrow or {}


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

local function validateArweaveAddress(address)
   assert(address ~= nil and address ~= "", "token address must be valid ao process id")
end

local function requireOrderbookTokenAuth(orderbook_address, token_address)
   requireSupportedToken(token_address)
   local ob = OrderBooks[orderbook_address]
   assert(ob and ob.tokens and ob.tokens[token_address], "orderbook is not authorized to handle this token")
end


local function emitVaultConfigurationPatch()
   Send({
      device = "patch@1.0",
      ["vault-configuration"] = {
         name = Name,
         variant = Variant,
         identifier = Identifier,
         supportedTokens = SupportedTokens,
         orderBooks = OrderBooks,
      },
   })
end



local function emitLockedBalancesPatch()
   Send({
      device = "patch@1.0",
      ["locked-balances-patch"] = {
         balances = LockedBalances,
      },
   })
end

local function emitAvailableBalancesPatch()
   Send({
      device = "patch@1.0",
      ["available-balances-patch"] = {
         balances = AvailableBalances,
      },
   })
end

local function emitOrderEscrowPatch()
   Send({
      device = "patch@1.0",
      ["order-escrow-patch"] = {
         orders = OrderEscrow,
      },
   })
end

Handlers.add("vault.configure",
Handlers.utils.hasMatchingTag("Action", "Configure"),
function(msg)
   assert(isOwner(msg.From), "Unauthorized")
   Name = tagOrField(msg, "Name") or Name
   Identifier = tagOrField(msg, "Identifier") or Identifier
   Variant = tagOrField(msg, "Variant") or Variant
   emitVaultConfigurationPatch()

   respond(msg, {
      Action = "Configure-OK",
      Variant = Variant,
      Identifier = Identifier,
      Name = Name,
   })

end)


Handlers.add("vault.add_token_support",
Handlers.utils.hasMatchingTag("Action", "AddTokenSupport"),
function(msg)
   assert(isOwner(msg.From), "Unauthorized")
   local token = tagOrField(msg, "TokenAddress")
   validateArweaveAddress(token)
   assert(not SupportedTokens[token], "token is already supported")
   local name = tagOrField(msg, "TokenName")
   local decimals = tagOrField(msg, "TokenDecimals")

   assert(name ~= nil and name ~= "", "token name cannot be nil")
   assert(decimals ~= nil and decimals ~= "" and tonumber(decimals) > 0, "decimals cannot be negative")

   SupportedTokens[token] = {
      address = token,
      name = name,
      decimals = tonumber(decimals),
   }

   addAuthority(token)
   emitVaultConfigurationPatch()

   respond(msg, {
      Action = "AddTokenSupport-OK",
      TokenAddress = token,
      TokenName = name,
      TokenDecimals = tonumber(decimals),
   })
end)


Handlers.add("vault.add_orderbook", Handlers.utils.hasMatchingTag("Action", "AddOrderbook"),
function(msg)
   assert(isOwner(msg.From), "unauthorized")
   local token_a = tagOrField(msg, "TokenA")
   local token_b = tagOrField(msg, "TokenB")
   local address = tagOrField(msg, "OrderbookAddress")
   local fee_bps = tagOrField(msg, "FeeBps")

   validateArweaveAddress(token_a)
   validateArweaveAddress(token_b)
   validateArweaveAddress(address)
   requireSupportedToken(token_a)
   requireSupportedToken(token_b)
   assert(token_a ~= token_b, "token_a and token_b must differ")
   assert(not OrderBooks[address], "orderbook already supported")
   assert(fee_bps ~= nil and fee_bps ~= "" and tonumber(fee_bps) >= 0, "invalid fee_bps param")

   OrderBooks[address] = {
      tokens = {
         [token_a] = true,
         [token_b] = true,
      },

      active = true,
      fee_bps = tonumber(fee_bps),
   }

   addAuthority(address)
   emitVaultConfigurationPatch()

   respond(msg, {
      Action = "AddOrderbook-OK",
      TokenA = token_a,
      TokenB = token_b,
      OrderbookAddress = address,
      FeeBps = tonumber(fee_bps),
   })
end)
