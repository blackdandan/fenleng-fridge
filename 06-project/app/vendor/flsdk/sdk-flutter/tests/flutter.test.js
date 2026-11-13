import assert from 'node:assert/strict';
import test from 'node:test';
import { FenlengBaseClient } from '@fenleng/sdk-core';
import { FlutterAuthSDKAdapter } from '../index.js';

test('FlutterAuthSDKAdapter provides Flutter secure authentication interface', async () => {
  const adapter = new FlutterAuthSDKAdapter(new FenlengBaseClient({baseUrl:'http://localhost:8080', fetch:async()=>new Response(JSON.stringify({status:'AUTHENTICATED'}),{status:200})}));
  const res = await adapter.authenticateSecurely({ user: 'flutter_dev' });
  assert.equal(res.status, 'AUTHENTICATED');
});
