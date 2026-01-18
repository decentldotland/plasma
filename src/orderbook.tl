local bint: function(number | string): any = require(".bint")(256)
local json: any = require("json")

global type OrderId = string
-- Side: "Bid" | "Ask"
global type Side = string
-- OrderStatus: "New" | "Partial" | "Filled" | "Cancelled"
global type OrderStatus = string
global type Price = string
global type Qty = string
local type Payload = {string: any}
local type ReplyFn = function(Payload): nil
global Send: function(Payload): nil

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

global Variant: string = "0.1.0"
global Name: string | nil = Name or nil
global Vault: string | nil = Vault or nil
global TokenA: string | nil = TokenA or nil
global TokenB: string | nil = TokenB or nil
global Active: boolean | nil = Active or nil
global BestBid: Price | nil = BestBid or nil
global BestAsk: Price | nil = BestAsk or nil
global FeeBps: string | nil = FeeBps or nil

global record Order
    id: OrderId
    price: Price
    side: Side
    qty: Qty
    remaining: Qty
    owner: string
    timestamp: string
    status: OrderStatus
end

-- FIFO metadata queue per price
global record PriceLevel
    price: Price
    head: OrderId | nil
    tail: OrderId | nil
    count: number
    total_qty: Qty
end

-- linked list node for FIFO within a price level
global record OrderNode
    id: OrderId
    prev: OrderId | nil
    next: OrderId | nil
end

-- trade/event record
global record Trade
    price: Price
    qty: Qty
    maker: string
    taker: string
    maker_order: OrderId
    taker_order: OrderId
    timestamp: string
end

-- order id -> Order map
global Orders: {OrderId: Order} = Orders or {}
-- order id -> node (O(1) cancel and queue updates)
global OrderNodes: {OrderId: OrderNode} = OrderNodes or {}
-- price -> price level record -- FIFO time priority queue
-- separate books for scalability
global Bids: {Price: PriceLevel} = Bids or {}
global Asks: {Price: PriceLevel} = Asks or {}
-- ownder -> set of related orders ids
global UserOrders: {string: {OrderId: boolean}} = UserOrders or {}
-- executed trades history for orderbook stats / data feed
global Trades: {number: Trade} = Trades or {}
-- sorted price arrays for best price traversal
global BidPrices: {number: Price} = BidPrices or {}
global AskPrices: {number: Price} = AskPrices or {}

-- orderbook stats types
global record MarketStats
    last_price: Price | nil
    vwap: Price | nil
    volume_24h: Qty
    high_24h: Price | nil
    low_24h: Price | nil
end

global Stats: MarketStats = Stats or {
    last_price = nil,
    vwap = nil,
    volume_24h = "0",
    high_24h = nil,
    low_24h = nil
}

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

local function removeAuthority(id: string): nil
    local a = ao.authorities or {}
    for i = #a, 1, -1 do
      if a[i] == id then
        table.remove(a, i)
      end
    end
    ao.authorities = a
    if SyncState then SyncState(nil) end
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

local function requirePositive(quantity: string, name: string): nil
  assert(quantity, name .. " is required")
  assert(bint.__lt(0, bint(quantity)), name .. " must be greater than 0")
end

local function validateArweaveAddress(address: string): nil
  assert(address ~= nil and address ~= "", "token address must be valid ao process id")
end

local function requireActiveBook(): nil
    assert(Active and Vault ~= nil, "Orderbook is inactive")
end

local function requireSupportedToken(address: string): nil
    assert(address == TokenA or address == TokenB, "token not supported in this orderbook")
end
