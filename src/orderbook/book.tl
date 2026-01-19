require "utils.types"
require "orderbook.types"

local patch = require "orderbook.patch"
local helpers = require "orderbook.helpers"
local deps = require "utils.deps"
local utils_validation = require "utils.validation"
local bint = deps.bint

local mod = {}


local function getBook(side: Side): {Price: PriceLevel}
  helpers.requireValidSide(side)
  if side == "Bid" then
    return Bids
  end
  return Asks
end

local function getPriceList(side: Side): {number: Price}
  helpers.requireValidSide(side)
  if side == "Bid" then
    return BidPrices
  end
  return AskPrices
end

local function addPrice(side: Side, price: Price): nil
  utils_validation.requirePositive(price, "addPrice price")
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

  helpers.updateBestPrices()
end

local function removePrice(side: Side, price: Price): nil
  local prices = getPriceList(side)
  for i = 1, #prices do
    if prices[i] == price then
      table.remove(prices, i)
      break
    end
  end
  helpers.updateBestPrices()
end

local function decreaseLevelQty(side: Side, price: Price, qty: Qty): nil
  utils_validation.requirePositive(qty, "decreaseLevelQty qty")
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