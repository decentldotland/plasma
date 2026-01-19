local mod = {}

local bint: function(number | string): any = require(".bint")(256)
local json: any = require("json")

mod.bint = bint
mod.json = json

return mod