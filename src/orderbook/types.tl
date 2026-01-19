global type OrderId = string
-- Side: "Bid" | "Ask"
global type Side = string
-- OrderStatus: "New" | "Partial" | "Filled" | "Cancelled"
global type OrderStatus = string
global type Price = string
global type Qty = string

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