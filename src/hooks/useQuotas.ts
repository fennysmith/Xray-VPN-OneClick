import { useState, useEffect, useCallback } from 'react';
import { useServices } from '../contexts/ServiceContext.js';
import { type TrafficQuota } from '../types/quota.js';
import { DEFAULT_QUOTA } from '../types/quota.js';

export function useQuotas() {
  const { quotaManager, trafficManager } = useServices();
  const [quotas, setQuotas] = useState<Record<string, TrafficQuota>>({});
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    try {
      setLoading(true);
      const [stored, usages] = await Promise.all([
        quotaManager.getAllQuotas(),
        trafficManager.getAllUsage().catch(() => []),
      ]);

      const merged: Record<string, TrafficQuota> = { ...stored };
      for (const usage of usages) {
        const existing = merged[usage.email] ?? { ...DEFAULT_QUOTA };
        merged[usage.email] = {
          ...existing,
          usedBytes: usage.total,
        };
      }
      setQuotas(merged);
    } catch {
      setQuotas({});
    } finally {
      setLoading(false);
    }
  }, [quotaManager, trafficManager]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { quotas, loading, refresh };
}
