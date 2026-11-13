import { defineConfig } from '@tarojs/cli';
import path from 'node:path';
export default defineConfig({
  projectName: 'fenleng-fridge', date: '2026-11-13', designWidth: 430,
  deviceRatio: { 430: 750 / 430 }, sourceRoot: 'src', outputRoot: 'dist',
  framework: 'react', compiler: 'webpack5', cache: { enable: false },
  defineConstants: { FRIDGE_TELEMETRY_ENABLED: JSON.stringify(process.env.FRIDGE_TELEMETRY_ENABLED==='true'), FRIDGE_MINI_FILING: JSON.stringify(process.env.FRIDGE_MINI_FILING || ''), FRIDGE_LEGAL_WEB_ENABLED: JSON.stringify(process.env.FRIDGE_LEGAL_WEB_ENABLED !== 'false'), FRIDGE_IDENTITY_CONFIG: JSON.stringify({
    enabled: process.env.FRIDGE_IDENTITY_ENABLED === 'true',
    guestEnabled: process.env.FRIDGE_GUEST_ENABLED === 'true',
    baseUrl: process.env.FRIDGE_PLATFORM_URL || '',
    clientId: process.env.FRIDGE_PLATFORM_CLIENT_ID || 'fenleng-fridge-miniapp',
  }) },
  mini: {
    compile: { include: [path.resolve(__dirname, '../../../packages')] },
    postcss: { pxtransform: { enable: true }, cssModules: { enable: false } },
  },
});
