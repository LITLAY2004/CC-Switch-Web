import { describe, expect, it, vi } from "vitest";
import type { ProviderHealth } from "@/lib/api/healthCheck";

const importHealthCheck = async () => {
  vi.resetModules();
  return import("@/lib/api/healthCheck");
};

const mockFetchResponse = (payload: unknown) =>
  vi.spyOn(globalThis, "fetch").mockResolvedValue({
    ok: true,
    status: 200,
    json: async () => payload,
  } as any);

describe("healthCheck API module", () => {
  it("statusToHealth converts numeric status to health enum", async () => {
    const { statusToHealth } = await importHealthCheck();

    expect(statusToHealth(1)).toBe("available");
    expect(statusToHealth(2)).toBe("degraded");
    expect(statusToHealth(0)).toBe("unavailable");
    expect(statusToHealth(99)).toBe("unknown");
  });

  it("calculateAvailability averages valid timeline entries", async () => {
    const { calculateAvailability } = await importHealthCheck();

    expect(calculateAvailability([{ availability: 100 }, { availability: 80 }])).toBe(90);
    expect(calculateAvailability([{ availability: -1 }, { availability: -5 }])).toBeUndefined();
    expect(calculateAvailability([])).toBeUndefined();
  });

  it("fetchAllHealthStatus maps API response to provider health and caches result", async () => {
    const payload = {
      meta: { period: "24h", count: 2 },
      data: [
        {
          provider: "88code",
          provider_url: "https://88code.com",
          service: "cc",
          category: "third_party",
          current_status: { status: 1, latency: 120, timestamp: 1_710_000_000 },
          timeline: [{ availability: 100 }, { availability: 80 }],
        },
        {
          provider: "duckcoding",
          provider_url: "https://duckcoding.com",
          service: "cx",
          category: "third_party",
          current_status: { status: 0, latency: 999, timestamp: 1_710_000_100 },
          timeline: [],
        },
      ],
    };

    const fetchMock = mockFetchResponse(payload);
    const { fetchAllHealthStatus } = await importHealthCheck();

    const firstResult = await fetchAllHealthStatus();

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(firstResult.get("88code/cc")).toEqual<ProviderHealth>({
      isHealthy: true,
      status: "available",
      latency: 120,
      lastChecked: 1_710_000_000 * 1000,
      availability: 90,
    });
    expect(firstResult.get("duckcoding/cx")).toEqual<ProviderHealth>({
      isHealthy: false,
      status: "unavailable",
      latency: 999,
      lastChecked: 1_710_000_100 * 1000,
      availability: undefined,
    });

    const secondResult = await fetchAllHealthStatus();
    expect(secondResult).toBe(firstResult);
    expect(fetchMock).toHaveBeenCalledTimes(1);

    fetchMock.mockRestore();
  });

  it("checkProviderHealth returns provider health or fallback when missing", async () => {
    const payload = {
      meta: { period: "24h", count: 1 },
      data: [
        {
          provider: "duckcoding",
          provider_url: "https://duckcoding.com",
          service: "cx",
          category: "third_party",
          current_status: { status: 2, latency: 88, timestamp: 1_710_000_200 },
          timeline: [{ availability: 70 }, { availability: 90 }],
        },
      ],
    };

    const fetchMock = mockFetchResponse(payload);
    const { checkProviderHealth } = await importHealthCheck();

    const existing = await checkProviderHealth("duckcoding", "cx");
    expect(existing).toEqual<ProviderHealth>({
      isHealthy: true,
      status: "degraded",
      latency: 88,
      lastChecked: 1_710_000_200 * 1000,
      availability: 80,
    });

    const missing = await checkProviderHealth("unknown", "cc");
    expect(missing.status).toBe("unknown");
    expect(missing.isHealthy).toBe(false);
    expect(missing.latency).toBe(0);

    expect(fetchMock).toHaveBeenCalledTimes(1);
    fetchMock.mockRestore();
  });

  it("appIdToService maps app ids to services", async () => {
    const { appIdToService } = await importHealthCheck();

    expect(appIdToService("claude")).toBe("cc");
    expect(appIdToService("codex")).toBe("cx");
    expect(appIdToService("gemini")).toBe("cc");
    expect(appIdToService("unknown" as any)).toBe("cc");
  });

  it("mergeHealth takes worse status when merging health data", async () => {
    const { mergeHealth } = await importHealthCheck();

    const available: ProviderHealth = {
      isHealthy: true,
      status: "available",
      latency: 100,
      lastChecked: 1000,
      availability: 95,
    };

    const unavailable: ProviderHealth = {
      isHealthy: false,
      status: "unavailable",
      latency: 50,
      lastChecked: 2000,
      availability: 10,
    };

    const merged = mergeHealth(available, unavailable);
    expect(merged.status).toBe("unavailable");
    expect(merged.isHealthy).toBe(false);
    expect(merged.availability).toBe(10);
    expect(merged.latency).toBe(100);
    expect(merged.lastChecked).toBe(2000);
  });

  it("mergeHealth returns incoming when existing is undefined", async () => {
    const { mergeHealth } = await importHealthCheck();

    const incoming: ProviderHealth = {
      isHealthy: true,
      status: "available",
      latency: 100,
      lastChecked: 1000,
      availability: 95,
    };

    const result = mergeHealth(undefined, incoming);
    expect(result).toEqual(incoming);
  });

  it("fetchAllHealthStatus aggregates multiple channels to worst status", async () => {
    const payload = {
      meta: { period: "24h", count: 2 },
      data: [
        {
          provider: "88code",
          provider_url: "https://88code.com",
          service: "cc",
          channel: "vip3",
          category: "third_party",
          current_status: { status: 0, latency: 500, timestamp: 1_710_000_000 },
          timeline: [{ availability: 0 }],
        },
        {
          provider: "88code",
          provider_url: "https://88code.com",
          service: "cc",
          channel: "vip5",
          category: "third_party",
          current_status: { status: 1, latency: 100, timestamp: 1_710_000_100 },
          timeline: [{ availability: 99 }],
        },
      ],
    };

    const fetchMock = mockFetchResponse(payload);
    const { fetchAllHealthStatus } = await importHealthCheck();

    const result = await fetchAllHealthStatus();
    const health = result.get("88code/cc");

    expect(health?.status).toBe("unavailable");
    expect(health?.isHealthy).toBe(false);
    expect(health?.availability).toBe(0);
    expect(health?.latency).toBe(500);

    fetchMock.mockRestore();
  });
});
