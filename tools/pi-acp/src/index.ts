#!/usr/bin/env node
import { Console } from "node:console";
import { readFileSync } from "node:fs";
import { Readable, Writable } from "node:stream";
import { ndJsonStream } from "@agentclientprotocol/sdk/unstable";
import { PI_VERSION, readLaunchConfig, VERSION } from "./config.js";
import { createPiAgent } from "./server.js";

if (process.argv.includes("--version") || process.argv.includes("--health")) {
  // Importing the official SDK above is part of the structural health check.
  const [major, minor] = process.versions.node.split(".").map(Number);
  if (major < 22 || (major === 22 && minor < 19)) throw new Error("Pi requires Node.js >= 22.19.0.");
  const installed = JSON.parse(readFileSync(new URL("../node_modules/@earendil-works/pi-coding-agent/package.json", import.meta.url), "utf8"));
  if (installed.version !== PI_VERSION) throw new Error(`Pi SDK version mismatch: expected ${PI_VERSION}.`);
  process.stdout.write(`omnibot-pi-acp ${VERSION} (Pi ${PI_VERSION})\n`);
} else {
  // Only ACP records may use stdout, including during Pi extension startup.
  globalThis.console = new Console(process.stderr, process.stderr);
  const runtime = createPiAgent(readLaunchConfig());
  const connection = runtime.app.connect(ndJsonStream(
    Writable.toWeb(process.stdout), Readable.toWeb(process.stdin),
  ));
  let shutdown: Promise<void> | undefined;
  const stop = () => shutdown ??= runtime.close().finally(() => connection.close());
  process.once("SIGINT", () => { void stop(); });
  process.once("SIGTERM", () => { void stop(); });
  await connection.closed;
  await stop();
}
