local bint = require(".bint")(256)
local json = require("json")

OrderId = {}
Side = {}
OrderStatus = {}
Price = {}
Qty = {}
Variant = "0.1.0"
Name = Name or nil
Vault = Vault or nil
TokenA = TokenA or nil
TokenB = TokenB or nil
Active = Active or nil
BestBid = BestBid or nil
BestAsk = BestAsk or nil
FeeBps = FeeBps or nil
Order = {}
PriceLevel = {}
OrderNode = {}
Trade = {}
Orders = Orders or {}
OrderNodes = OrderNodes or {}
Bids = Bids or {}
Asks = Asks or {}
UserOrders = UserOrders or {}
Trades = Trades or {}
BidPrices = BidPrices or {}
AskPrices = AskPrices or {}
MarketStats = {}
Stats = Stats or {
   last_price = nil,
   vwap = nil,
   volume_24h = "0",
   high_24h = nil,
   low_24h = nil,
}

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

local function removeAuthority(id)
   local a = ao.authorities or {}
   for i = #a, 1, -1 do
      if a[i] == id then
         table.remove(a, i)
      end
   end
   ao.authorities = a
   if SyncState then SyncState(nil) end
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

local function requirePositive(quantity, name)
   assert(quantity, name .. " is required")
   assert(bint.__lt(0, bint(quantity)), name .. " must be greater than 0")
end

local function validateArweaveAddress(address)
   assert(address ~= nil and address ~= "", "token address must be valid ao process id")
end

local function requireActiveBook()
   assert(Active and Vault ~= nil, "Orderbook is inactive")
end

local function requireSupportedToken(address)
   assert(address == TokenA or address == TokenB, "token not supported in this orderbook")
end

local function requireValidSide(side)
   assert(side == "Bid" or side == "Ask", "invalid side")
end

local function emitBestPricesPatch()
   Send({
      device = "patch@1.0",
      ["best-prices-patch"] = {
         BestBid = BestBid,
         BestAsk = BestAsk,
      },
   })
end

local function getBook(side)
   requireValidSide(side)
   if side == "Bid" then
      return Bids
   end
   return Asks
end

local function getPriceList(side)
   requireValidSide(side)
   if side == "Bid" then
      return BidPrices
   end
   return AskPrices
end

local function updateBestPrices()
   local newBestBid = BidPrices[1]
   local newBestAsk = AskPrices[1]
   if newBestBid == BestBid and newBestAsk == BestAsk then
      return
   end
   BestBid = newBestBid
   BestAsk = newBestAsk
   emitBestPricesPatch()
end

local function addPrice(side, price)
   requirePositive(price, "addPrice price")
   local prices = getPriceList(side)

   for _, existing in ipairs(prices) do
      if existing == price then
         return
      end
   end

   local inserted = false
   for i = 1, #prices do
      if side == "Bid" then
         if bint(price) > bint(prices[i]) then
            table.insert(prices, i, price)
            inserted = true
            break
         end
      else
         if bint(price) < bint(prices[i]) then
            table.insert(prices, i, price)
            inserted = true
            break
         end
      end
   end

   if not inserted then
      table.insert(prices, price)
   end

   updateBestPrices()
end

local function removePrice(side, price)
   local prices = getPriceList(side)
   for i = 1, #prices do
      if prices[i] == price then
         table.remove(prices, i)
         break
      end
   end
   updateBestPrices()
end

local function decreaseLevelQty(side, price, qty)
   requirePositive(qty, "decreaseLevelQty qty")
   local book = getBook(side)
   local level = book[price]
   if not level then
      return
   end

   local nextValue = bint(level.total_qty) - bint(qty)
   if nextValue < bint(0) then
      nextValue = bint(0)
   end
   level.total_qty = tostring(nextValue)
end

local function enqueueOrder(side, price, orderId)
   local book = getBook(side)
   local order = Orders[orderId]
   assert(order, "order not found")
   assert(order.price == price, "price mismatch")
   assert(order.side == side, "side mismatch")
   requirePositive(order.remaining, "enqueueOrder remaining")

   if not book[price] then
      book[price] = {
         price = price,
         head = nil,
         tail = nil,
         count = 0,
         total_qty = "0",
      }
      addPrice(side, price)
   end

   assert(not OrderNodes[orderId], "order already enqueued")

   local level = book[price]
   local node = { id = orderId, prev = level.tail, next = nil }

   if level.tail then
      OrderNodes[level.tail].next = orderId
   else
      level.head = orderId
   end

   level.tail = orderId
   level.count = level.count + 1
   level.total_qty = tostring(bint(level.total_qty) + bint(order.remaining))
   OrderNodes[orderId] = node
end

local function dequeueOrder(side, price)
   local book = getBook(side)
   local level = book[price]
   if not level or not level.head then
      return nil
   end

   local orderId = level.head
   local node = OrderNodes[orderId]
   local nextId = node and node.next or nil

   level.head = nextId
   if nextId then
      OrderNodes[nextId].prev = nil
   else
      level.tail = nil
   end

   level.count = level.count - 1
   local order = Orders[orderId]
   if order then
      level.total_qty = tostring(bint(level.total_qty) - bint(order.remaining))
   end
   OrderNodes[orderId] = nil

   if level.count <= 0 then
      book[price] = nil
      removePrice(side, price)
   end

   return orderId
end

local function removeOrderFromLevel(side, price, orderId)
   local book = getBook(side)
   local level = book[price]
   if not level then
      return
   end

   local node = OrderNodes[orderId]
   if not node then
      return
   end

   if node.prev then
      OrderNodes[node.prev].next = node.next
   else
      level.head = node.next
   end

   if node.next then
      OrderNodes[node.next].prev = node.prev
   else
      level.tail = node.prev
   end

   level.count = level.count - 1
   local order = Orders[orderId]
   if order then
      level.total_qty = tostring(bint(level.total_qty) - bint(order.remaining))
   end
   OrderNodes[orderId] = nil

   if level.count <= 0 then
      book[price] = nil
      removePrice(side, price)
   end
end
