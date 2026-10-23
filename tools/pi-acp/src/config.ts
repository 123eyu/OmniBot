import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { InMemoryCredentialStore } from "@earendil-works/pi-ai";
import { ModelRuntime } from "@earendil-works/pi-coding-agent";

export const VERSION = "0.1.0";
export const PI_VERSION = "1.4.0";
export const PROVIDER_ID = "omnibot";

export interface LaunchConfig {
  agentDir: string;
  sessionDir: string;
  modelId: string;
  apiKey: string;
  provider: Parameters<ModelRuntime["registerProvider"]>[1];
  skillPaths: string[];
}

// Pi configuration values support interpolation and !commands. ACP and host
// configuration already contain resolved values, so preserve them as literals.
export function piLiteral(value: string): string {
  const escaped = value.replaceAll("$", "$$$$");
  return escaped.startsWith("!") ? `$${escaped}` : escaped;
}

export function readLaunchConfig(env = process.env): LaunchConfig {
  const agentDir = resolve(env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "omnibot-acp"));
  const configPath = env.OMNIBOT_PI_MODELS_PATH || join(agentDir, "models.json");
  const document = JSON.parse(readFileSync(configPath, "utf8"));
  const provider = document.providers?.[PROVIDER_ID];
  const modelId = env.OMNIBOT_PI_MODEL?.trim();
  const apiKey = env.OMNIBOT_PI_API_KEY;
  if (!provider || !Array.isArray(provider.models) || !provider.models.length) {
    throw new Error("Pi requires the shared Provider model catalog.");
  }
  if (!modelId || !provider.models.some((model: { id?: string }) => model.id === modelId)) {
    throw new Error("Select a model from the shared Provider before starting Pi.");
  }
  if (!apiKey) throw new Error("Pi requires shared Provider credentials.");
  if (!["openai-completions", "openai-responses", "anthropic-messages"].includes(provider.api)) {
    throw new Error("Unsupported Pi Provider protocol.");
  }
  const endpoint = new URL(provider.baseUrl);
  if (!["http:", "https:"].includes(endpoint.protocol)) throw new Error("Invalid Provider URL.");
  // Snapshot configuration at process launch. Other conversations/processes may
  // subsequently write their own shared-Provider configuration to the file.
  const headers = JSON.parse(env.OMNIBOT_PI_HEADERS || "{}");
  if (Object.values(headers).some((value) => typeof value !== "string")) {
    throw new Error("Provider headers must contain string values.");
  }
  return {
    agentDir,
    sessionDir: join(agentDir, "sessions"),
    modelId,
    apiKey,
    provider: {
      ...provider,
      apiKey: undefined,
      headers: Object.fromEntries(Object.entries(headers).map(([name, value]) => [name, piLiteral(value as string)])),
    },
    skillPaths: (env.OMNIBOT_PI_SKILL_PATHS || "").split(":").filter(Boolean),
  };
}

export async function createModelRuntime(config: LaunchConfig): Promise<ModelRuntime> {
  const runtime = await ModelRuntime.create({
    credentials: new InMemoryCredentialStore(),
    modelsPath: null,
    allowModelNetwork: false,
  });
  runtime.registerProvider(PROVIDER_ID, {
    ...config.provider,
    // The SDK registration API, unlike models.json loading, expects the
    // complete price shape even when the host has no pricing metadata.
    models: config.provider.models?.map((model) => ({
      ...model, cost: model.cost ?? { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    })),
  });
  await runtime.setRuntimeApiKey(PROVIDER_ID, config.apiKey);
  if (!runtime.getModel(PROVIDER_ID, config.modelId)) {
    throw new Error(`The shared Provider does not expose model ${config.modelId}.`);
  }
  return runtime;
}
