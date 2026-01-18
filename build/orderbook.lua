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
