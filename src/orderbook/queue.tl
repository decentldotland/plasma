require "utils.types"
require "orderbook.types"

local patch = require "orderbook.patch"
local helpers = require "orderbook.helpers"
local book_dep = require "orderbook.book" 
local deps = require "utils.deps"
local utils_validation = require "utils.validation"
local bint = deps.bint

local mod = {}


local function enqueueOrder(side: Side, price: Price, orderId: OrderId): nil
  local book = book_dep.getBook(side)
  local order = Orders[orderId]
  assert(order, "order not found")
  assert(order.price == price, "price mismatch")
  assert(order.side == side, "side mismatch")
  utils_validation.requirePositive(order.remaining, "enqueueOrder remaining")

  if not book[price] then
    book[price] = {
      price = price,
      head = nil,
      tail = nil,
      count = 0,
      total_qty = "0"
    }
    book_dep.addPrice(side, price)
  end

  assert(not OrderNodes[orderId], "order already enqueued")

  local level = book[price]
  local node: OrderNode = { id = orderId, prev = level.tail, next = nil }

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

local function dequeueOrder(side: Side, price: Price): OrderId | nil
  local book = book_dep.getBook(side)
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
    book_dep.removePrice(side, price)
  end

  return orderId
end

local function removeOrderFromLevel(side: Side, price: Price, orderId: OrderId): nil
  local book = book_dep.getBook(side)
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
    book_dep.removePrice(side, price)
  end
end

mod.enqueueOrder = enqueueOrder
mod.dequeueOrder = dequeueOrder
mod.removeOrderFromLevel = removeOrderFromLevel

return mod