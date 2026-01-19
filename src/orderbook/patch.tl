require "utils.types"
require "orderbook.types"

local mod = {}

local function emitBestPricesPatch(): nil
    Send({
        device = "patch@1.0",
        ["best-prices-patch"] = {
            BestBid = BestBid,
            BestAsk = BestAsk
        }
    })
end

mod.emitBestPricesPatch = emitBestPricesPatch

return mod