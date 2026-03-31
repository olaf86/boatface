import path from "node:path";
import {spawn} from "node:child_process";
import {defineSecret} from "firebase-functions/params";

export const datasetRefreshToken = defineSecret("DATASET_REFRESH_TOKEN");

export function getDefaultStorageBucket(projectId: string): string {
  return `${projectId}.firebasestorage.app`;
}

async function runLocalNodeScript(
  scriptName: string,
  args: string[],
): Promise<Record<string, unknown> | null> {
  const scriptPath = path.resolve(process.cwd(), "scripts", scriptName);

  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [scriptPath, ...args], {
      stdio: ["ignore", "pipe", "pipe"],
      env: process.env,
    });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      const text = chunk.toString();
      stdout += text;
      process.stdout.write(text);
    });

    child.stderr.on("data", (chunk) => {
      const text = chunk.toString();
      stderr += text;
      process.stderr.write(text);
    });

    child.on("error", reject);
    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(stderr || `${scriptName} exited with code ${code}`));
        return;
      }

      const lines = stdout
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean);
      const lastLine = lines.at(-1) ?? "";

      try {
        resolve(lastLine ? JSON.parse(lastLine) as Record<string, unknown> : null);
      } catch {
        resolve({rawOutput: stdout});
      }
    });
  });
}

export async function refreshRacerDataset(datasetId: string, options?: {
  syncImages?: boolean;
  clear?: boolean;
  setCurrent?: boolean;
}): Promise<Record<string, unknown>> {
  const projectId = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT;
  if (!projectId) {
    throw new Error("missing_project_id");
  }

  const syncImages = options?.syncImages ?? true;
  const clear = options?.clear ?? true;
  const setCurrent = options?.setCurrent ?? true;
  const bucket = getDefaultStorageBucket(projectId);

  const args = [
    "--dataset",
    datasetId,
    "--project",
    projectId,
    "--bucket",
    bucket,
  ];
  if (!clear) {
    args.push("--no-clear");
  }
  if (!setCurrent) {
    args.push("--no-set-current");
  }
  if (!syncImages) {
    args.push("--skip-images");
  }

  const result = await runLocalNodeScript("refresh-racer-dataset.mjs", args);

  return {
    datasetId,
    projectId,
    bucket: syncImages ? bucket : null,
    syncImages,
    clear,
    setCurrent,
    result,
  };
}

export function requireRefreshToken(request: {
  headers: Record<string, string | string[] | undefined>;
}): boolean {
  const headerValue = request.headers["x-boatface-admin-token"];
  const token =
    typeof headerValue === "string" ? headerValue.trim() :
      Array.isArray(headerValue) ? (headerValue[0] ?? "").trim() :
      "";

  return Boolean(token) && token === datasetRefreshToken.value();
}
