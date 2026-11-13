/** Exact official SDK keys owned by this product; preserve every business key. */
export async function clearPlatformSession(driver: {remove(key:string):void; read(key:string):unknown}): Promise<void> {
  const keys=['fl_session_token','fl_session_token:refresh','fl_session_token:kind'].map(key => `fridge.platform.v1:${key}`);
  let failed=false;
  for (const key of keys) {try {driver.remove(key);if (driver.read(key)) failed=true;} catch {failed=true;}}
  if (failed) throw new Error('SESSION_CLEANUP_FAILED');
}
