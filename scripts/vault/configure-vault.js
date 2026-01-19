import { connect, createSigner } from "@permaweb/aoconnect";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WALLET_PATH = path.join(__dirname, "..", "..", "wallet.json");
const AO_URL = "https://push.forward.computer";
const SCHEDULER = "n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo";

const VAULT_PROCESS = "P-s1nKZ2jiHrno_EkUy05QEErfLgQcCFh8ltevAeLQs";
const VAULT_NAME = "plasma-vault";
const VAULT_IDENTIFIER = "plasma-vault-1";
const VAULT_VARIANT = "0.1.0";

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
      { name: "Action", value: "Configure" },
      { name: "Name", value: VAULT_NAME },
      { name: "Identifier", value: VAULT_IDENTIFIER },
      { name: "Variant", value: VAULT_VARIANT },
    ],
  });

  const result = await ao.result({ process: VAULT_PROCESS, message: messageId });
  console.log("Configure sent.", messageId);
  console.log("Result:", JSON.stringify(result, null, 2));
} catch (err) {
  console.error("Configure failed.");
  console.error(err);
  if (err && err.cause) {
    console.error("Cause:", err.cause);
  }
  process.exitCode = 1;
}
