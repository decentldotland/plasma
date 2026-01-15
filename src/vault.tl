local bint: function(number | string): any = require(".bint")(256)
local json: any = require("json")

global type Balance = any
local type Payload = {string: any}
local type ReplyFn = function(Payload): nil

global Variant: string = "0.1.0"
global Name: string | nil = Name or nil
global Identifer: string = Identifer or nil 

global record TokenReq
    address: string
    decimals: number
    name: string
end

global record OrderBookReq
    address: string
    token_a: string
    token_b: string
end

local record Msg
  From: string
  Id: string | nil
  Tags: any
  TagArray: any
  reply: ReplyFn | nil
end

global SupportedTokens: {string: TokenReq} = SupportedTokens or {}
global OrderBooks: {string: OrderBookReq} = OrderBooks or {}
-- user address -> token address -> balance
global Balances: {string: {string: Balance}} = Balances or {}
global Send: function(Payload): nil

local function isOwner(sender: string): boolean
  return sender == Owner
end

local function isAuthority(sender: string) : boolean
  return sender == Marketplace
end

local function addAuthority(id: string)
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

local function getMsgId(msg): string
    return msg.Id
end

local function findTagValue(tags, name: string): string | nil
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