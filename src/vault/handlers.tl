require "utils.types"
require "vault.types"

local deps = require "utils.deps"
local shared = require "utils.validation"
local helpers = require "vault.helpers"
local patch = require "vault.patch"

local bint = deps.bint
local json = deps.json

local mod = {}


local function configure(msg: Msg)
    assert(shared.isOwner(msg.From), "Unauthorized")
    Name =  shared.tagOrField(msg, "Name") or Name
    Identifier = shared.tagOrField(msg, "Identifier") or Identifier
    Variant = shared.tagOrField(msg, "Variant") or Variant
    patch.emitVaultConfigurationPatch()

    shared.respond(msg, {
      Action = "Configure-OK",
      Variant = Variant,
      Identifier = Identifier,
      Name = Name,
    })

end



local function add_token_support(msg: Msg)
    assert(shared.isOwner(msg.From), "Unauthorized")
    local token = shared.tagOrField(msg, "TokenAddress")
    shared.validateArweaveAddress(token)
    assert(not SupportedTokens[token], "token is already supported")
    local name = shared.tagOrField(msg, "TokenName")
    local decimals = shared.tagOrField(msg, "TokenDecimals")

    assert(name ~= nil and name ~= "", "token name cannot be nil")
    assert(decimals ~= nil and decimals ~= "" and tonumber(decimals) > 0, "decimals cannot be negative")

    SupportedTokens[token] = {
      address = token,
      name = name,
      decimals = tonumber(decimals),
      active = true
    }

    shared.addAuthority(token)
    patch.emitVaultConfigurationPatch()

    shared.respond(msg, {
      Action = "AddTokenSupport-OK",
      TokenAddress = token,
      TokenName = name,
      Active = true,
      TokenDecimals = tonumber(decimals),
    })
end


local function add_orderbook(msg: Msg)
    assert(shared.isOwner(msg.From), "unauthorized")
    local token_a = shared.tagOrField(msg, "TokenA")
    local token_b = shared.tagOrField(msg, "TokenB")
    local address = shared.tagOrField(msg, "OrderbookAddress")
    local fee_bps = shared.tagOrField(msg, "FeeBps")

    shared.validateArweaveAddress(token_a)
    shared.validateArweaveAddress(token_b)
    shared.validateArweaveAddress(address)
    helpers.requireActiveToken(token_a)
    helpers.requireActiveToken(token_b)
    assert(token_a ~= token_b, "token_a and token_b must differ")
    assert(not OrderBooks[address], "orderbook already supported")
    assert(fee_bps ~= nil and fee_bps ~= "" and tonumber(fee_bps) >= 0, "invalid fee_bps param")
    
    OrderBooks[address] = {
      tokens = {
        [token_a] = true,
        [token_b] = true
      },
      active = true,
      fee_bps = tonumber(fee_bps)
    }

    shared.addAuthority(address)
    patch.emitVaultConfigurationPatch()

    shared.respond(msg, {
      Action = "AddOrderbook-OK",
      TokenA = token_a,
      TokenB = token_b,
      OrderbookAddress = address,
      FeeBps = tonumber(fee_bps)
    })
end


local function configure_orderbook(msg: Msg)
    assert(shared.isOwner(msg.From), "Unauthorized")
    local orderbook_address = shared.tagOrField(msg, "OrderbookAddress")
    local fee_bps = shared.tagOrField(msg, "FeeBps") or nil
    local active = shared.tagOrField(msg, "Active") or nil 

    shared.validateArweaveAddress(orderbook_address)
    helpers.requireSupportedOrderBook(orderbook_address)

    local ob_before = OrderBooks[orderbook_address]

    if fee_bps ~= nil then
      assert(fee_bps ~= nil and fee_bps ~= "" and tonumber(fee_bps) >= 0, "invalid fee_bps param")
      OrderBooks[orderbook_address].fee_bps = tonumber(fee_bps)
    end

    if active ~= nil then
      local status_bool = string.tolower(active) == "true"
      -- for false to true actuve status, addAuthority
      if status_bool and not ob_before.active then
        shared.addAuthority(orderbook_address)
      end
      OrderBooks[orderbook_address].active = status_bool
      -- for true to false active status, remove authority
      if not status_bool then
        shared.removeAuthority(orderbook_address)
      end
    end

    patch.emitVaultConfigurationPatch()

    local ob_after = OrderBooks[orderbook_address]


    shared.respond(msg, {
      Action = "ConfigureOrderbook-OK",
      FeeBps = ob_after.fee_bps,
      Active = ob_after.active,
      OrderbookAddress = orderbook_address,
    })
end


local function configure_token(msg: Msg)

    assert(shared.isOwner(msg.From), "unauthorized")
    local token_address = shared.tagOrField(msg, "TokenAddress")
    local token_name = shared.tagOrField(msg, "TokenName")
    local token_decimals = shared.tagOrField(msg, "TokenDecimals")
    local token_active = shared.tagOrField(msg, "TokenActive")

    assert(token_address ~= nil and token_address ~= "", "TokenAddress required")
    shared.validateArweaveAddress(token_address)
    helpers.requireSupportedToken(token_address)

    local token_before = SupportedTokens[token_address]

    if token_name ~= nil and token_name ~= "" then
      SupportedTokens[token_address].name = token_name
    end

    if token_decimals ~= nil and tonumber(token_decimals) > 0 then
      SupportedTokens[token_address].decimals = tonumber(token_decimals)
    end

    if token_active == "true" or token_active == "false" then
      if token_active == "true" and not token_before.active then
        shared.addAuthority(token_address)
      end
      SupportedTokens[token_address].active = token_active == "true"
      if token_active == "false" then 
        shared.removeAuthority(token_address)
      end
    end

    patch.emitVaultConfigurationPatch()

    local token_after = SupportedTokens[token_address]

    shared.respond(msg, {
      Action = "ConfigureToken-OK",
      Name = token_after.name,
      Active = token_after.active,
      Decimals = token_after.decimals,
    })

end


-- deposit into the vault via Credit-Notice from token process
local function credit_notice(msg: Msg)
    local token = msg.From
    local sender = shared.tagOrField(msg, "Sender")
    local quantity = shared.tagOrField(msg, "Quantity")
    local recipient = shared.tagOrField(msg, "Recipient")

    helpers.requireActiveToken(token)
    shared.validateArweaveAddress(sender)
    shared.requirePositive(quantity, "Deposit quantity")
    if recipient ~= nil then
      assert(recipient == ao.id, "invalid deposit recipient")
    end

    helpers.addAvailableBalances(sender, token, quantity)
    patch.emitAvailableBalancesPatch()

    shared.respond(msg, {
      Action = "Deposit-OK",
      TokenAddress = token,
      Sender = sender,
      Quantity = quantity,
    })
  end

-- user withdraws from vault back to token process
local function withdraw(msg: Msg)
    local token = shared.tagOrField(msg, "TokenAddress")
    local quantity = shared.tagOrField(msg, "Quantity")
    local recipient = shared.tagOrField(msg, "Recipient") or msg.From

    shared.validateArweaveAddress(token)
    shared.validateArweaveAddress(recipient)
    helpers.requireSupportedToken(token)
    shared.requirePositive(quantity, "Withdraw quantity")

    helpers.subAvailableBalances(msg.From, token, quantity)
    helpers.addLockedBalances(msg.From, token, quantity)

    local withdraw_id = shared.getMsgId(msg)
    assert(withdraw_id ~= nil and withdraw_id ~= "", "withdraw_id unavailable")

    PendingWithdrawals[withdraw_id] = {
      user = msg.From,
      token = token,
      quantity = quantity,
      recipient = recipient,
      created = tostring(msg.Timestamp or "")
    }

    Send({
      Target = token,
      Action = "Transfer",
      Tags = {
        Recipient = recipient,
        Quantity = quantity,
        ["X-Withdraw-Id"] = withdraw_id,
        ["X-Withdraw-User"] = msg.From,
        ["X-Vault-Id"] = ao.id,
       }
    })

    patch.emitAvailableBalancesPatch()
    patch.emitLockedBalancesPatch()

    shared.respond(msg, {
      Action = "Withdraw-Pending",
      WithdrawId = withdraw_id,
      TokenAddress = token,
      Recipient = recipient,
      Quantity = quantity,
    })
end


-- finalize withdraw after token debit notice

local function debit_notice(msg: Msg)
    local withdraw_id = shared.tagOrField(msg, "X-Withdraw-Id")
    local system_id = shared.tagOrField(msg, "X-Vault-Id")
    if not withdraw_id or system_id ~= ao.id then
      return
    end

    local pending = PendingWithdrawals[withdraw_id]
    if not pending then
      return
    end

    assert(msg.From == pending.token, "invalid token for withdraw")

    helpers.subLockedBalances(pending.user, pending.token, pending.quantity)
    PendingWithdrawals[withdraw_id] = nil
    patch.emitLockedBalancesPatch()

    Send({
       Target = pending.user,
      Action = "Withdraw-OK",
      Tags = {
        WithdrawId = withdraw_id,
        TokenAddress = pending.token,
        Recipient = pending.recipient,
        Quantity = pending.quantity
      }
    })
end

-- lock/unlock ledger operations

local function lock(msg: Msg)
    local order_id = shared.tagOrField(msg, "OrderId")
    local user = shared.tagOrField(msg, "User")
    local token = shared.tagOrField(msg, "TokenAddress")
    local quantity = shared.tagOrField(msg, "Quantity")
    local side = shared.tagOrField(msg, "Side")

    assert(order_id and order_id ~= "", "OrderId required")
    shared.validateArweaveAddress(user)
    shared.validateArweaveAddress(token)
    shared.validateArweaveAddress(order_id)
    helpers.requireActiveOrderBook(msg.From)
    helpers.requireOrderbookTokenAuth(msg.From, token)
    shared.requirePositive(quantity, "Lock quantity")

    assert(not OrderEscrow[order_id], "order already escrowed")

    -- move available -> locked
    helpers.subAvailableBalances(user, token, quantity)
    helpers.addLockedBalances(user, token, quantity)

    OrderEscrow[order_id] = {
      user = user,
      token = token,
      amount = quantity,
      filled = "0",
      side = side or "",
      orderbook = msg.From
    }

    patch.emitAvailableBalancesPatch()
    patch.emitLockedBalancesPatch()
    patch.emitOrderEscrowPatch()

    shared.respond(msg, {
      Action = "Lock-OK",
      OrderId = order_id
    })
  end

local function unlock(msg: Msg)
    local order_id = shared.tagOrField(msg, "OrderId")

    assert(order_id and order_id ~= "", "OrderId required")

    local esc = OrderEscrow[order_id]
    assert(esc, "order not escrowed")
    assert(esc.orderbook == msg.From, "unauthorized orderbook")

    -- remaining = amount - filled
    local remaining = bint(esc.amount) - bint(esc.filled)
    assert(remaining >= bint(0), "invalid escrow remaining")

    if remaining > bint(0) then
      helpers.subLockedBalances(esc.user, esc.token, tostring(remaining))
      helpers.addAvailableBalances(esc.user, esc.token, tostring(remaining))
    end

    OrderEscrow[order_id] = nil

    patch.emitAvailableBalancesPatch()
    patch.emitLockedBalancesPatch()
    patch.emitOrderEscrowPatch()

    shared.respond(msg, {
      Action = "Unlock-OK",
      OrderId = order_id
    })
  end

local function settle(msg: Msg)
    local order_id = shared.tagOrField(msg, "OrderId")
    local recipient = shared.tagOrField(msg, "Recipient")
    local fill_qty = shared.tagOrField(msg, "FillQuantity")

    shared.validateArweaveAddress(recipient)
    shared.validateArweaveAddress(order_id)
    shared.requirePositive(fill_qty, "FillQuantity")

    local esc = OrderEscrow[order_id]
    assert(esc, "order not escrowed")
    helpers.ensureSenderIsOrderbook(esc.orderbook, msg.From)

    local remaining = bint(esc.amount) - bint(esc.filled)
    assert(bint(fill_qty) <= remaining, "fill exceeds escrow")

    -- move locked -> recipient available
    helpers.subLockedBalances(esc.user, esc.token, fill_qty)
    helpers.addAvailableBalances(recipient, esc.token, fill_qty)

    esc.filled = tostring(bint(esc.filled) + bint(fill_qty))

    -- if fully filled, clear escrow
    if bint(esc.filled) == bint(esc.amount) then
      OrderEscrow[order_id] = nil
    end

    patch.emitAvailableBalancesPatch()
    patch.emitLockedBalancesPatch()
    patch.emitOrderEscrowPatch()

    shared.respond(msg, {
      Action = "Settle-OK",
      OrderId = order_id,
      Filled = fill_qty
    })
  end

-- settle/cancel orderbook ops on balances

local function cancel(msg: Msg)
    local order_id = shared.tagOrField(msg, "OrderId")

    shared.validateArweaveAddress(order_id)

    local esc = OrderEscrow[order_id]
    assert(esc, "order not escrowed")
    helpers.ensureSenderIsOrderbook(esc.orderbook, msg.From)

    local remaining = bint(esc.amount) - bint(esc.filled)
    assert(remaining >= bint(0), "invalid escrow remaining")

    if remaining > bint(0) then
      helpers.subLockedBalances(esc.user, esc.token, tostring(remaining))
      helpers.addAvailableBalances(esc.user, esc.token, tostring(remaining))
    end

    OrderEscrow[order_id] = nil

    patch.emitAvailableBalancesPatch()
    patch.emitLockedBalancesPatch()
    patch.emitOrderEscrowPatch()

    shared.respond(msg, {
      Action = "Cancel-OK",
      OrderId = order_id
    })
  end

-- todo: implement error API

mod.configure = configure
mod.add_token_support = add_token_support
mod.add_orderbook = add_orderbook
mod.configure_orderbook = configure_orderbook
mod.configure_token = configure_token
mod.credit_notice = credit_notice
mod.withdraw = withdraw
mod.debit_notice = debit_notice
mod.lock = lock
mod.unlock = unlock
mod.settle = settle
mod.cancel = cancel

return mod