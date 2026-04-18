import net from "node:net";
import { spawn } from "node:child_process";
import { mkdir } from "node:fs/promises";
import { isDeepStrictEqual } from "node:util";
import { dirname, resolve } from "node:path";

const DEFAULTS = {
  godotPath: "godot4",
  host: "127.0.0.1",
  port: 6010,
  startupTimeoutMs: 10_000,
  commandTimeoutMs: 5_000,
  connectRetryMs: 100,
  extraArgs: [],
  env: {},
};

function delay(ms) {
  return new Promise((resolveDelay) => setTimeout(resolveDelay, ms));
}

function connectOnce(host, port) {
  return new Promise((resolveSocket, rejectSocket) => {
    const socket = net.createConnection({ host, port });
    const onError = (error) => {
      socket.destroy();
      rejectSocket(error);
    };

    socket.once("error", onError);
    socket.once("connect", () => {
      socket.off("error", onError);
      socket.setNoDelay(true);
      resolveSocket(socket);
    });
  });
}

export async function launch(options) {
  const client = new Godoteer(options);
  await client.launch();
  return client;
}

export class Godoteer {
  constructor(options = {}) {
    this.options = { ...DEFAULTS, ...options };
    this.nextId = 1;
    this.pending = new Map();
    this.buffer = "";
    this.stdout = "";
    this.stderr = "";
    this.process = null;
    this.socket = null;
    this.closed = false;
  }

  async launch() {
    const {
      godotPath,
      projectPath,
      scene,
      host,
      port,
      extraArgs,
      env,
      startupTimeoutMs,
      connectRetryMs,
    } = this.options;

    if (!projectPath) {
      throw new Error("Missing `projectPath`.");
    }

    const args = ["--path", projectPath, ...extraArgs];
    if (scene) {
      args.push(scene);
    }

    this.process = spawn(godotPath, args, {
      env: {
        ...process.env,
        ...env,
        GODOTEER_HOST: host,
        GODOTEER_PORT: String(port),
      },
      stdio: ["ignore", "pipe", "pipe"],
    });

    let spawnError = null;
    let exitError = null;

    this.process.once("error", (error) => {
      spawnError = error;
    });

    this.process.once("exit", (code, signal) => {
      const reason = this.closed
        ? null
        : new Error(
            `Godot exited before close. code=${code ?? "null"} signal=${signal ?? "null"}${this._formatProcessOutput()}`
          );
      exitError = reason;
      this._rejectAll(reason);
    });

    this.process.stdout?.on("data", (chunk) => {
      this.stdout += chunk.toString("utf8");
      this.stdout = this.stdout.slice(-8_000);
    });

    this.process.stderr?.on("data", (chunk) => {
      this.stderr += chunk.toString("utf8");
      this.stderr = this.stderr.slice(-8_000);
    });

    const deadline = Date.now() + startupTimeoutMs;
    let lastError = null;

    while (Date.now() < deadline) {
      if (spawnError) {
        throw spawnError;
      }

      if (exitError) {
        throw exitError;
      }

      try {
        this.socket = await connectOnce(host, port);
        this._attachSocket();
        await this.call("ping");
        return this;
      } catch (error) {
        lastError = error;
        await delay(connectRetryMs);
      }
    }

    throw new Error(
      `Timed out connecting to Godoteer agent at ${host}:${port}. Last error: ${lastError?.message ?? "unknown"}${this._formatProcessOutput()}`
    );
  }

  async call(method, params = {}, timeoutMs = this.options.commandTimeoutMs) {
    if (!this.socket) {
      throw new Error("Socket not connected.");
    }

    const id = this.nextId++;
    const payload = JSON.stringify({ id, method, params }) + "\n";

    return new Promise((resolveCall, rejectCall) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        rejectCall(new Error(`Command timed out: ${method}`));
      }, timeoutMs);

      this.pending.set(id, {
        resolve: (value) => {
          clearTimeout(timer);
          resolveCall(value);
        },
        reject: (error) => {
          clearTimeout(timer);
          rejectCall(error);
        },
      });

      this.socket.write(payload, "utf8");
    });
  }

  async screenshot(options = {}) {
    const path = options.path ? resolve(options.path) : resolve("artifacts/godoteer.png");
    await mkdir(dirname(path), { recursive: true });
    const result = await this.call("screenshot", { path });
    return result.path;
  }

  async mouseMove(x, y) {
    await this.call("mouse_move", { x, y });
  }

  async mouseDown(button = "left", options = {}) {
    await this.call("mouse_button", {
      button,
      pressed: true,
      x: options.x,
      y: options.y,
    });
  }

  async mouseUp(button = "left", options = {}) {
    await this.call("mouse_button", {
      button,
      pressed: false,
      x: options.x,
      y: options.y,
    });
  }

  async click(x, y, options = {}) {
    const button = options.button ?? "left";
    const pressDelayMs = options.pressDelayMs ?? 16;
    await this.mouseMove(x, y);
    await this.mouseDown(button, { x, y });
    await delay(pressDelayMs);
    await this.mouseUp(button, { x, y });
  }

  async keyTap(key) {
    await this.call("key_tap", { key });
  }

  async invoke(nodePath, method, ...args) {
    const result = await this.call("call_method", {
      nodePath,
      method,
      args,
    });
    return result.value;
  }

  async nodeExists(nodePath) {
    const result = await this.call("node_exists", { nodePath });
    return result.exists;
  }

  async property(nodePath, property) {
    const result = await this.call("get_property", { nodePath, property });
    return result.value;
  }

  async tree(nodePath = "/root") {
    const result = await this.call("tree_snapshot", { nodePath });
    return result.nodes;
  }

  async expectNode(nodePath) {
    const exists = await this.nodeExists(nodePath);
    if (!exists) {
      throw new Error(`Expected node to exist: ${nodePath}`);
    }
  }

  async expectProperty(nodePath, property, expected) {
    const actual = await this.property(nodePath, property);
    if (!isDeepStrictEqual(actual, expected)) {
      throw new Error(
        `Property mismatch for ${nodePath}.${property}\nexpected: ${JSON.stringify(expected)}\nactual: ${JSON.stringify(actual)}`
      );
    }
  }

  async wait(ms) {
    await delay(ms);
  }

  async waitForNode(nodePath, options = {}) {
    const timeoutMs = options.timeoutMs ?? 2_000;
    const pollMs = options.pollMs ?? 50;
    const deadline = Date.now() + timeoutMs;

    while (Date.now() < deadline) {
      if (await this.nodeExists(nodePath)) {
        return true;
      }
      await delay(pollMs);
    }

    throw new Error(`Timed out waiting for node: ${nodePath}`);
  }

  async waitForProperty(nodePath, property, expected, options = {}) {
    const timeoutMs = options.timeoutMs ?? 2_000;
    const pollMs = options.pollMs ?? 50;
    const deadline = Date.now() + timeoutMs;

    while (Date.now() < deadline) {
      const actual = await this.property(nodePath, property);
      if (isDeepStrictEqual(actual, expected)) {
        return actual;
      }
      await delay(pollMs);
    }

    throw new Error(`Timed out waiting for property ${nodePath}.${property}`);
  }

  async close(options = {}) {
    const graceful = options.graceful ?? true;
    const killTimeoutMs = options.killTimeoutMs ?? 2_000;

    this.closed = true;

    if (graceful && this.socket) {
      try {
        await this.call("quit", {}, 1_000);
      } catch {}
    }

    if (this.socket) {
      this.socket.destroy();
      this.socket = null;
    }

    if (!this.process) {
      return;
    }

    const process = this.process;
    if (process.exitCode !== null || process.killed) {
      return;
    }

    await new Promise((resolveExit) => {
      const onExit = () => {
        clearTimeout(termTimer);
        clearTimeout(killTimer);
        resolveExit();
      };

      const termTimer = setTimeout(() => {
        if (process.exitCode === null && !process.killed) {
          process.kill("SIGTERM");
        }
      }, Math.max(1, Math.floor(killTimeoutMs / 2)));

      const killTimer = setTimeout(() => {
        if (process.exitCode === null && !process.killed) {
          process.kill("SIGKILL");
        }
      }, killTimeoutMs);

      process.once("exit", onExit);
    });
  }

  _attachSocket() {
    this.socket.on("data", (chunk) => {
      this.buffer += chunk.toString("utf8");

      while (true) {
        const newlineIndex = this.buffer.indexOf("\n");
        if (newlineIndex === -1) {
          break;
        }

        const rawLine = this.buffer.slice(0, newlineIndex).trim();
        this.buffer = this.buffer.slice(newlineIndex + 1);

        if (!rawLine) {
          continue;
        }

        let message;
        try {
          message = JSON.parse(rawLine);
        } catch (error) {
          this._rejectAll(new Error(`Bad JSON from Godot: ${error.message}`));
          continue;
        }

        const pending = this.pending.get(message.id);
        if (!pending) {
          continue;
        }

        this.pending.delete(message.id);
        if (message.ok) {
          pending.resolve(message.result);
        } else {
          pending.reject(new Error(message.error ?? "Unknown Godot error"));
        }
      }
    });

    this.socket.once("close", () => {
      this._rejectAll(new Error("Godoteer socket closed."));
    });

    this.socket.once("error", (error) => {
      this._rejectAll(error);
    });
  }

  _rejectAll(error) {
    if (!error) {
      return;
    }

    for (const [id, pending] of this.pending) {
      this.pending.delete(id);
      pending.reject(error);
    }
  }

  _formatProcessOutput() {
    const parts = [];

    if (this.stderr.trim()) {
      parts.push(`stderr=${JSON.stringify(this.stderr.trim())}`);
    }

    if (this.stdout.trim()) {
      parts.push(`stdout=${JSON.stringify(this.stdout.trim())}`);
    }

    return parts.length > 0 ? ` ${parts.join(" ")}` : "";
  }
}
