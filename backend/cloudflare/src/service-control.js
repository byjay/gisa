const STORAGE_KEY = 'state';
const DEFAULT_STATE = Object.freeze({
  enabled: true,
  message: '',
  updatedAt: '1970-01-01T00:00:00.000Z',
  revision: 0,
});

export function isValidServiceState(value) {
  return value !== null
    && typeof value === 'object'
    && typeof value.enabled === 'boolean'
    && typeof value.message === 'string'
    && typeof value.updatedAt === 'string'
    && Number.isFinite(Date.parse(value.updatedAt))
    && Number.isSafeInteger(value.revision)
    && value.revision >= 0;
}

function json(data, status = 200) {
  return Response.json(data, {
    status,
    headers: { 'Cache-Control': 'no-store' },
  });
}

export class ServiceControl {
  constructor(state) {
    this.state = state;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname !== '/state') return json({ error: 'not_found' }, 404);

    if (request.method === 'GET') {
      const stored = await this.state.storage.get(STORAGE_KEY);
      const value = stored === undefined ? DEFAULT_STATE : stored;
      if (!isValidServiceState(value)) {
        return json({ error: 'service_control_unavailable' }, 503);
      }
      if (stored === undefined) await this.state.storage.put(STORAGE_KEY, value);
      return json(value);
    }

    if (request.method === 'PUT') {
      let input;
      try {
        input = await request.json();
      } catch (_) {
        return json({ error: 'bad_request', message: '올바른 JSON이 필요합니다.' }, 400);
      }
      if (!input || typeof input.enabled !== 'boolean' || typeof input.message !== 'string') {
        return json({ error: 'bad_request', message: 'enabled와 message가 필요합니다.' }, 400);
      }

      const stored = await this.state.storage.get(STORAGE_KEY);
      const current = stored === undefined ? DEFAULT_STATE : stored;
      if (!isValidServiceState(current)) {
        return json({ error: 'service_control_unavailable' }, 503);
      }
      const next = {
        enabled: input.enabled,
        message: input.message,
        updatedAt: new Date().toISOString(),
        revision: current.revision + 1,
      };
      if (!Number.isSafeInteger(next.revision)) {
        return json({ error: 'service_control_unavailable' }, 503);
      }
      await this.state.storage.put(STORAGE_KEY, next);
      return json(next);
    }

    return json({ error: 'method_not_allowed' }, 405);
  }
}
