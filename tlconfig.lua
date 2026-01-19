return {
  source_dir = "src",
  include_dir = { "src", "src/typedefs" },
  include = {
    "**/*.tl",
  },
  build_dir = "build-lua",
  lua_version = "5.1",
  warning_unused = true,
  gen_compat = "off",
  globals = {
    Send = true,
    Handlers = true,
    ao = true,
    Owner = true,
  },
}
