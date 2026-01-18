import { connect, createSigner } from "@permaweb/aoconnect";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WALLET_PATH = path.join(__dirname, "..", "..", "wallet.json");
const BLUEPRINT_PATH = "./build/vault.lua";
const PROCESS_NAME = "plasma-vault";
const AO_URL = "https://push.forward.computer";
const SCHEDULER = "n_XZJhUnmldNFo4dhajoPZWhBXuJk-OcQr5JQ49c4Zo";
const MODULE_ID = "ISShJH1ij-hPPt9St5UFFr_8Ys3Kj5cyg7zrMGt7H9s";
const SIGNING_FORMAT = "ANS-104";
const wallet = JSON.parse(fs.readFileSync(WALLET_PATH, "utf-8"));
const signer = createSigner(wallet);
const blueprint = fs.readFileSync(BLUEPRINT_PATH, "utf-8");

const ao = connect({
  MODE: "mainnet",
  URL: AO_URL,
  SCHEDULER,
  signer,
});

async function main() {
  try {
    const spawnResponse = await ao.request({
      path: "/push",
      method: "POST",
      "signing-format": "ans104",
      signingFormat: SIGNING_FORMAT,
      "accept-bundle": "true",
      "accept-codec": "httpsig@1.0",
      device: "process@1.0",
      "scheduler-device": "scheduler@1.0",
      "push-device": "push@1.0",
      "execution-device": "genesis-wasm@1.0",
      Authority: SCHEDULER,
      Scheduler: SCHEDULER,
      Module: MODULE_ID,
      Name: PROCESS_NAME,
      "Data-Protocol": "ao",
      Type: "Process",
      Variant: "ao.N.1",
      data: "1984",
    });

    const headers = spawnResponse?.headers || spawnResponse?.Headers || null;
    const processId = headers?.get ? headers.get("process") : headers?.process;
    if (!processId) {
      throw new Error("Spawn missing process id.");
    }

    const evalMessageId = await ao.message({
      process: processId,
      signer,
      tags: [{ name: "Action", value: "Eval" }],
      data: blueprint,
    });
    const evalResult = await ao.result({ process: processId, message: evalMessageId });
    console.log("Eval result:", JSON.stringify(evalResult, null, 2));

    console.log("Deployed vault process:", processId);
  } catch (err) {
    console.error("Vault deploy failed.");
    console.error(err);
    if (err && err.cause) {
      console.error("Cause:", err.cause);
    }
    process.exitCode = 1;
  }
}

main();
