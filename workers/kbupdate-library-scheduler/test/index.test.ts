import { env } from "cloudflare:test";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { checkAndDispatch, type SchedulerEnv } from "../src/scheduler";

const checkedAt = new Date("2026-07-12T01:17:00.000Z");

function schedulerEnv(dispatchEnabled = "true"): SchedulerEnv {
  return {
    ...env,
    CATALOG_URL: "https://catalog.example.test/wsusscn2.cab",
    GITHUB_API_URL: "https://api.github.test",
    GITHUB_OWNER: "potatoqualitee",
    GITHUB_REPO: "kbupdate",
    GITHUB_WORKFLOW: "refresh-kbupdate-library.yml",
    GITHUB_REF: "main",
    DISPATCH_ENABLED: dispatchEnabled,
    GITHUB_TOKEN: "test-token",
  };
}

function catalogResponse(etag = '"catalog-v2"'): Response {
  return new Response(null, {
    status: 200,
    headers: {
      etag,
      "last-modified": "Tue, 09 Jun 2026 16:22:37 GMT",
      "content-length": "649341212",
    },
  });
}

beforeEach(async () => {
  await env.STATE.delete("catalog-state");
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("kbupdate library scheduler", () => {
  it("dispatches a new catalog once and checkpoints its fingerprint", async () => {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(catalogResponse())
      .mockResolvedValueOnce(
        Response.json(
          {
            workflow_run_id: 42,
            run_url: "https://api.github.test/repos/potatoqualitee/kbupdate/actions/runs/42",
            html_url: "https://github.test/potatoqualitee/kbupdate/actions/runs/42",
          },
          { status: 200 },
        ),
      );

    const first = await checkAndDispatch(schedulerEnv(), checkedAt, fetcher);
    const second = await checkAndDispatch(
      schedulerEnv(),
      new Date("2026-07-13T01:17:00.000Z"),
      vi.fn<typeof fetch>().mockResolvedValue(catalogResponse()),
    );

    expect(first.action).toBe("dispatched");
    expect(second.action).toBe("unchanged");
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(fetcher.mock.calls[1]?.[1]?.method).toBe("POST");
  });

  it("does not checkpoint a failed GitHub dispatch", async () => {
    const failedFetch = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(catalogResponse())
      .mockResolvedValueOnce(new Response("denied", { status: 403 }));

    await expect(checkAndDispatch(schedulerEnv(), checkedAt, failedFetch)).rejects.toThrow(
      "GitHub workflow dispatch failed",
    );

    const retryFetch = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(catalogResponse())
      .mockResolvedValueOnce(new Response(null, { status: 204 }));
    const retry = await checkAndDispatch(schedulerEnv(), checkedAt, retryFetch);

    expect(retry.action).toBe("dispatched");
    expect(retryFetch).toHaveBeenCalledTimes(2);
  });

  it("observes without dispatching while the gate is disabled", async () => {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(catalogResponse());

    const result = await checkAndDispatch(schedulerEnv("false"), checkedAt, fetcher);
    const state = await env.STATE.get<{ dispatchedFingerprint?: string }>("catalog-state", "json");

    expect(result.action).toBe("disabled");
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(state?.dispatchedFingerprint).toBeUndefined();
  });
});
