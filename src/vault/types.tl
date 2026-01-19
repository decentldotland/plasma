require "utils.types"

global type Balance = any
global Variant: string = "0.1.0"
global Name: string | nil = Name or nil
global Identifier: string | nil = Identifier or nil 

global record TokenReq
    address: string
    decimals: number
    name: string
    active: boolean
end

global record OrderBookReq
  tokens: {string: boolean}
  active: boolean
  fee_bps: number
end

global record OrderEscrowReq
  user: string
  token: string
  amount: string
  filled: string
  side: string
  orderbook: string
end

global record PendingWithdrawReq
  user: string
  token: string
  quantity: string
  recipient: string
  created: string
end

global SupportedTokens: {string: TokenReq} = SupportedTokens or {}
-- orderbook address -> tokens = {token_a] = true, [token_b] = true}
global OrderBooks: {string: OrderBookReq} = OrderBooks or {}
-- user address -> token address -> balance
global AvailableBalances: {string: {string: Balance}} = AvailableBalances or {}
global LockedBalances: {string: {string: Balance}} = LockedBalances or {}
-- order_id -> OrderEscrowReq
global OrderEscrow: {string: OrderEscrowReq} = OrderEscrow or {}
-- withdraw_id -> PendingWithdrawReq
global PendingWithdrawals: {string: PendingWithdrawReq} = PendingWithdrawals or {}
