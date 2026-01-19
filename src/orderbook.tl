-- local bint: function(number | string): any = require(".bint")(256)
-- local json: any = require("json")

-- global type OrderId = string
-- -- Side: "Bid" | "Ask"
-- global type Side = string
-- -- OrderStatus: "New" | "Partial" | "Filled" | "Cancelled"
-- global type OrderStatus = string
-- global type Price = string
-- global type Qty = string
-- local type Payload = {string: any}
-- local type ReplyFn = function(Payload): nil
-- global Send: function(Payload): nil

-- local record Tag
--     name: string | nil
--     Name: string | nil
--     value: string | nil
--     Value: string | nil
-- end

-- local record Msg
--     From: string
--     Id: string | nil
--     Tags: {Tag} | {string: string} | nil
--     TagArray: {Tag} | nil
--     reply: ReplyFn | nil
-- end

-- global Variant: string = "0.1.0"
-- global Name: string | nil = Name or nil
-- global Vault: string | nil = Vault or nil
-- global TokenA: string | nil = TokenA or nil
-- global TokenB: string | nil = TokenB or nil
-- global Active: boolean | nil = Active or nil
-- global BestBid: Price | nil = BestBid or nil
-- global BestAsk: Price | nil = BestAsk or nil
-- global FeeBps: string | nil = FeeBps or nil

-- global record Order
--     id: OrderId
--     price: Price
--     side: Side
--     qty: Qty
--     remaining: Qty
--     owner: string
--     timestamp: string
--     status: OrderStatus
-- end

-- -- FIFO metadata queue per price
-- global record PriceLevel
--     price: Price
--     head: OrderId | nil
--     tail: OrderId | nil
--     count: number
--     total_qty: Qty
-- end

-- -- linked list node for FIFO within a price level
-- global record OrderNode
--     id: OrderId
--     prev: OrderId | nil
--     next: OrderId | nil
-- end

-- -- trade/event record
-- global record Trade
--     price: Price
--     qty: Qty
--     maker: string
--     taker: string
--     maker_order: OrderId
--     taker_order: OrderId
--     timestamp: string
-- end

-- -- order id -> Order map
-- global Orders: {OrderId: Order} = Orders or {}
-- -- order id -> node (O(1) cancel and queue updates)
-- global OrderNodes: {OrderId: OrderNode} = OrderNodes or {}
-- -- price -> price level record -- FIFO time priority queue
-- -- separate books for scalability
-- global Bids: {Price: PriceLevel} = Bids or {}
-- global Asks: {Price: PriceLevel} = Asks or {}
-- -- ownder -> set of related orders ids
-- global UserOrders: {string: {OrderId: boolean}} = UserOrders or {}
-- -- executed trades history for orderbook stats / data feed
-- global Trades: {number: Trade} = Trades or {}
-- -- sorted price arrays for best price traversal
-- global BidPrices: {number: Price} = BidPrices or {}
-- global AskPrices: {number: Price} = AskPrices or {}

-- -- orderbook stats types
-- global record MarketStats
--     last_price: Price | nil
--     vwap: Price | nil
--     volume_24h: Qty
--     high_24h: Price | nil
--     low_24h: Price | nil
-- end

-- global Stats: MarketStats = Stats or {
--     last_price = nil,
--     vwap = nil,
--     volume_24h = "0",
--     high_24h = nil,
--     low_24h = nil
-- }

-- local function isOwner(sender: string): boolean
--   return sender == Owner
-- end

-- local function addAuthority(id: string): nil
--   local a = ao.authorities or {}
--   for _, v in ipairs(a) do
--     if v == id then return end
--   end
--   table.insert(a, id)
--   ao.authorities = a
--   if SyncState then
--     SyncState(nil)
--   end
-- end

-- local function removeAuthority(id: string): nil
--     local a = ao.authorities or {}
--     for i = #a, 1, -1 do
--       if a[i] == id then
--         table.remove(a, i)
--       end
--     end
--     ao.authorities = a
--     if SyncState then SyncState(nil) end
-- end

-- local function respond(msg: Msg, payload: Payload)
--   if msg.reply then
--     msg.reply(payload)
--   else
--     payload.Target = msg.From
--     Send(payload)
--   end
-- end

-- local function getMsgId(msg: Msg): string | nil
--     return msg.Id
-- end

-- local function findTagValue(tags: {Tag} | nil, name: string): string | nil
--   if not tags then
--     return nil
--   end
--   local lower = string.lower(name)
--   if tags[1] then
--     for _, tag in ipairs(tags) do
--       local tagName = tag.name or tag.Name
--       if tagName and string.lower(tagName) == lower then
--         return tag.value or tag.Value
--       end
--     end
--   end
--   if tags[name] ~= nil then
--     return tags[name]
--   end
--   for k, v in pairs(tags) do
--     if type(k) == "string" and string.lower(k) == lower then
--       return v
--     end
--   end
--   return nil
-- end

-- local function tagOrField(msg: Msg, name: string): string | nil
--   local value = findTagValue(msg.Tags, name) or findTagValue(msg.TagArray, name)
--   if value ~= nil then
--     return value
--   end
--   return msg[name]
-- end

-- local function requirePositive(quantity: string, name: string): nil
--   assert(quantity, name .. " is required")
--   assert(bint.__lt(0, bint(quantity)), name .. " must be greater than 0")
-- end

-- local function validateArweaveAddress(address: string): nil
--   assert(address ~= nil and address ~= "", "token address must be valid ao process id")
-- end

-- local function requireActiveBook(): nil
--     assert(Active and Vault ~= nil, "Orderbook is inactive")
-- end

-- local function requireSupportedToken(address: string): nil
--     assert(address == TokenA or address == TokenB, "token not supported in this orderbook")
-- end

-- local function requireValidSide(side: Side): nil
--   assert(side == "Bid" or side == "Ask", "invalid side")
-- end

-- local function emitBestPricesPatch(): nil
--     Send({
--         device = "patch@1.0",
--         ["best-prices-patch"] = {
--             BestBid = BestBid,
--             BestAsk = BestAsk
--         }
--     })
-- end

-- local function getBook(side: Side): {Price: PriceLevel}
--   requireValidSide(side)
--   if side == "Bid" then
--     return Bids
--   end
--   return Asks
-- end

-- local function getPriceList(side: Side): {number: Price}
--   requireValidSide(side)
--   if side == "Bid" then
--     return BidPrices
--   end
--   return AskPrices
-- end

-- local function updateBestPrices(): nil
--   local newBestBid = BidPrices[1]
--   local newBestAsk = AskPrices[1]
--   if newBestBid == BestBid and newBestAsk == BestAsk then
--     return
--   end
--   BestBid = newBestBid
--   BestAsk = newBestAsk
--   emitBestPricesPatch()
-- end

-- local function addPrice(side: Side, price: Price): nil
--   requirePositive(price, "addPrice price")
--   local prices = getPriceList(side)

--   for _, existing in ipairs(prices) do
--     if existing == price then
--       return
--     end
--   end

--   local inserted = false
--   for i = 1, #prices do
--     if side == "Bid" then
--       if bint(price) > bint(prices[i]) then
--         table.insert(prices, i, price)
--         inserted = true
--         break
--       end
--     else
--       if bint(price) < bint(prices[i]) then
--         table.insert(prices, i, price)
--         inserted = true
--         break
--       end
--     end
--   end

--   if not inserted then
--     table.insert(prices, price)
--   end

--   updateBestPrices()
-- end

-- local function removePrice(side: Side, price: Price): nil
--   local prices = getPriceList(side)
--   for i = 1, #prices do
--     if prices[i] == price then
--       table.remove(prices, i)
--       break
--     end
--   end
--   updateBestPrices()
-- end

-- local function decreaseLevelQty(side: Side, price: Price, qty: Qty): nil
--   requirePositive(qty, "decreaseLevelQty qty")
--   local book = getBook(side)
--   local level = book[price]
--   if not level then
--     return
--   end

--   local nextValue = bint(level.total_qty) - bint(qty)
--   if nextValue < bint(0) then
--     nextValue = bint(0)
--   end
--   level.total_qty = tostring(nextValue)
-- end

-- local function enqueueOrder(side: Side, price: Price, orderId: OrderId): nil
--   local book = getBook(side)
--   local order = Orders[orderId]
--   assert(order, "order not found")
--   assert(order.price == price, "price mismatch")
--   assert(order.side == side, "side mismatch")
--   requirePositive(order.remaining, "enqueueOrder remaining")

--   if not book[price] then
--     book[price] = {
--       price = price,
--       head = nil,
--       tail = nil,
--       count = 0,
--       total_qty = "0"
--     }
--     addPrice(side, price)
--   end

--   assert(not OrderNodes[orderId], "order already enqueued")

--   local level = book[price]
--   local node: OrderNode = { id = orderId, prev = level.tail, next = nil }

--   if level.tail then
--     OrderNodes[level.tail].next = orderId
--   else
--     level.head = orderId
--   end

--   level.tail = orderId
--   level.count = level.count + 1
--   level.total_qty = tostring(bint(level.total_qty) + bint(order.remaining))
--   OrderNodes[orderId] = node
-- end

-- local function dequeueOrder(side: Side, price: Price): OrderId | nil
--   local book = getBook(side)
--   local level = book[price]
--   if not level or not level.head then
--     return nil
--   end

--   local orderId = level.head
--   local node = OrderNodes[orderId]
--   local nextId = node and node.next or nil

--   level.head = nextId
--   if nextId then
--     OrderNodes[nextId].prev = nil
--   else
--     level.tail = nil
--   end

--   level.count = level.count - 1
--   local order = Orders[orderId]
--   if order then
--     level.total_qty = tostring(bint(level.total_qty) - bint(order.remaining))
--   end
--   OrderNodes[orderId] = nil

--   if level.count <= 0 then
--     book[price] = nil
--     removePrice(side, price)
--   end

--   return orderId
-- end

-- local function removeOrderFromLevel(side: Side, price: Price, orderId: OrderId): nil
--   local book = getBook(side)
--   local level = book[price]
--   if not level then
--     return
--   end

--   local node = OrderNodes[orderId]
--   if not node then
--     return
--   end

--   if node.prev then
--     OrderNodes[node.prev].next = node.next
--   else
--     level.head = node.next
--   end

--   if node.next then
--     OrderNodes[node.next].prev = node.prev
--   else
--     level.tail = node.prev
--   end

--   level.count = level.count - 1
--   local order = Orders[orderId]
--   if order then
--     level.total_qty = tostring(bint(level.total_qty) - bint(order.remaining))
--   end
--   OrderNodes[orderId] = nil

--   if level.count <= 0 then
--     book[price] = nil
--     removePrice(side, price)
--   end
-- end
