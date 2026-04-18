import { launch } from "../src/index.js";

const app = await launch({
  godotPath: process.env.GODOT_PATH ?? "godot4",
  projectPath: process.env.GODOT_PROJECT ?? "/absolute/path/to/godot/project",
});

try {
  await app.waitForNode("/root/Main", { timeoutMs: 5_000 });
  await app.click(200, 120);
  await app.keyTap("Enter");
  await app.wait(100);
  const screenshotPath = await app.screenshot({ path: "artifacts/smoke.png" });
  console.log("screenshot:", screenshotPath);
  await app.expectNode("/root/Main");
} finally {
  await app.close();
}
