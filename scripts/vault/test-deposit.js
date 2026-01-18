import { connect, createSigner } from "@permaweb/aoconnect";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WALLET_PATH = path.join(__dirname, "..", "..", "wallet.json");
const AO_URL = "https://push.forward.computer";
const SCHEDULER = "n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo";

const TOKEN_PROCESS = "TOKEN_PROCESS_ID_HERE";
const VAULT_PROCESS = "VAULT_PROCESS_ID_HERE";
const QUANTITY = "1000";

const wallet = JSON.parse(fs.readFileSync(WALLET_PATH, "utf-8"));
const signer = createSigner(wallet);

const ao = connect({
  MODE: "mainnet",
  URL: AO_URL,
  SCHEDULER,
  signer,
});

function getTagValue(tags, name) {
  if (!tags) return null;
  const found = tags.find((tag) => tag.name === name);
  return found ? found.value : null;
}

function extractAction(result, actionName) {
  const messages = result?.Messages || [];
  for (const msg of messages) {
    const action = getTagValue(msg.Tags, "Action") || msg.Action;
    if (action === actionName) {
      return msg;
    }
  }
  return null;
}

async function findActionInRecentResults(processId, actionName) {
  const res = await ao.results({ process: processId, limit: 5, sort: "DESC" });
  const edges = res?.edges || [];
  for (const edge of edges) {
    const node = edge.node || {};
    const match = extractAction(node, actionName);
    if (match) return match;
  }
  return null;
}

try {
  const messageId = await ao.message({
    process: TOKEN_PROCESS,
    signer,
    tags: [
      { name: "Action", value: "Transfer" },
      { name: "Recipient", value: VAULT_PROCESS },
      { name: "Quantity", value: QUANTITY },
    ],
  });

  const result = await ao.result({ process: TOKEN_PROCESS, message: messageId });
  console.log("Deposit transfer sent.", messageId);
  console.log("Token Result:", JSON.stringify(result, null, 2));

  const deposit = await findActionInRecentResults(VAULT_PROCESS, "Deposit-OK");
  if (deposit) {
    console.log("Vault Deposit-OK:", JSON.stringify(deposit, null, 2));
  }
} catch (err) {
  console.error("Deposit test failed.");
  console.error(err);
  if (err && err.cause) {
    console.error("Cause:", err.cause);
  }
  process.exitCode = 1;
}
