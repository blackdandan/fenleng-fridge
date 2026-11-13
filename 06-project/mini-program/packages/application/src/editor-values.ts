import {calendarDay} from '@fridge/domain';

export function intervalFromText(text: string): number | null {
  const ascii = text.trim().replace(/[٠-٩۰-۹०-९]/g, c => {
    const point = c.codePointAt(0)!;
    return String(point - (point >= 0x966 ? 0x966 : point >= 0x6f0 ? 0x6f0 : 0x660));
  });
  if (!/^[0-9]+$/.test(ascii)) return null;
  const value = Number(ascii);
  return Number.isInteger(value) && value >= 1 && value <= 3650 ? value : null;
}
export function timeValue(value: string): string {
  const date = new Date(value);
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}
export function localDateTime(day: string, time: string): string {
  if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(day) || !/^[0-9]{2}:[0-9]{2}$/.test(time)) throw new Error('CHECK_DATE_INVALID');
  const [year, month, date] = day.split('-').map(Number); const [hour, minute] = time.split(':').map(Number);
  const value = new Date(year, month - 1, date, hour, minute);
  if (calendarDay(value) !== day || value.getHours() !== hour || value.getMinutes() !== minute) throw new Error('CHECK_DATE_INVALID');
  return value.toISOString();
}
