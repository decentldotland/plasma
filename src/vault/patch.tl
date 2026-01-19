require "utils.types"
require "vault.types"

local mod = {}

function mod.emitVaultConfigurationPatch() 
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

function mod.emitLockedBalancesPatch()
  Send({
    device = "patch@1.0",
    ["locked-balances-patch"] = {
      balances = LockedBalances
    }
  })
end

function mod.emitAvailableBalancesPatch()
  Send({
    device = "patch@1.0",
    ["available-balances-patch"] = {
      balances = AvailableBalances
    }
  })
end

function mod.emitOrderEscrowPatch()
  Send({
    device = "patch@1.0",
    ["order-escrow-patch"] = {
      orders = OrderEscrow
    }
  })
end

return mod