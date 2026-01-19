require "utils.types"
require "vault.types"

local deps = require "utils.deps"
local utils_validation = require "utils.validation"
local bint = deps.bint

local mod = {}

local function requireSupportedToken(address: string)
    assert(SupportedTokens[address], "token not supported")
end

local function requireActiveToken(address: string)
    assert(SupportedTokens[address] and SupportedTokens[address].active, "token not supported")
end

local function requireSupportedOrderBook(address: string)
    assert(OrderBooks[address], "orderbook not supported")
end

local function requireActiveOrderBook(address: string)
    assert(OrderBooks[address] and OrderBooks[address].active, "orderbook not supported or not active")
end

local function requireOrderbookTokenAuth(orderbook_address: string, token_address: string)
  requireActiveToken(token_address)
  local ob = OrderBooks[orderbook_address]
  assert(ob and ob.tokens and ob.active and ob.tokens[token_address], "orderbook is not authorized to handle this token")
end

local function ensureAccount(balanceMap: {string: {string: Balance}}, account: string)
  if not balanceMap[account] then
    balanceMap[account] = {}
  end
end

local function ensureSenderIsOrderbook(orderbook: string, sender: string): nil
  assert(orderbook == sender, "unauthorized orderbook")
end

-- ledger utils
local function addLockedBalances(account: string, token: string, quantity: string)
  ensureAccount(LockedBalances, account)
  utils_validation.requirePositive(quantity, "addLockedBalances")
  LockedBalances[account][token] = tostring(bint(LockedBalances[account][token] or "0") + bint(quantity))
end

local function subLockedBalances(account: string, token: string, quantity: string)
  ensureAccount(LockedBalances, account)
  utils_validation.requirePositive(quantity, "subLockedBalances")
  local nextValue = bint(LockedBalances[account][token] or "0") - bint(quantity)
  assert(nextValue >= bint(0), "locked balance underflow")
  LockedBalances[account][token] = tostring(nextValue)
end

local function addAvailableBalances(account: string, token: string, quantity: string)
  ensureAccount(AvailableBalances, account)
  utils_validation.requirePositive(quantity, "addAvailableBalances")
  AvailableBalances[account][token] = tostring(bint(AvailableBalances[account][token] or "0") + bint(quantity))
end

local function subAvailableBalances(account: string, token: string, quantity: string)
  ensureAccount(AvailableBalances, account)
  utils_validation.requirePositive(quantity, "subAvailableBalances")
  local nextValue = bint(AvailableBalances[account][token] or "0") - bint(quantity)
  assert(nextValue >= bint(0), "available balance underflow")
  AvailableBalances[account][token] = tostring(nextValue)
end

-- registry
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
