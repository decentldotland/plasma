require "utils.types"
require "vault.types"

local handlers = require "vault.handlers"

Handlers.add(
  "vault.configure",
  Handlers.utils.hasMatchingTag("Action", "Configure"),
  handlers.configure
)

Handlers.add(
  "vault.add_token_support",
  Handlers.utils.hasMatchingTag("Action", "AddTokenSupport"),
  handlers.add_token_support
)

Handlers.add(
  "vault.add_orderbook",
  Handlers.utils.hasMatchingTag("Action", "AddOrderbook"),
  handlers.add_orderbook
)

Handlers.add(
  "vault.configure_orderbook",
  Handlers.utils.hasMatchingTag("Action", "ConfigureOrderbook"),
  handlers.configure_orderbook
)

Handlers.add(
  "vault.configure_token",
  Handlers.utils.hasMatchingTag("Action", "ConfigureToken"),
  handlers.configure_token
)

Handlers.add(
  "vault.credit_notice",
  Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
  handlers.credit_notice
)

Handlers.add(
  "vault.withdraw",
  Handlers.utils.hasMatchingTag("Action", "Withdraw"),
  handlers.withdraw
)

Handlers.add(
  "vault.debit_notice",
  Handlers.utils.hasMatchingTag("Action", "Debit-Notice"),
  handlers.debit_notice
)

Handlers.add(
  "vault.lock",
  Handlers.utils.hasMatchingTag("Action", "Lock"),
  handlers.lock
)

Handlers.add(
  "vault.unlock",
  Handlers.utils.hasMatchingTag("Action", "Unlock"),
  handlers.unlock
)

Handlers.add(
  "vault.settle",
  Handlers.utils.hasMatchingTag("Action", "Settle"),
  handlers.settle
)

Handlers.add(
  "vault.cancel",
  Handlers.utils.hasMatchingTag("Action", "Cancel"),
  handlers.cancel
)
