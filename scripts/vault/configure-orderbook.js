import { connect, createSigner } from "@permaweb/aoconnect";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WALLET_PATH = path.join(__dirname, "..", "..", "wallet.json");
const AO_URL = "https://push.forward.computer";
const SCHEDULER = "n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo";

const VAULT_PROCESS = "VAULT_PROCESS_ID_HERE";
const ORDERBOOK_PROCESS = "ORDERBOOK_PROCESS_ID_HERE";
const FEE_BPS = "5";
const ORDERBOOK_ACTIVE = "true";

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
      { name: "Action", value: "ConfigureOrderbook" },
      { name: "OrderbookAddress", value: ORDERBOOK_PROCESS },
      { name: "FeeBps", value: FEE_BPS },
      { name: "Active", value: ORDERBOOK_ACTIVE },
    ],
  });

  const result = await ao.result({ process: VAULT_PROCESS, message: messageId });
  console.log("ConfigureOrderbook sent.", messageId);
  console.log("Result:", JSON.stringify(result, null, 2));
} catch (err) {
  console.error("ConfigureOrderbook failed.");
  console.error(err);
  if (err && err.cause) {
    console.error("Cause:", err.cause);
  }
  process.exitCode = 1;
}
