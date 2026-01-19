do
local _ENV = _ENV
package.preload[ "utils.deps" ] = function( ... ) local arg = _G.arg;
local mod = {}

local bint = require(".bint")(256)
local json = require("json")

mod.bint = bint
mod.json = json

return mod
end
end

do
local _ENV = _ENV
package.preload[ "utils.types" ] = function( ... ) local arg = _G.arg;
Payload = {}
ReplyFn = {}


Tag = {}






Msg = {}
end
end

do
local _ENV = _ENV
package.preload[ "utils.validation" ] = function( ... ) local arg = _G.arg;
require("utils.types")

local deps = require("utils.deps")
local bint = deps.bint

local mod = {}

function mod.isOwner(sender)
   return sender == Owner
end

function mod.addAuthority(id)
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

function mod.removeAuthority(id)
   local a = ao.authorities or {}
   for i = #a, 1, -1 do
      if a[i] == id then
         table.remove(a, i)
      end
   end
   ao.authorities = a
   if SyncState then SyncState(nil) end
end

function mod.respond(msg, payload)
   if msg.reply then
      msg.reply(payload)
   else
      payload.Target = msg.From
      Send(payload)
   end
end

function mod.getMsgId(msg)
   return msg.Id
end

function mod.findTagValue(tags, name)
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

function mod.tagOrField(msg, name)
   local value = mod.findTagValue(msg.Tags, name) or findTagValue(msg.TagArray, name)
   if value ~= nil then
      return value
   end
   return msg[name]
end

function mod.validateArweaveAddress(address)
   assert(address ~= nil and address ~= "", "token address must be valid ao process id")
end

function mod.requirePositive(quantity, name)
   assert(quantity, name .. " is required")
   assert(bint.__lt(0, bint(quantity)), name .. " must be greater than 0")
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "vault.handlers" ] = function( ... ) local arg = _G.arg;
require("utils.types")
require("vault.types")

local deps = require("utils.deps")
local shared = require("utils.validation")
local helpers = require("vault.helpers")
local patch = require("vault.patch")

local bint = deps.bint
local json = deps.json

local mod = {}


local function configure(msg)
   assert(shared.isOwner(msg.From), "Unauthorized")
   Name = shared.tagOrField(msg, "Name") or Name
   Identifier = shared.tagOrField(msg, "Identifier") or Identifier
   Variant = shared.tagOrField(msg, "Variant") or Variant
   patch.emitVaultConfigurationPatch()

   shared.respond(msg, {
      Action = "Configure-OK",
      Variant = Variant,
      Identifier = Identifier,
      Name = Name,
   })

end



local function add_token_support(msg)
   assert(shared.isOwner(msg.From), "Unauthorized")
   local token = shared.tagOrField(msg, "TokenAddress")
   shared.validateArweaveAddress(token)
   assert(not SupportedTokens[token], "token is already supported")
   local name = shared.tagOrField(msg, "TokenName")
   local decimals = shared.tagOrField(msg, "TokenDecimals")

   assert(name ~= nil and name ~= "", "token name cannot be nil")
   assert(decimals ~= nil and decimals ~= "" and tonumber(decimals) > 0, "decimals cannot be negative")

   SupportedTokens[token] = {
      address = token,
      name = name,
      decimals = tonumber(decimals),
      active = true,
   }

   shared.addAuthority(token)
   patch.emitVaultConfigurationPatch()

   shared.respond(msg, {
      Action = "AddTokenSupport-OK",
      TokenAddress = token,
      TokenName = name,
      Active = true,
      TokenDecimals = tonumber(decimals),
   })
end


local function add_orderbook(msg)
   assert(shared.isOwner(msg.From), "unauthorized")
   local token_a = shared.tagOrField(msg, "TokenA")
   local token_b = shared.tagOrField(msg, "TokenB")
   local address = shared.tagOrField(msg, "OrderbookAddress")
   local fee_bps = shared.tagOrField(msg, "FeeBps")

   shared.validateArweaveAddress(token_a)
   shared.validateArweaveAddress(token_b)
   shared.validateArweaveAddress(address)
   helpers.requireActiveToken(token_a)
   helpers.requireActiveToken(token_b)
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

   shared.addAuthority(address)
   patch.emitVaultConfigurationPatch()

   shared.respond(msg, {
      Action = "AddOrderbook-OK",
      TokenA = token_a,
      TokenB = token_b,
      OrderbookAddress = address,
      FeeBps = tonumber(fee_bps),
   })
end


local function configure_orderbook(msg)
   assert(shared.isOwner(msg.From), "Unauthorized")
   local orderbook_address = shared.tagOrField(msg, "OrderbookAddress")
   local fee_bps = shared.tagOrField(msg, "FeeBps") or nil
   local active = shared.tagOrField(msg, "Active") or nil

   shared.validateArweaveAddress(orderbook_address)
   helpers.requireSupportedOrderBook(orderbook_address)

   local ob_before = OrderBooks[orderbook_address]

   if fee_bps ~= nil then
      assert(fee_bps ~= nil and fee_bps ~= "" and tonumber(fee_bps) >= 0, "invalid fee_bps param")
      OrderBooks[orderbook_address].fee_bps = tonumber(fee_bps)
   end

   if active ~= nil then
      local status_bool = string.tolower(active) == "true"

      if status_bool and not ob_before.active then
         shared.addAuthority(orderbook_address)
      end
      OrderBooks[orderbook_address].active = status_bool

      if not status_bool then
         shared.removeAuthority(orderbook_address)
      end
   end

   patch.emitVaultConfigurationPatch()

   local ob_after = OrderBooks[orderbook_address]


   shared.respond(msg, {
      Action = "ConfigureOrderbook-OK",
      FeeBps = ob_after.fee_bps,
      Active = ob_after.active,
      OrderbookAddress = orderbook_address,
   })
end


local function configure_token(msg)

   assert(shared.isOwner(msg.From), "unauthorized")
   local token_address = shared.tagOrField(msg, "TokenAddress")
   local token_name = shared.tagOrField(msg, "TokenName")
   local token_decimals = shared.tagOrField(msg, "TokenDecimals")
   local token_active = shared.tagOrField(msg, "TokenActive")

   assert(token_address ~= nil and token_address ~= "", "TokenAddress required")
   shared.validateArweaveAddress(token_address)
   helpers.requireSupportedToken(token_address)

   local token_before = SupportedTokens[token_address]

   if token_name ~= nil and token_name ~= "" then
      SupportedTokens[token_address].name = token_name
   end

   if token_decimals ~= nil and tonumber(token_decimals) > 0 then
      SupportedTokens[token_address].decimals = tonumber(token_decimals)
   end

   if token_active == "true" or token_active == "false" then
      if token_active == "true" and not token_before.active then
         shared.addAuthority(token_address)
      end
      SupportedTokens[token_address].active = token_active == "true"
      if token_active == "false" then
         shared.removeAuthority(token_address)
      end
   end

   patch.emitVaultConfigurationPatch()

   local token_after = SupportedTokens[token_address]

   shared.respond(msg, {
      Action = "ConfigureToken-OK",
      Name = token_after.name,
      Active = token_after.active,
      Decimals = token_after.decimals,
   })

end



local function credit_notice(msg)
   local token = msg.From
   local sender = shared.tagOrField(msg, "Sender")
   local quantity = shared.tagOrField(msg, "Quantity")
   local recipient = shared.tagOrField(msg, "Recipient")

   helpers.requireActiveToken(token)
   shared.validateArweaveAddress(sender)
   shared.requirePositive(quantity, "Deposit quantity")
   if recipient ~= nil then
      assert(recipient == ao.id, "invalid deposit recipient")
   end

   helpers.addAvailableBalances(sender, token, quantity)
   patch.emitAvailableBalancesPatch()

   shared.respond(msg, {
      Action = "Deposit-OK",
      TokenAddress = token,
      Sender = sender,
      Quantity = quantity,
   })
end


local function withdraw(msg)
   local token = shared.tagOrField(msg, "TokenAddress")
   local quantity = shared.tagOrField(msg, "Quantity")
   local recipient = shared.tagOrField(msg, "Recipient") or msg.From

   shared.validateArweaveAddress(token)
   shared.validateArweaveAddress(recipient)
   helpers.requireSupportedToken(token)
   shared.requirePositive(quantity, "Withdraw quantity")

   helpers.subAvailableBalances(msg.From, token, quantity)
   helpers.addLockedBalances(msg.From, token, quantity)

   local withdraw_id = shared.getMsgId(msg)
   assert(withdraw_id ~= nil and withdraw_id ~= "", "withdraw_id unavailable")

   PendingWithdrawals[withdraw_id] = {
      user = msg.From,
      token = token,
      quantity = quantity,
      recipient = recipient,
      created = tostring(msg.Timestamp or ""),
   }

   Send({
      Target = token,
      Action = "Transfer",
      Tags = {
         Recipient = recipient,
         Quantity = quantity,
         ["X-Withdraw-Id"] = withdraw_id,
         ["X-Withdraw-User"] = msg.From,
         ["X-Vault-Id"] = ao.id,
      },
   })

   patch.emitAvailableBalancesPatch()
   patch.emitLockedBalancesPatch()

   shared.respond(msg, {
      Action = "Withdraw-Pending",
      WithdrawId = withdraw_id,
      TokenAddress = token,
      Recipient = recipient,
      Quantity = quantity,
   })
end




local function debit_notice(msg)
   local withdraw_id = shared.tagOrField(msg, "X-Withdraw-Id")
   local system_id = shared.tagOrField(msg, "X-Vault-Id")
   if not withdraw_id or system_id ~= ao.id then
      return
   end

   local pending = PendingWithdrawals[withdraw_id]
   if not pending then
      return
   end

   assert(msg.From == pending.token, "invalid token for withdraw")

   helpers.subLockedBalances(pending.user, pending.token, pending.quantity)
   PendingWithdrawals[withdraw_id] = nil
   patch.emitLockedBalancesPatch()

   Send({
      Target = pending.user,
      Action = "Withdraw-OK",
      Tags = {
         WithdrawId = withdraw_id,
         TokenAddress = pending.token,
         Recipient = pending.recipient,
         Quantity = pending.quantity,
      },
   })
end



local function lock(msg)
   local order_id = shared.tagOrField(msg, "OrderId")
   local user = shared.tagOrField(msg, "User")
   local token = shared.tagOrField(msg, "TokenAddress")
   local quantity = shared.tagOrField(msg, "Quantity")
   local side = shared.tagOrField(msg, "Side")

   assert(order_id and order_id ~= "", "OrderId required")
   shared.validateArweaveAddress(user)
   shared.validateArweaveAddress(token)
   shared.validateArweaveAddress(order_id)
   helpers.requireActiveOrderBook(msg.From)
   helpers.requireOrderbookTokenAuth(msg.From, token)
   shared.requirePositive(quantity, "Lock quantity")

   assert(not OrderEscrow[order_id], "order already escrowed")


   helpers.subAvailableBalances(user, token, quantity)
   helpers.addLockedBalances(user, token, quantity)

   OrderEscrow[order_id] = {
      user = user,
      token = token,
      amount = quantity,
      filled = "0",
      side = side or "",
      orderbook = msg.From,
   }

   patch.emitAvailableBalancesPatch()
   patch.emitLockedBalancesPatch()
   patch.emitOrderEscrowPatch()

   shared.respond(msg, {
      Action = "Lock-OK",
      OrderId = order_id,
   })
end

local function unlock(msg)
   local order_id = shared.tagOrField(msg, "OrderId")

   assert(order_id and order_id ~= "", "OrderId required")

   local esc = OrderEscrow[order_id]
   assert(esc, "order not escrowed")
   assert(esc.orderbook == msg.From, "unauthorized orderbook")


   local remaining = bint(esc.amount) - bint(esc.filled)
   assert(remaining >= bint(0), "invalid escrow remaining")

   if remaining > bint(0) then
      helpers.subLockedBalances(esc.user, esc.token, tostring(remaining))
      helpers.addAvailableBalances(esc.user, esc.token, tostring(remaining))
   end

   OrderEscrow[order_id] = nil

   patch.emitAvailableBalancesPatch()
   patch.emitLockedBalancesPatch()
   patch.emitOrderEscrowPatch()

   shared.respond(msg, {
      Action = "Unlock-OK",
      OrderId = order_id,
   })
end

local function settle(msg)
   local order_id = shared.tagOrField(msg, "OrderId")
   local recipient = shared.tagOrField(msg, "Recipient")
   local fill_qty = shared.tagOrField(msg, "FillQuantity")

   shared.validateArweaveAddress(recipient)
   shared.validateArweaveAddress(order_id)
   shared.requirePositive(fill_qty, "FillQuantity")

   local esc = OrderEscrow[order_id]
   assert(esc, "order not escrowed")
   helpers.ensureSenderIsOrderbook(esc.orderbook, msg.From)

   local remaining = bint(esc.amount) - bint(esc.filled)
   assert(bint(fill_qty) <= remaining, "fill exceeds escrow")


   helpers.subLockedBalances(esc.user, esc.token, fill_qty)
   helpers.addAvailableBalances(recipient, esc.token, fill_qty)

   esc.filled = tostring(bint(esc.filled) + bint(fill_qty))


   if bint(esc.filled) == bint(esc.amount) then
      OrderEscrow[order_id] = nil
   end

   patch.emitAvailableBalancesPatch()
   patch.emitLockedBalancesPatch()
   patch.emitOrderEscrowPatch()

   shared.respond(msg, {
      Action = "Settle-OK",
      OrderId = order_id,
      Filled = fill_qty,
   })
end



local function cancel(msg)
   local order_id = shared.tagOrField(msg, "OrderId")

   shared.validateArweaveAddress(order_id)

   local esc = OrderEscrow[order_id]
   assert(esc, "order not escrowed")
   helpers.ensureSenderIsOrderbook(esc.orderbook, msg.From)

   local remaining = bint(esc.amount) - bint(esc.filled)
   assert(remaining >= bint(0), "invalid escrow remaining")

   if remaining > bint(0) then
      helpers.subLockedBalances(esc.user, esc.token, tostring(remaining))
      helpers.addAvailableBalances(esc.user, esc.token, tostring(remaining))
   end

   OrderEscrow[order_id] = nil

   patch.emitAvailableBalancesPatch()
   patch.emitLockedBalancesPatch()
   patch.emitOrderEscrowPatch()

   shared.respond(msg, {
      Action = "Cancel-OK",
      OrderId = order_id,
   })
end



mod.configure = configure
mod.add_token_support = add_token_support
mod.add_orderbook = add_orderbook
mod.configure_orderbook = configure_orderbook
mod.configure_token = configure_token
mod.credit_notice = credit_notice
mod.withdraw = withdraw
mod.debit_notice = debit_notice
mod.lock = lock
mod.unlock = unlock
mod.settle = settle
mod.cancel = cancel

return mod
end
end

do
local _ENV = _ENV
package.preload[ "vault.helpers" ] = function( ... ) local arg = _G.arg;
require("utils.types")
require("vault.types")

local deps = require("utils.deps")
local utils_validation = require("utils.validation")
local bint = deps.bint

local mod = {}

local function requireSupportedToken(address)
   assert(SupportedTokens[address], "token not supported")
end

local function requireActiveToken(address)
   assert(SupportedTokens[address] and SupportedTokens[address].active, "token not supported")
end

local function requireSupportedOrderBook(address)
   assert(OrderBooks[address], "orderbook not supported")
end

local function requireActiveOrderBook(address)
   assert(OrderBooks[address] and OrderBooks[address].active, "orderbook not supported or not active")
end

local function requireOrderbookTokenAuth(orderbook_address, token_address)
   requireActiveToken(token_address)
   local ob = OrderBooks[orderbook_address]
   assert(ob and ob.tokens and ob.active and ob.tokens[token_address], "orderbook is not authorized to handle this token")
end

local function ensureAccount(balanceMap, account)
   if not balanceMap[account] then
      balanceMap[account] = {}
   end
end

local function ensureSenderIsOrderbook(orderbook, sender)
   assert(orderbook == sender, "unauthorized orderbook")
end


local function addLockedBalances(account, token, quantity)
   ensureAccount(LockedBalances, account)
   utils_validation.requirePositive(quantity, "addLockedBalances")
   LockedBalances[account][token] = tostring(bint(LockedBalances[account][token] or "0") + bint(quantity))
end

local function subLockedBalances(account, token, quantity)
   ensureAccount(LockedBalances, account)
   utils_validation.requirePositive(quantity, "subLockedBalances")
   local nextValue = bint(LockedBalances[account][token] or "0") - bint(quantity)
   assert(nextValue >= bint(0), "locked balance underflow")
   LockedBalances[account][token] = tostring(nextValue)
end

local function addAvailableBalances(account, token, quantity)
   ensureAccount(AvailableBalances, account)
   utils_validation.requirePositive(quantity, "addAvailableBalances")
   AvailableBalances[account][token] = tostring(bint(AvailableBalances[account][token] or "0") + bint(quantity))
end

local function subAvailableBalances(account, token, quantity)
   ensureAccount(AvailableBalances, account)
   utils_validation.requirePositive(quantity, "subAvailableBalances")
   local nextValue = bint(AvailableBalances[account][token] or "0") - bint(quantity)
   assert(nextValue >= bint(0), "available balance underflow")
   AvailableBalances[account][token] = tostring(nextValue)
end


mod.requireSupportedToken = requireSupportedToken
mod.requireActiveToken = requireActiveToken
mod.requireSupportedOrderBook = requireSupportedOrderBook
mod.requireActiveOrderBook = requireActiveOrderBook
mod.requireOrderbookTokenAuth = requireOrderbookTokenAuth
mod.ensureAccount = ensureAccount
mod.ensureSenderIsOrderbook = ensureSenderIsOrderbook
mod.addLockedBalances = addLockedBalances
mod.subLockedBalances = subLockedBalances
mod.addAvailableBalances = addAvailableBalances
mod.subAvailableBalances = subAvailableBalances

return mod
end
end

do
local _ENV = _ENV
package.preload[ "vault.main" ] = function( ... ) local arg = _G.arg;
require("utils.types")
require("vault.types")

local handlers = require("vault.handlers")

Handlers.add(
"vault.configure",
Handlers.utils.hasMatchingTag("Action", "Configure"),
handlers.configure)


Handlers.add(
"vault.add_token_support",
Handlers.utils.hasMatchingTag("Action", "AddTokenSupport"),
handlers.add_token_support)


Handlers.add(
"vault.add_orderbook",
Handlers.utils.hasMatchingTag("Action", "AddOrderbook"),
handlers.add_orderbook)


Handlers.add(
"vault.configure_orderbook",
Handlers.utils.hasMatchingTag("Action", "ConfigureOrderbook"),
handlers.configure_orderbook)


Handlers.add(
"vault.configure_token",
Handlers.utils.hasMatchingTag("Action", "ConfigureToken"),
handlers.configure_token)


Handlers.add(
"vault.credit_notice",
Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
handlers.credit_notice)


Handlers.add(
"vault.withdraw",
Handlers.utils.hasMatchingTag("Action", "Withdraw"),
handlers.withdraw)


Handlers.add(
"vault.debit_notice",
Handlers.utils.hasMatchingTag("Action", "Debit-Notice"),
handlers.debit_notice)


Handlers.add(
"vault.lock",
Handlers.utils.hasMatchingTag("Action", "Lock"),
handlers.lock)


Handlers.add(
"vault.unlock",
Handlers.utils.hasMatchingTag("Action", "Unlock"),
handlers.unlock)


Handlers.add(
"vault.settle",
Handlers.utils.hasMatchingTag("Action", "Settle"),
handlers.settle)


Handlers.add(
"vault.cancel",
Handlers.utils.hasMatchingTag("Action", "Cancel"),
handlers.cancel)
end
end

do
local _ENV = _ENV
package.preload[ "vault.patch" ] = function( ... ) local arg = _G.arg;
require("utils.types")
require("vault.types")

local mod = {}

function mod.emitVaultConfigurationPatch()
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



function mod.emitLockedBalancesPatch()
   Send({
      device = "patch@1.0",
      ["locked-balances-patch"] = {
         balances = LockedBalances,
      },
   })
end

function mod.emitAvailableBalancesPatch()
   Send({
      device = "patch@1.0",
      ["available-balances-patch"] = {
         balances = AvailableBalances,
      },
   })
end

function mod.emitOrderEscrowPatch()
   Send({
      device = "patch@1.0",
      ["order-escrow-patch"] = {
         orders = OrderEscrow,
      },
   })
end

return mod
end
end

do
local _ENV = _ENV
package.preload[ "vault.types" ] = function( ... ) local arg = _G.arg;
require("utils.types")

Balance = {}
Variant = "0.1.0"
Name = Name or nil
Identifier = Identifier or nil

TokenReq = {}






OrderBookReq = {}





OrderEscrowReq = {}








PendingWithdrawReq = {}







SupportedTokens = SupportedTokens or {}

OrderBooks = OrderBooks or {}

AvailableBalances = AvailableBalances or {}
LockedBalances = LockedBalances or {}

OrderEscrow = OrderEscrow or {}

PendingWithdrawals = PendingWithdrawals or {}
end
end

require("utils.types")
require("vault.types")

local handlers = require("vault.handlers")

Handlers.add(
"vault.configure",
Handlers.utils.hasMatchingTag("Action", "Configure"),
handlers.configure)


Handlers.add(
"vault.add_token_support",
Handlers.utils.hasMatchingTag("Action", "AddTokenSupport"),
handlers.add_token_support)


Handlers.add(
"vault.add_orderbook",
Handlers.utils.hasMatchingTag("Action", "AddOrderbook"),
handlers.add_orderbook)


Handlers.add(
"vault.configure_orderbook",
Handlers.utils.hasMatchingTag("Action", "ConfigureOrderbook"),
handlers.configure_orderbook)


Handlers.add(
"vault.configure_token",
Handlers.utils.hasMatchingTag("Action", "ConfigureToken"),
handlers.configure_token)


Handlers.add(
"vault.credit_notice",
Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
handlers.credit_notice)


Handlers.add(
"vault.withdraw",
Handlers.utils.hasMatchingTag("Action", "Withdraw"),
handlers.withdraw)


Handlers.add(
"vault.debit_notice",
Handlers.utils.hasMatchingTag("Action", "Debit-Notice"),
handlers.debit_notice)


Handlers.add(
"vault.lock",
Handlers.utils.hasMatchingTag("Action", "Lock"),
handlers.lock)


Handlers.add(
"vault.unlock",
Handlers.utils.hasMatchingTag("Action", "Unlock"),
handlers.unlock)


Handlers.add(
"vault.settle",
Handlers.utils.hasMatchingTag("Action", "Settle"),
handlers.settle)


Handlers.add(
"vault.cancel",
Handlers.utils.hasMatchingTag("Action", "Cancel"),
handlers.cancel)
