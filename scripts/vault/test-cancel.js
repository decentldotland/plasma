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
const ORDER_ID = "ORDER_ID_HERE";

const wallet = JSON.parse(fs.readFileSync(WALLET_PATH, "utf-8"));
const signer = createSigner(wallet);

const ao = connect({
  MODE: "mainnet",
  URL: AO_URL,
  SCHEDULER,
  signer,
});

async function findActionInRecentResults(processId, actionName) {
  const res = await ao.results({ process: processId, limit: 5, sort: "DESC" });
  const edges = res?.edges || [];
  for (const edge of edges) {
    const node = edge.node || {};
    const messages = node?.Messages || [];
    for (const msg of messages) {
      const action = msg.Action || msg?.Tags?.find((tag) => tag.name === "Action")?.value;
      if (action === actionName) return msg;
    }
  }
  return null;
}

const evalData = [
  `Send({`,
  `  Target = "${VAULT_PROCESS}",`,
  `  Action = "Cancel",`,
  `  Tags = {`,
  `    OrderId = "${ORDER_ID}"`,
  `  }`,
  `})`,
].join("\n");

try {
  const messageId = await ao.message({
    process: ORDERBOOK_PROCESS,
    signer,
    tags: [{ name: "Action", value: "Eval" }],
    data: evalData,
  });

  const result = await ao.result({ process: ORDERBOOK_PROCESS, message: messageId });
  console.log("Cancel sent via orderbook.", messageId);
  console.log("Orderbook Result:", JSON.stringify(result, null, 2));

  const cancelOk = await findActionInRecentResults(VAULT_PROCESS, "Cancel-OK");
  if (cancelOk) {
    console.log("Vault Cancel-OK:", JSON.stringify(cancelOk, null, 2));
  }
} catch (err) {
  console.error("Cancel test failed.");
  console.error(err);
  if (err && err.cause) {
    console.error("Cause:", err.cause);
  }
  process.exitCode = 1;
}
