import { connect, createSigner } from "@permaweb/aoconnect";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WALLET_PATH = path.join(__dirname, "..", "..", "wallet.json");
const AO_URL = "https://push.forward.computer";
const SCHEDULER = "n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo";

const VAULT_PROCESS = "lGyEdo-A-SteggedVtk2IBxbzoSJY8Dt4IxCwyODdvc";
// const TOKEN_PROCESS = "w5D3cwvC4Y9RCTy70BjyGFzTAjmUI0iOgdJbVyTeNvc";
const TOKEN_PROCESS = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
const TOKEN_NAME = "PLASMAAAAAAAA";
const TOKEN_DECIMALS = "12";

const wallet = JSON.parse(fs.readFileSync(WALLET_PATH, "utf-8"));
const signer = createSigner(wallet);

const ao = connect({
  MODE: "mainnet",
  URL: AO_URL,
  SCHEDULER,
  signer,
});

try {
  const messageId = await ao.message({
    process: VAULT_PROCESS,
    signer,
    tags: [
      { name: "Action", value: "AddTokenSupport" },
      { name: "TokenAddress", value: TOKEN_PROCESS },
      { name: "TokenName", value: TOKEN_NAME },
      { name: "TokenDecimals", value: TOKEN_DECIMALS },
    ],
  });

  const result = await ao.result({ process: VAULT_PROCESS, message: messageId });
  console.log("AddTokenSupport sent.", messageId);
  console.log("Result:", JSON.stringify(result, null, 2));
} catch (err) {
  console.error("AddTokenSupport failed.");
  console.error(err);
  if (err && err.cause) {
    console.error("Cause:", err.cause);
  }
  process.exitCode = 1;
}
