require "utils.types"
require "orderbook.types"

local patch = require "orderbook.patch"

local mod = {}

local function requireSupportedToken(address: string): nil
    assert(address == TokenA or address == TokenB, "token not supported in this orderbook")
end

local function requireValidSide(side: Side): nil
  assert(side == "Bid" or side == "Ask", "invalid side")
end

local function updateBestPrices(): nil
  local newBestBid = BidPrices[1]
  local newBestAsk = AskPrices[1]
  if newBestBid == BestBid and newBestAsk == BestAsk then
    return
  end
  BestBid = newBestBid
  BestAsk = newBestAsk
  patch.emitBestPricesPatch()
end

mod.requireSupportedToken = requireSupportedToken
mod.requireValidSide = requireValidSide
mod.updateBestPrices = updateBestPrices

return mod