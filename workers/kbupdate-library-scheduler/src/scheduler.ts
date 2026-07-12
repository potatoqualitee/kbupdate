const STATE_KEY = "catalog-state";

type Fetcher = typeof fetch;

export interface SchedulerEnv {
  STATE: Env["STATE"];
  CATALOG_URL: string;
  GITHUB_API_URL: string;
  GITHUB_OWNER: string;
  GITHUB_REPO: string;
  GITHUB_WORKFLOW: string;
  GITHUB_REF: string;
  DISPATCH_ENABLED: string;
  GITHUB_TOKEN: string;
}

interface CatalogSnapshot {
  fingerprint: string;
  etag: string | null;
  lastModified: string | null;
  contentLength: string | null;
}

interface SchedulerState {
  checkedAt: string;
  observed: CatalogSnapshot;
  dispatchedAt?: string;
  dispatchedFingerprint?: string;
}

export interface CheckResult {
  action: "disabled" | "dispatched" | "unchanged";
  catalog: CatalogSnapshot;
}

function requiredHeader(headers: Headers, name: string): string | null {
  const value = headers.get(name);
  return value && value.trim() ? value.trim() : null;
}

async function readCatalog(env: SchedulerEnv, fetcher: Fetcher): Promise<CatalogSnapshot> {
  const response = await fetcher(env.CATALOG_URL, {
    method: "HEAD",
    redirect: "follow",
    headers: { "User-Agent": "kbupdate-library-scheduler/1.0" },
  });

  if (!response.ok) {
    throw new Error(`Microsoft catalog HEAD request failed with HTTP ${response.status}.`);
  }

  const etag = requiredHeader(response.headers, "etag");
  const lastModified = requiredHeader(response.headers, "last-modified");
  const contentLength = requiredHeader(response.headers, "content-length");
  const fingerprint = [etag, lastModified, contentLength].filter(Boolean).join("|");

  if (!fingerprint) {
    throw new Error("Microsoft catalog response did not include an ETag or usable metadata.");
  }

  return { fingerprint, etag, lastModified, contentLength };
}

async function dispatchRefresh(
  env: SchedulerEnv,
  catalog: CatalogSnapshot,
  fetcher: Fetcher,
): Promise<void> {
  const endpoint = new URL(
    `/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/actions/workflows/${env.GITHUB_WORKFLOW}/dispatches`,
    env.GITHUB_API_URL,
  );
  const response = await fetcher(endpoint, {
    method: "POST",
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      "Content-Type": "application/json",
      "User-Agent": "kbupdate-library-scheduler/1.0",
      "X-GitHub-Api-Version": "2026-03-10",
    },
    body: JSON.stringify({
      ref: env.GITHUB_REF,
      inputs: {
        catalog_fingerprint: catalog.fingerprint,
        catalog_etag: catalog.etag ?? "",
        catalog_last_modified: catalog.lastModified ?? "",
        catalog_content_length: catalog.contentLength ?? "",
      },
    }),
  });

  if (response.status !== 200 && response.status !== 204) {
    const detail = (await response.text()).slice(0, 1024);
    throw new Error(`GitHub workflow dispatch failed with HTTP ${response.status}: ${detail}`);
  }
}

export async function checkAndDispatch(
  env: SchedulerEnv,
  checkedAt: Date,
  fetcher: Fetcher = fetch,
): Promise<CheckResult> {
  const catalog = await readCatalog(env, fetcher);
  const previous = await env.STATE.get<SchedulerState>(STATE_KEY, "json");

  if (previous?.dispatchedFingerprint === catalog.fingerprint) {
    await env.STATE.put(
      STATE_KEY,
      JSON.stringify({ ...previous, checkedAt: checkedAt.toISOString(), observed: catalog }),
    );
    return { action: "unchanged", catalog };
  }

  if (env.DISPATCH_ENABLED.toLowerCase() !== "true") {
    await env.STATE.put(
      STATE_KEY,
      JSON.stringify({ ...previous, checkedAt: checkedAt.toISOString(), observed: catalog }),
    );
    return { action: "disabled", catalog };
  }

  await dispatchRefresh(env, catalog, fetcher);
  const dispatchedAt = checkedAt.toISOString();
  await env.STATE.put(
    STATE_KEY,
    JSON.stringify({
      checkedAt: dispatchedAt,
      observed: catalog,
      dispatchedAt,
      dispatchedFingerprint: catalog.fingerprint,
    } satisfies SchedulerState),
  );
  return { action: "dispatched", catalog };
}
