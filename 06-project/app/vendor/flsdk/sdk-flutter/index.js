import { FenlengBaseClient } from '@fenleng/sdk-core';

export class FlutterAuthSDKAdapter {
  constructor(client) {
    if (!client) throw new Error('FlutterAuthSDKAdapter requires a configured client');
    this.client = client;
  }

  async authenticateSecurely(credentials) {
    return this.client.request('/api/platform/v1/auth/login', 'POST', credentials);
  }
}
