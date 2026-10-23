import {
  methods, RequestError,
  type AgentContext, type ContentBlock, type McpServer, type PromptResponse,
  type RequestPermissionRequest, type RequestPermissionResponse,
  type SessionConfigOption, type SessionModeState, type SessionNotification,
} from "@agentclientprotocol/sdk/unstable";
import type { AssistantMessage } from "@earendil-works/pi-ai";
import {
  createAgentSession, createMcpExtension, DefaultResourceLoader, SessionManager, SettingsManager,
  type AgentSession, type AgentSessionEvent, type ExtensionFactory, type ModelRuntime, type ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { type LaunchConfig, PROVIDER_ID } from "./config.js";
import { promptContent, toolDescription } from "./content.js";
import { sessionMcpConfig } from "./mcp.js";
import { PiProjection } from "./projection.js";

interface PromptOperation {
  abort: AbortController;
  completion?: Promise<PromptResponse>;
  lastAssistant?: AssistantMessage;
  settledAborted: boolean;
}

export class PiAcpSession {
  private session!: AgentSession;
  private projection!: PiProjection;
  private operation?: PromptOperation;
  private updates: Promise<void> = Promise.resolve();
  private deliveryError?: unknown;
  private disposed = false;
  private mutation?: ReturnType<typeof Promise.withResolvers<void>>;
  private closing?: Promise<void>;
  private mode = "full-access";
  private unsubscribe?: () => void;
  readonly createdAt = new Date().toISOString();

  private constructor(
    readonly manager: SessionManager,
    private config: LaunchConfig,
    private models: ModelRuntime,
    private client: AgentContext,
  ) {}

  static async create(manager: SessionManager, config: LaunchConfig, models: ModelRuntime, client: AgentContext, servers: McpServer[]): Promise<PiAcpSession> {
    const owned = new PiAcpSession(manager, config, models, client);
    const mcpConfig = sessionMcpConfig(servers, manager.getCwd());
    const settings = SettingsManager.inMemory({
      retry: { enabled: false, provider: { maxRetries: 0 } },
      cacheWarming: "off",
    });
    // Credentials, tools and MCP definitions are supplied by this host. Skills
    // and context files still use Pi's standard discovery. Third-party executable
    // extensions are outside the first release's supported surface.
    const resources = new DefaultResourceLoader({
      cwd: manager.getCwd(), agentDir: config.agentDir, settingsManager: settings,
      noExtensions: true,
      additionalSkillPaths: config.skillPaths,
      extensionFactories: [owned.permissions(), createMcpExtension({ loadConfig: () => mcpConfig })],
    });
    await resources.reload();
    const storedModel = manager.buildSessionContext().model;
    const modelId = storedModel?.modelId || config.modelId;
    const model = models.getModel(PROVIDER_ID, modelId);
    if (!model) throw RequestError.invalidParams(undefined, `Model ${modelId} is unavailable in the shared Provider.`);
    const result = await createAgentSession({
      cwd: manager.getCwd(), agentDir: config.agentDir, sessionManager: manager,
      settingsManager: settings, resourceLoader: resources, modelRuntime: models, model,
      sessionStartEvent: { type: "session_start", reason: storedModel ? "resume" : "startup" },
    });
    owned.session = result.session;
    owned.projection = new PiProjection(manager, manager.getCwd(), (update) => owned.publish(update));
    owned.unsubscribe = owned.session.subscribe((event) => owned.onEvent(event));
    try {
      await owned.session.bindExtensions({
        onError: (error) => process.stderr.write(`Pi extension ${error.event}: ${error.error}\n`),
      });
      return owned;
    } catch (error) {
      await owned.close();
      throw error;
    }
  }

  get id(): string { return this.manager.getSessionId(); }
  get cwd(): string { return this.manager.getCwd(); }
  get busy(): boolean { return this.operation !== undefined || this.mutation !== undefined; }

  modes(): SessionModeState {
    return {
      currentModeId: this.mode,
      availableModes: [
        { id: "full-access", name: "Full access", description: "Use the host's unrestricted execution policy." },
        { id: "on-request", name: "Ask before tools", description: "Request host permission before executing tools." },
      ],
    };
  }

  configOptions(): SessionConfigOption[] {
    const modelIds = this.config.provider.models?.map((model) => model.id) || [this.config.modelId];
    return [
      { id: "model", name: "Model", category: "model", type: "select",
        currentValue: this.session.model!.id,
        options: modelIds.map((id) => ({ value: id, name: this.models.getModel(PROVIDER_ID, id)?.name || id })),
      },
      { id: "thought_level", name: "Thinking", category: "thought_level", type: "select",
        currentValue: this.session.thinkingLevel,
        options: this.session.getAvailableThinkingLevels().map((value) => ({ value, name: value })),
      },
    ];
  }

  async setConfig(id: string, value: string | boolean): Promise<SessionConfigOption[]> {
    return this.withIdleSession(async () => {
      if (typeof value !== "string") throw RequestError.invalidParams();
      if (id === "model") {
        const model = this.models.getModel(PROVIDER_ID, value);
        if (!model || !this.config.provider.models?.some((candidate) => candidate.id === value)) {
          throw RequestError.invalidParams(undefined, "Select a model from the shared Provider.");
        }
        await this.session.setModel(model);
      } else if (id === "thought_level") {
        const level = this.session.getAvailableThinkingLevels().find((level) => level === value);
        if (!level) throw RequestError.invalidParams(undefined, "Unsupported thinking level.");
        this.session.setThinkingLevel(level);
      } else throw RequestError.invalidParams(undefined, `Unknown config option: ${id}`);
      const configOptions = this.configOptions();
      this.publish({ sessionUpdate: "config_option_update", configOptions });
      this.publishUsage();
      await this.drain();
      return configOptions;
    });
  }

  async setMode(mode: string): Promise<void> {
    await this.withIdleSession(async () => {
      if (!this.modes().availableModes.some((candidate) => candidate.id === mode)) throw RequestError.invalidParams();
      this.mode = mode;
      this.publish({ sessionUpdate: "current_mode_update", currentModeId: mode });
      await this.drain();
    });
  }

  async replay(): Promise<void> {
    await this.withIdleSession(async () => {
      this.projection.replay();
      this.publishUsage();
      await this.drain();
    });
  }

  prompt(blocks: ContentBlock[], signal: AbortSignal): Promise<PromptResponse> {
    this.requireIdle();
    const input = promptContent(blocks);
    if (signal.aborted) return Promise.reject(RequestError.requestCancelled());
    const operation: PromptOperation = { abort: new AbortController(), settledAborted: false };
    this.operation = operation;
    operation.completion = this.runPrompt(operation, input, signal);
    return operation.completion;
  }

  private async runPrompt(operation: PromptOperation, input: ReturnType<typeof promptContent>, signal: AbortSignal): Promise<PromptResponse> {
    const before = this.session.getSessionStats().tokens;
    const cancel = () => { void this.cancel().catch((error) => { this.deliveryError ??= error; }); };
    signal.addEventListener("abort", cancel, { once: true });
    try {
      // Subscribe at session creation, before any prompt. SDK prompt resolves
      // after automatic work, not at its low-level agent_end event.
      let sdkAborted = false;
      try {
        await this.session.prompt(input.text, { images: input.images, source: "rpc" });
      } catch (error) {
        if (!operation.abort.signal.aborted || !(error instanceof Error) || error.name !== "AbortError") throw error;
        sdkAborted = true;
      }
      await this.session.waitForIdle();
      this.publishUsage();
      await this.drain();
      const last = operation.lastAssistant;
      const cancelled = sdkAborted || operation.settledAborted || last?.stopReason === "aborted";
      if (!cancelled && last?.stopReason === "error") {
        throw new RequestError(-32603, last.errorMessage || "Pi Provider request failed.");
      }
      const after = this.session.getSessionStats().tokens;
      return {
        stopReason: cancelled ? "cancelled" : last?.stopReason === "length" ? "max_tokens" : "end_turn",
        usage: {
          inputTokens: after.input - before.input, outputTokens: after.output - before.output,
          cachedReadTokens: after.cacheRead - before.cacheRead, cachedWriteTokens: after.cacheWrite - before.cacheWrite,
          totalTokens: after.total - before.total,
        },
      };
    } finally {
      signal.removeEventListener("abort", cancel);
      if (this.operation === operation) this.operation = undefined;
    }
  }

  async cancel(): Promise<void> {
    if (!this.operation) return;
    // Unblock pending ACP permissions before waiting for Pi to become idle.
    this.operation.abort.abort();
    await this.session.abort();
  }

  close(): Promise<void> {
    if (this.closing) return this.closing;
    this.closing = (async () => {
      await this.mutation?.promise;
      const prompt = this.operation?.completion;
      await this.cancel();
      await prompt?.catch(() => {}); // Its owning prompt already reports the outcome.
      try {
        await this.session.extensionRunner.emit({ type: "session_shutdown", reason: "quit" });
      } finally {
        this.disposed = true;
        this.unsubscribe?.();
        this.session.dispose();
      }
    })();
    return this.closing;
  }

  private permissions(): ExtensionFactory {
    return (pi) => {
      pi.on("tool_call", async (event, ctx): Promise<ToolCallEventResult | void> => {
        const operation = this.operation;
        if (!operation || operation.abort.signal.aborted || ctx.signal?.aborted) {
          return { block: true, reason: "Prompt cancelled.", terminate: true };
        }
        const toolCall = { toolCallId: event.toolCallId, ...toolDescription(event.toolName, event.input, this.cwd), rawInput: event.input, status: "pending" as const };
        this.publish({ sessionUpdate: "tool_call_update", ...toolCall });
        await this.drain();
        try {
          const request: RequestPermissionRequest = {
            sessionId: this.id, toolCall,
            options: [
              { optionId: "allow_once", name: "Allow", kind: "allow_once" },
              { optionId: "reject_once", name: "Deny", kind: "reject_once" },
            ],
          };
          const response: Promise<RequestPermissionResponse> = this.client.request(
            methods.client.session.requestPermission, request, { cancellationSignal: operation.abort.signal },
          );
          // JSON-RPC cancellation is cooperative. Pi must not remain blocked
          // on a client dialog while session/cancel is waiting for abort().
          const cancelled = Promise.withResolvers<Awaited<typeof response>>();
          const onAbort = () => cancelled.resolve({ outcome: { outcome: "cancelled" } });
          operation.abort.signal.addEventListener("abort", onAbort, { once: true });
          if (operation.abort.signal.aborted) onAbort();
          const result = await Promise.race([response, cancelled.promise]).finally(() => {
            operation.abort.signal.removeEventListener("abort", onAbort);
          });
          if (operation.abort.signal.aborted || result.outcome.outcome !== "selected" || result.outcome.optionId !== "allow_once") {
            return { block: true, reason: "Tool execution was not approved.", terminate: operation.abort.signal.aborted };
          }
          this.publish({ sessionUpdate: "tool_call_update", toolCallId: event.toolCallId, status: "in_progress" });
          await this.drain();
          return undefined;
        } catch (error) {
          if (operation.abort.signal.aborted) return { block: true, reason: "Prompt cancelled.", terminate: true };
          throw error;
        }
      });
    };
  }

  private onEvent(event: AgentSessionEvent): void {
    if (this.disposed) return;
    if (event.type === "session_info_changed") {
      this.publish({ sessionUpdate: "session_info_update", title: event.name, updatedAt: new Date().toISOString() });
    }
    if (!this.operation) return;
    if (event.type === "message_end" && event.message.role === "assistant") this.operation.lastAssistant = event.message;
    if (event.type === "agent_settled") this.operation.settledAborted = event.aborted;
    this.projection.event(event);
  }

  private publish(update: SessionNotification["update"]): void {
    this.updates = this.updates.then(async () => {
      if (!this.disposed && !this.deliveryError) await this.client.notify(methods.client.session.update, { sessionId: this.id, update });
    }).catch((error) => {
      this.deliveryError ??= error;
      void this.cancel().catch(() => {});
    });
  }

  private publishUsage(): void {
    const usage = this.session.getContextUsage();
    if (usage?.tokens != null) this.publish({ sessionUpdate: "usage_update", used: usage.tokens, size: usage.contextWindow });
  }

  private async drain(): Promise<void> {
    await this.updates;
    if (this.deliveryError) throw this.deliveryError;
  }

  private async withIdleSession<T>(action: () => Promise<T>): Promise<T> {
    this.requireIdle();
    const mutation = Promise.withResolvers<void>();
    this.mutation = mutation;
    try {
      return await action();
    } finally {
      this.mutation = undefined;
      mutation.resolve();
    }
  }

  private requireIdle(): void {
    if (this.disposed || this.closing) throw RequestError.invalidRequest(undefined, "Session is closed.");
    if (this.operation) throw RequestError.invalidRequest(undefined, "An ACP prompt already owns this session.");
    if (this.mutation) throw RequestError.invalidRequest(undefined, "Session configuration or history is being loaded.");
    if (this.deliveryError) throw this.deliveryError;
  }
}
