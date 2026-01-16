local bint: function(number | string): any = require(".bint")(256)
local json: any = require("json")

global type Balance = any
local type Payload = {string: any}
local type ReplyFn = function(Payload): nil

global Variant: string = "0.1.0"
global Name: string | nil = Name or nil
global Identifier: string | nil = Identifier or nil 

global record TokenReq
    address: string
    decimals: number
    name: string
end

global record OrderBookReq
  tokens: {string: boolean}
  active: boolean
  fee_bps: string
end

global record OrderEscrowReq
  user: string
  token: string
  amount: string
  filled: string
  side: string
  orderbook: string
end

local record Tag
    name: string | nil
    Name: string | nil
    value: string | nil
    Value: string | nil
end

local record Msg
    From: string
    Id: string | nil
    Tags: {Tag} | {string: string} | nil
    TagArray: {Tag} | nil
    reply: ReplyFn | nil
end

global SupportedTokens: {string: TokenReq} = SupportedTokens or {}
-- orderbook address -> tokens = {token_a] = true, [token_b] = true}
global OrderBooks: {string: OrderBookReq} = OrderBooks or {}
-- user address -> token address -> balance
global AvailableBalances: {string: {string: Balance}} = AvailableBalances or {}
global LockedBalances: {string: {string: Balance}} = LockedBalances or {}
-- order_id -> OrderEscrowReq
global OrderEscrow: {string: OrderEscrowReq} = OrderEscrow or {}
global Send: function(Payload): nil

local function isOwner(sender: string): boolean
  return sender == Owner
end

local function addAuthority(id: string): nil
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

local function respond(msg: Msg, payload: Payload)
  if msg.reply then
    msg.reply(payload)
  else
    payload.Target = msg.From
    Send(payload)
  end
end

local function getMsgId(msg: Msg): string | nil
    return msg.Id
end

local function findTagValue(tags: {Tag} | nil, name: string): string | nil
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

local function tagOrField(msg: Msg, name: string): string | nil
  local value = findTagValue(msg.Tags, name) or findTagValue(msg.TagArray, name)
  if value ~= nil then
    return value
  end
  return msg[name]
end

local function requireSupportedToken(address: string)
    assert(SupportedTokens[address], "token not supported")
end

local function requireSupportedOrderBook(address: string)
    assert(OrderBooks[address], "orderbook not supported")
end

local function requireOrderbookTokenAuth(orderbook_address: string, token_address: string)
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
            orderBooks = OrderBooks
        }
    })
end

-- full emission, no deltas

local function emitLockedBalancesPatch()
  Send({
    device = "patch@1.0",
    ["locked-balances-patch"] = {
      balances = LockedBalances
    }
  })
end

local function emitAvailableBalancesPatch()
  Send({
    device = "patch@1.0",
    ["available-balances-patch"] = {
      balances = AvailableBalances
    }
  })
end

local function emitOrderEscrowPatch()
  Send({
    device = "patch@1.0",
    ["order-escrow-patch"] = {
      orders = OrderEscrow
    }
  })
end

Handlers.add("vault.configure", 
  Handlers.utils.hasMatchingTag("Action", "Configure"),
  function(msg: Msg)
    assert(isOwner(msg.From), "Unauthorized")
    Name =  tagOrField(msg, "Name") or Name
    Identifier = fintagOrFielddTagValue(msg, "Identifier") or Identifier
    Variant = tagOrField(msg, "Variant") or Variant
    emitVaultConfigurationPatch()

    respond(msg, {
      Action = "Configure-OK",
      Variant = Variant,
      Identifier = Identifier,
      Name = Name,
    })

  end
)