const NODE_URL = "https://app-1.forward.computer";
const PROCESS_ID = "P-s1nKZ2jiHrno_EkUy05QEErfLgQcCFh8ltevAeLQs";

async function main() {
  try {
    const cronUrl = `${NODE_URL}/~cron@1.0/once?cron-path=${PROCESS_ID}~process@1.0/now`;
    const cronRes = await fetch(cronUrl, { method: "GET" });
    const cronBody = await cronRes.text();

    console.log("Hydration trigger status:", cronRes.status);
    console.log("Hydration trigger response:", cronBody);

    const nowUrl = `${NODE_URL}/${PROCESS_ID}~process@1.0/now?require-codec=application/json&accept-bundle=true`;
    const nowRes = await fetch(nowUrl, { method: "GET" });
    const nowBody = await nowRes.text();

    console.log("Now status:", nowRes.status);
    console.log("Now response:", nowBody);
  } catch (err) {
    console.error("Hydration failed.");
    console.error(err);
    process.exitCode = 1;
  }
}

main();
