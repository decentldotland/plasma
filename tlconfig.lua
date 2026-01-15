return {
  include = { "src/" },
  build_dir = "build/",
  lua_version = "5.1",
  warning_unused = true,
  gen_compat = "off",
  globals = {
    Send = true,
    Handlers = true,
    ao = true,
    Owner = true,
  }
}
