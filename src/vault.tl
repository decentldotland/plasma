local bint: function(number | string): any = require(".bint")(256)
local json: any = require("json")

global type Balance = any

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

global SupportedTokens: {string: TokenReq} = SupportedTokens or {}
global OrderBooks: {string: OrderBookReq} = OrderBooks or {}
-- User address -> Token address -> Balance
global Balances: {string: {string: Balance}} = Balances or {}
