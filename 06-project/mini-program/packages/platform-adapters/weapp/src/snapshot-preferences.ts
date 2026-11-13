import type {PreferencesPort, PrivacyRecord} from '@fridge/platform-contracts';

export interface PreferencesDriver {
  keys(): readonly string[];
  read(key: string): unknown;
  write(key: string, value: unknown): Promise<void>;
  remove(key: string): Promise<void>;
}
type Display = Awaited<ReturnType<PreferencesPort['readDisplay']>>;
export class SnapshotPreferences implements PreferencesPort {
  constructor(private driver: PreferencesDriver) {}
  async readWithdrawalPending(): Promise<boolean> {return this.driver.read('fridge.privacy.withdrawal.v1') === true;}
  async beginWithdrawal(): Promise<void> {await this.driver.write('fridge.privacy.withdrawal.v1',true);}
  async finishWithdrawal(): Promise<void> {await this.driver.remove('fridge.privacy.withdrawal.v1');}
  async readPrivacy(): Promise<PrivacyRecord | null> {
    const record = this.driver.read('fridge.privacy.v1') as PrivacyRecord | null;
    return record && typeof record.policyVersion === 'string' && typeof record.acceptedAt === 'string' ? record : null;
  }
  async writePrivacy(record: PrivacyRecord | null): Promise<void> {
    if (record) await this.driver.write('fridge.privacy.v1',record);
    else await this.driver.remove('fridge.privacy.v1');
  }
  async readDisplay(): Promise<Display> {
    if (this.driver.keys().includes('fridge.display.v1')) {
      const record = this.driver.read('fridge.display.v1') as Display | null;
      if (!record || !['system','light','dark'].includes(record.theme) ||
        !(record.locale === null || typeof record.locale === 'string' && record.locale.length > 0)) {
        // A display preference must not lock users out of their inventory.
        // Keep the stored evidence until an explicit new display choice.
        return {locale:null,theme:'system'};
      }
      return record;
    }
    const locale = this.driver.read('fridge.locale'); const theme = this.driver.read('fridge.theme');
    return {locale: typeof locale === 'string' && locale ? locale : null,
      theme: theme === 'light' || theme === 'dark' ? theme : 'system'};
  }
  async writeDisplay(value: Display): Promise<void> {
    // One native storage commit prevents mixed language/theme after a quota error.
    await this.driver.write('fridge.display.v1',value);
  }
}
