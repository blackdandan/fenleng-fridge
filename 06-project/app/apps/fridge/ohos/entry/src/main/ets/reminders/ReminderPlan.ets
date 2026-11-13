// Pure rules shared by the native bridge and host-side behavioral verification.
export class ReminderCycle {
  key: string = '';
  day: string = '';
  hour: number = 0;
  minute: number = 0;
  second: number = 0;
  millisecond: number = 0;
}

export class ReminderCopy {
  title: string = '';
  body: string = '';
  channel: string = '';
  locale: string = '';
}

export class ReminderBatch {
  identity: string = '';
  day: string = '';
  at: number = 0;
  localTime: string = '';
  keys: string[] = [];
  count: number = 0;
  notificationId: number = 0;
  title: string = '';
  content: string = '';
}

export function validDay(day: string): boolean {
  if (typeof day !== 'string' || !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(day)) return false;
  const year = Number(day.slice(0, 4)), month = Number(day.slice(5, 7)), date = Number(day.slice(8));
  if (year < 1000 || year > 9999) return false;
  const value = new Date(Date.UTC(year, month - 1, date));
  return value.getUTCFullYear() === year && value.getUTCMonth() === month - 1 && value.getUTCDate() === date;
}

export function cycleTime(cycle: ReminderCycle): number {
  if (!cycle || typeof cycle.key !== 'string' || !cycle.key.trim() || cycle.key.length > 512 || !validDay(cycle.day) ||
    !Number.isInteger(cycle.hour) || cycle.hour < 0 || cycle.hour > 23 ||
    !Number.isInteger(cycle.minute) || cycle.minute < 0 || cycle.minute > 59 ||
    !Number.isInteger(cycle.second) || cycle.second < 0 || cycle.second > 59 ||
    !Number.isInteger(cycle.millisecond) || cycle.millisecond < 0 || cycle.millisecond > 1000) {
    throw new Error('NOTIFICATION_PLAN_INVALID');
  }
  const day = cycle.day;
  // Calendar triggers use whole local wall-clock seconds. Never truncate early.
  return Math.ceil(new Date(Number(day.slice(0, 4)), Number(day.slice(5, 7)) - 1, Number(day.slice(8)),
    cycle.hour, cycle.minute, cycle.second, cycle.millisecond).getTime() / 1000) * 1000;
}

export function validateCopy(copy: ReminderCopy): void {
  if (!copy || typeof copy.title !== 'string' || !copy.title || copy.title.length > 256 ||
    typeof copy.body !== 'string' || !copy.body.includes('{count}') || copy.body.length > 1024 ||
    typeof copy.channel !== 'string' || !copy.channel || copy.channel.length > 128 ||
    typeof copy.locale !== 'string' || copy.locale.length > 32) throw new Error('NOTIFICATION_PLAN_INVALID');
}

export function localTimestamp(date: Date): string {
  const pad = (value: number): string => value.toString().padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

export function makeBatches(cycles: ReminderCycle[], seen: string[], copy: ReminderCopy, now: number,
  format: (count: number, locale: string) => string = (count: number): string => count.toString()): ReminderBatch[] {
  validateCopy(copy);
  if (!Array.isArray(cycles) || !Number.isFinite(now)) throw new Error('NOTIFICATION_PLAN_INVALID');
  const keys = new Set<string>();
  const times = cycles.map((cycle: ReminderCycle): number => {
    const at = cycleTime(cycle);
    if (keys.has(cycle.key)) throw new Error('NOTIFICATION_PLAN_INVALID');
    keys.add(cycle.key); return at;
  });
  const groups = new Map<string, ReminderBatch>();
  const visited = new Set<string>(seen);
  cycles.forEach((cycle: ReminderCycle, index: number): void => {
    if (visited.has(cycle.key)) return;
    // All already due cycles of one day are one immediate handoff, not a burst.
    const at = Math.max(Math.ceil(now / 1000) * 1000 + 1000, times[index]);
    const id = `${cycle.day}:${at}`;
    let batch = groups.get(id);
    if (!batch) {
      batch = new ReminderBatch(); batch.day = cycle.day; batch.at = at;
      batch.localTime = localTimestamp(new Date(at));
      batch.notificationId = Number(cycle.day.replace(/-/g, ''));
      batch.title = copy.title; groups.set(id, batch);
    }
    batch.keys.push(cycle.key);
  });
  const batches: ReminderBatch[] = [];
  groups.forEach((batch: ReminderBatch): void => {
    batch.keys.sort();
    batch.count = cycles.filter((cycle: ReminderCycle, i: number): boolean => cycle.day === batch.day && times[i] <= batch.at).length;
    const count = format(batch.count, copy.locale || 'en');
    batch.content = copy.body.split('{count}').join(count);
    // Private identity only; the OS click payload carries the calendar day.
    batch.identity = JSON.stringify([batch.day, batch.at, batch.keys, batch.title, batch.content]);
    batches.push(batch);
  });
  return batches.sort((a: ReminderBatch, b: ReminderBatch): number => a.at - b.at || a.identity.localeCompare(b.identity));
}
