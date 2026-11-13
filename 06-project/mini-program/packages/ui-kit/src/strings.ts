export class FridgeStrings {
  readonly rtl: boolean;
  constructor(readonly messages: Readonly<Record<string, Readonly<Record<string, string>>>>, readonly locale: string) {
    this.rtl = locale === 'ar';
  }
  text(key: string): string {
    const value = this.messages[this.locale]?.[key];
    if (typeof value !== 'string') throw new Error(`UI_TRANSLATION_MISSING:${this.locale}:${key}`);
    return value;
  }
  timestamp(value:number):string {
    const date=new Date(value);
    try{return date.toLocaleString(this.locale,{year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false});}
    catch {const pad=(n:number)=>n.toString().padStart(2,'0');return `${date.getFullYear()}-${pad(date.getMonth()+1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;}
  }
  format(key: string, values: Readonly<Record<string, string | number>>): string {
    return this.text(key).replace(/\{(\w+)\}/g, (_, name: string) => String(values[name] ?? `{${name}}`));
  }
  date(value: string, full = false): string {
    const date = new Date(value);
    const day = `${String(date.getMonth() + 1).padStart(2,'0')}.${String(date.getDate()).padStart(2,'0')}`;
    const time = `${String(date.getHours()).padStart(2,'0')}:${String(date.getMinutes()).padStart(2,'0')}`;
    if (this.locale.startsWith('zh')) return full ? `${day} ${time}` : day;
    try {return full ? date.toLocaleString(this.locale, {year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false}) : date.toLocaleDateString(this.locale, {month: '2-digit', day: '2-digit'});}
    catch {return full ? `${day} ${time}` : day;}
  }
  static resolve(locales: readonly string[], system: string, preference?: string | null): string {
    const input = (preference || system).replace(/_/g, '-');
    const exact = locales.find(locale => locale.toLowerCase() === input.toLowerCase());
    if (exact) return exact;
    if (/^zh/i.test(input)) return /TW|HK|Hant/i.test(input) ? 'zh-TW' : 'zh-CN';
    return locales.find(locale => locale.split('-')[0].toLowerCase() === input.split('-')[0].toLowerCase()) || 'zh-CN';
  }
}
