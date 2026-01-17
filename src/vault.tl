local bint: function(number | string): any = require(".bint")(256)
local json: any = require("json")

global type Balance = any
local type Payload = {string: any}
local type ReplyFn = function(Payload): nil

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

local record Tag
    name: string | nil
    Name: string | nil
    value: string | nil
    Value: string | nil
end

local record Msg
    From: string
    Id: string | nil
    Tags: {Tag} | {string: string} | nil
    TagArray: {Tag} | nil
    reply: ReplyFn | nil
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
global Send: function(Payload): nil

local function isOwner(sender: string): boolean
  return sender == Owner
end

local function addAuthority(id: string): nil
  local a = ao.authorities or {}
  for _, v in ipairs(a) do
    if v == id then return end
  end
  table.insert(a, id)
  ao.authorities = a
  if SyncState then
    SyncState(nil)
  end
end

local function removeAuthority(id: string): nil
    local a = ao.authorities or {}
    for i = #a, 1, -1 do
      if a[i] == id then
        table.remove(a, i)
      end
    end
    ao.authorities = a
    if SyncState then SyncState(nil) end
end

local function respond(msg: Msg, payload: Payload)
  if msg.reply then
    msg.reply(payload)
  else
    payload.Target = msg.From
    Send(payload)
  end
end

local function getMsgId(msg: Msg): string | nil
    return msg.Id
end

local function findTagValue(tags: {Tag} | nil, name: string): string | nil
  if not tags then
    return nil
  end
  local lower = string.lower(name)
  if tags[1] then
    for _, tag in ipairs(tags) do
      local tagName = tag.name or tag.Name
      if tagName and string.lower(tagName) == lower then
        return tag.value or tag.Value
      end
    end
  end
  if tags[name] ~= nil then
    return tags[name]
  end
  for k, v in pairs(tags) do
    if type(k) == "string" and string.lower(k) == lower then
      return v
    end
  end
  return nil
end

local function tagOrField(msg: Msg, name: string): string | nil
  local value = findTagValue(msg.Tags, name) or findTagValue(msg.TagArray, name)
  if value ~= nil then
    return value
  end
  return msg[name]
end

local function requireSupportedToken(address: string)
    assert(SupportedTokens[address], "token not supported")
end

local function requireActiveToken(address: string)
    assert(SupportedTokens[address] and SupportedTokens[address].active, "token not supported")
end

local function requireSupportedOrderBook(address: string)
    assert(OrderBooks[address], "orderbook not supported")
end

local function requireActiveOrderBook(address: string)
    assert(OrderBooks[address] and OrderBooks[address].active, "orderbook not supported or not active")
end

local function validateArweaveAddress(address: string)
  assert(address ~= nil and address ~= "", "token address must be valid ao process id")
end

local function requireOrderbookTokenAuth(orderbook_address: string, token_address: string)
  requireActiveToken(token_address)
  local ob = OrderBooks[orderbook_address]
  assert(ob and ob.tokens and ob.active and ob.tokens[token_address], "orderbook is not authorized to handle this token")
end

local function ensureAccount(balanceMap: {string: {string: Balance}}, account: string)
  if not balanceMap[account] then
    balanceMap[account] = {}
  end
end

local function ensureSenderIsOrderbook(orderbook: string, sender: string): nil
  assert(orderbook == sender, "unauthorized orderbook")
end

-- ledger utils
local function requirePositive(quantity: string, name: string)
  assert(quantity, name .. " is required")
  assert(bint.__lt(0, bint(quantity)), name .. " must be greater than 0")
end

local function addLockedBalances(account: string, token: string, quantity: string)
  ensureAccount(LockedBalances, account)
  requirePositive(quantity, "addLockedBalances")
  LockedBalances[account][token] = tostring(bint(LockedBalances[account][token] or "0") + bint(quantity))
end

local function subLockedBalances(account: string, token: string, quantity: string)
  ensureAccount(LockedBalances, account)
  requirePositive(quantity, "subLockedBalances")
  local nextValue = bint(LockedBalances[account][token] or "0") - bint(quantity)
  assert(nextValue >= bint(0), "locked balance underflow")
  LockedBalances[account][token] = tostring(nextValue)
end

local function addAvailableBalances(account: string, token: string, quantity: string)
  ensureAccount(AvailableBalances, account)
  requirePositive(quantity, "addAvailableBalances")
  AvailableBalances[account][token] = tostring(bint(AvailableBalances[account][token] or "0") + bint(quantity))
end

local function subAvailableBalances(account: string, token: string, quantity: string)
  ensureAccount(AvailableBalances, account)
  requirePositive(quantity, "subAvailableBalances")
  local nextValue = bint(AvailableBalances[account][token] or "0") - bint(quantity)
  assert(nextValue >= bint(0), "available balance underflow")
  AvailableBalances[account][token] = tostring(nextValue)
end


local function emitVaultConfigurationPatch() 
    Send({
        device = "patch@1.0",
        ["vault-configuration"] = {
            name = Name,
            variant = Variant,
            identifier = Identifier,
            supportedTokens = SupportedTokens,
            orderBooks = OrderBooks
        }
    })
end

-- full emission, no deltas

local function emitLockedBalancesPatch()
  Send({
    device = "patch@1.0",
    ["locked-balances-patch"] = {
      balances = LockedBalances
    }
  })
end

local function emitAvailableBalancesPatch()
  Send({
    device = "patch@1.0",
    ["available-balances-patch"] = {
      balances = AvailableBalances
    }
  })
end

local function emitOrderEscrowPatch()
  Send({
    device = "patch@1.0",
    ["order-escrow-patch"] = {
      orders = OrderEscrow
    }
  })
end

Handlers.add("vault.configure", 
  Handlers.utils.hasMatchingTag("Action", "Configure"),
  function(msg: Msg)
    assert(isOwner(msg.From), "Unauthorized")
    Name =  tagOrField(msg, "Name") or Name
    Identifier = tagOrField(msg, "Identifier") or Identifier
    Variant = tagOrField(msg, "Variant") or Variant
    emitVaultConfigurationPatch()

    respond(msg, {
      Action = "Configure-OK",
      Variant = Variant,
      Identifier = Identifier,
      Name = Name,
    })

  end
)

Handlers.add("vault.add_token_support",
  Handlers.utils.hasMatchingTag("Action", "AddTokenSupport"),
  function(msg: Msg)
    assert(isOwner(msg.From), "Unauthorized")
    local token = tagOrField(msg, "TokenAddress")
    validateArweaveAddress(token)
    assert(not SupportedTokens[token], "token is already supported")
    local name = tagOrField(msg, "TokenName")
    local decimals = tagOrField(msg, "TokenDecimals")

    assert(name ~= nil and name ~= "", "token name cannot be nil")
    assert(decimals ~= nil and decimals ~= "" and tonumber(decimals) > 0, "decimals cannot be negative")

    SupportedTokens[token] = {
      address = token,
      name = name,
      decimals = tonumber(decimals),
      active = true
    }

    addAuthority(token)
    emitVaultConfigurationPatch()

    respond(msg, {
      Action = "AddTokenSupport-OK",
      TokenAddress = token,
      TokenName = name,
      Active = true,
      TokenDecimals = tonumber(decimals),
    })
  end
  )

Handlers.add("vault.add_orderbook", Handlers.utils.hasMatchingTag("Action", "AddOrderbook"),
  function(msg: Msg)
    assert(isOwner(msg.From), "unauthorized")
    local token_a = tagOrField(msg, "TokenA")
    local token_b = tagOrField(msg, "TokenB")
    local address = tagOrField(msg, "OrderbookAddress")
    local fee_bps = tagOrField(msg, "FeeBps")

    validateArweaveAddress(token_a)
    validateArweaveAddress(token_b)
    validateArweaveAddress(address)
    requireActiveToken(token_a)
    requireActiveToken(token_b)
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

    addAuthority(address)
    emitVaultConfigurationPatch()

    respond(msg, {
      Action = "AddOrderbook-OK",
      TokenA = token_a,
      TokenB = token_b,
      OrderbookAddress = address,
      FeeBps = tonumber(fee_bps)
    })
  end
  )
Handlers.add("vault.configure_orderbook", 
  Handlers.utils.hasMatchingTag("Action", "ConfigureOrderbook"),
  function(msg: Msg)

    assert(isOwner(msg.From), "Unauthorized")
    local orderbook_address = tagOrField(msg, "OrderbookAddress")
    local fee_bps = tagOrField(msg, "FeeBps") or nil
    local active = tagOrField(msg, "Active") or nil 

    validateArweaveAddress(orderbook_address)
    requireSupportedOrderBook(orderbook_address)

    local ob_before = OrderBooks[orderbook_address]

    if fee_bps ~= nil then
      assert(fee_bps ~= nil and fee_bps ~= "" and tonumber(fee_bps) >= 0, "invalid fee_bps param")
      OrderBooks[orderbook_address].fee_bps = tonumber(fee_bps)
    end

    if active ~= nil then
      local status_bool = string.tolower(active) == "true"
      -- for false to true actuve status, addAuthority
      if status_bool and not ob_before.active then
        addAuthority(orderbook_address)
      end
      OrderBooks[orderbook_address].active = status_bool
      -- for true to false active status, remove authority
      if not status_bool then
        removeAuthority(orderbook_address)
      end
    end

    emitVaultConfigurationPatch()

    local ob_after = OrderBooks[orderbook_address]


    respond(msg, {
      Action = "ConfigureOrderbook-OK",
      FeeBps = ob_after.fee_bps,
      Active = ob_after.active,
      OrderbookAddress = orderbook_address,
    })
  end
  )

Handlers.add("vault.configure_token",
  Handlers.utils.hasMatchingTag("Action", "ConfigureToken"),
  function(msg: Msg)

    assert(isOwner(msg.From), "unauthorized")
    local token_address = tagOrField(msg, "TokenAddress")
    local token_name = tagOrField(msg, "TokenName")
    local token_decimals = tagOrField(msg, "TokenDecimals")
    local token_active = tagOrField(msg, "TokenActive")

    assert(token_address ~= nil and token_address ~= "", "TokenAddress required")
    validateArweaveAddress(token_address)
    requireSupportedToken(token_address)

    local token_before = SupportedTokens[token_address]

    if token_name ~= nil and token_name ~= "" then
      SupportedTokens[token_address].name = token_name
    end

    if token_decimals ~= nil and tonumber(token_decimals) > 0 then
      SupportedTokens[token_address].decimals = tonumber(token_decimals)
    end

    if token_active == "true" or token_active == "false" then
      if token_active == "true" and not token_before.active then
        addAuthority(token_address)
      end
      SupportedTokens[token_address].active = token_active == "true"
      if token_active == "false" then 
        removeAuthority(token_address)
      end
    end

    emitVaultConfigurationPatch()

    local token_after = SupportedTokens[token_address]

    respond(msg, {
      Action = "ConfigureToken-OK",
      Name = token_after.name,
      Active = token_after.active,
      Decimals = token_after.decimals,
    })

  end
  
  )

-- deposit into the vault via Credit-Notice from token process
Handlers.add("vault.credit_notice",
  Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
  function(msg: Msg)
    local token = msg.From
    local sender = tagOrField(msg, "Sender")
    local quantity = tagOrField(msg, "Quantity")
    local recipient = tagOrField(msg, "Recipient")

    requireActiveToken(token)
    validateArweaveAddress(sender)
    requirePositive(quantity, "Deposit quantity")
    if recipient ~= nil then
      assert(recipient == ao.id, "invalid deposit recipient")
    end

    addAvailableBalances(sender, token, quantity)
    emitAvailableBalancesPatch()

    respond(msg, {
      Action = "Deposit-OK",
      TokenAddress = token,
      Sender = sender,
      Quantity = quantity,
    })
  end
  )

-- user withdraws from vault back to token process
Handlers.add("vault.withdraw",
  Handlers.utils.hasMatchingTag("Action", "Withdraw"),
  function(msg: Msg)
    local token = tagOrField(msg, "TokenAddress")
    local quantity = tagOrField(msg, "Quantity")
    local recipient = tagOrField(msg, "Recipient") or msg.From

    validateArweaveAddress(token)
    validateArweaveAddress(recipient)
    requireSupportedToken(token)
    requirePositive(quantity, "Withdraw quantity")

    subAvailableBalances(msg.From, token, quantity)
    addLockedBalances(msg.From, token, quantity)

    local withdraw_id = getMsgId(msg)
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

    emitAvailableBalancesPatch()
    emitLockedBalancesPatch()

    respond(msg, {
      Action = "Withdraw-Pending",
      WithdrawId = withdraw_id,
      TokenAddress = token,
      Recipient = recipient,
      Quantity = quantity,
    })
  end
)


-- finalize withdraw after token debit notice
Handlers.add("vault.debit_notice",
  Handlers.utils.hasMatchingTag("Action", "Debit-Notice"),
  function(msg: Msg)
    local withdraw_id = tagOrField(msg, "X-Withdraw-Id")
    local system_id = tagOrField(msg, "X-Vault-Id")
    if not withdraw_id or system_id ~= ao.id then
      return
    end

    local pending = PendingWithdrawals[withdraw_id]
    if not pending then
      return
    end

    assert(msg.From == pending.token, "invalid token for withdraw")

    subLockedBalances(pending.user, pending.token, pending.quantity)
    PendingWithdrawals[withdraw_id] = nil
    emitLockedBalancesPatch()

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
)

-- lock/unlock ledger operations

Handlers.add("vault.lock",
  Handlers.utils.hasMatchingTag("Action", "Lock"),
  function(msg: Msg)
    local order_id = tagOrField(msg, "OrderId")
    local user = tagOrField(msg, "User")
    local token = tagOrField(msg, "TokenAddress")
    local quantity = tagOrField(msg, "Quantity")
    local side = tagOrField(msg, "Side")

    assert(order_id and order_id ~= "", "OrderId required")
    validateArweaveAddress(user)
    validateArweaveAddress(token)
    validateArweaveAddress(order_id)
    requireActiveOrderBook(msg.From)
    requireOrderbookTokenAuth(msg.From, token)
    requirePositive(quantity, "Lock quantity")

    assert(not OrderEscrow[order_id], "order already escrowed")

    -- move available -> locked
    subAvailableBalances(user, token, quantity)
    addLockedBalances(user, token, quantity)

    OrderEscrow[order_id] = {
      user = user,
      token = token,
      amount = quantity,
      filled = "0",
      side = side or "",
      orderbook = msg.From
    }

    emitAvailableBalancesPatch()
    emitLockedBalancesPatch()
    emitOrderEscrowPatch()

    respond(msg, {
      Action = "Lock-OK",
      OrderId = order_id
    })
  end
)

Handlers.add("vault.unlock",
  Handlers.utils.hasMatchingTag("Action", "Unlock"),
  function(msg: Msg)
    local order_id = tagOrField(msg, "OrderId")

    assert(order_id and order_id ~= "", "OrderId required")

    local esc = OrderEscrow[order_id]
    assert(esc, "order not escrowed")
    assert(esc.orderbook == msg.From, "unauthorized orderbook")

    -- remaining = amount - filled
    local remaining = bint(esc.amount) - bint(esc.filled)
    assert(remaining >= bint(0), "invalid escrow remaining")

    if remaining > bint(0) then
      subLockedBalances(esc.user, esc.token, tostring(remaining))
      addAvailableBalances(esc.user, esc.token, tostring(remaining))
    end

    OrderEscrow[order_id] = nil

    emitAvailableBalancesPatch()
    emitLockedBalancesPatch()
    emitOrderEscrowPatch()

    respond(msg, {
      Action = "Unlock-OK",
      OrderId = order_id
    })
  end
)

Handlers.add("vault.settle",
  Handlers.utils.hasMatchingTag("Action", "Settle"),
  function(msg: Msg)
    local order_id = tagOrField(msg, "OrderId")
    local recipient = tagOrField(msg, "Recipient")
    local fill_qty = tagOrField(msg, "FillQuantity")

    validateArweaveAddress(recipient)
    validateArweaveAddress(order_id)
    requirePositive(fill_qty, "FillQuantity")

    local esc = OrderEscrow[order_id]
    assert(esc, "order not escrowed")
    ensureSenderIsOrderbook(esc.orderbook, msg.From)

    local remaining = bint(esc.amount) - bint(esc.filled)
    assert(bint(fill_qty) <= remaining, "fill exceeds escrow")

    -- move locked -> recipient available
    subLockedBalances(esc.user, esc.token, fill_qty)
    addAvailableBalances(recipient, esc.token, fill_qty)

    esc.filled = tostring(bint(esc.filled) + bint(fill_qty))

    -- if fully filled, clear escrow
    if bint(esc.filled) == bint(esc.amount) then
      OrderEscrow[order_id] = nil
    end

    emitAvailableBalancesPatch()
    emitLockedBalancesPatch()
    emitOrderEscrowPatch()

    respond(msg, {
      Action = "Settle-OK",
      OrderId = order_id,
      Filled = fill_qty
    })
  end
)

-- settle/cancel orderbook ops on balances

Handlers.add("vault.cancel",
  Handlers.utils.hasMatchingTag("Action", "Cancel"),
  function(msg: Msg)
    local order_id = tagOrField(msg, "OrderId")

    validateArweaveAddress(order_id)

    local esc = OrderEscrow[order_id]
    assert(esc, "order not escrowed")
    ensureSenderIsOrderbook(esc.orderbook, msg.From)

    local remaining = bint(esc.amount) - bint(esc.filled)
    assert(remaining >= bint(0), "invalid escrow remaining")

    if remaining > bint(0) then
      subLockedBalances(esc.user, esc.token, tostring(remaining))
      addAvailableBalances(esc.user, esc.token, tostring(remaining))
    end

    OrderEscrow[order_id] = nil

    emitAvailableBalancesPatch()
    emitLockedBalancesPatch()
    emitOrderEscrowPatch()

    respond(msg, {
      Action = "Cancel-OK",
      OrderId = order_id
    })
  end
)
