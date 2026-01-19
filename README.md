## About
A modular CLOB on AO written in Teal and compiled to Lua. MVP goal: a fully functional limit/market order CLOB with cross fills and a continuous price-time priority matching engine.

## Build processes

```bash
make build # all processes

## scopped

make build-vault
make build-orderbook
```

## Deploy processes

### vault

```bash
make deploy vault
```

### orderbook

```bash
make deploy orderbook
```

## License
Plasma is licensed under the [BSL 1.1](./LICENSE) license
