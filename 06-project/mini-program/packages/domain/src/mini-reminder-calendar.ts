import {activeFoods,calendarDay,type InventoryState} from './models';

export type MiniReminderLanguage='zh_CN'|'zh_TW'|'zh_HK'|'en_US';
export interface MiniReminderCalendar {
  readonly timezone:string;readonly language:MiniReminderLanguage;
  readonly days:readonly {readonly day:string;readonly fireAt:string;readonly count:number}[];
}
export function miniReminderLanguage(locale:string):MiniReminderLanguage {
  if(/^zh[-_](HK|Hant[-_]HK)$/i.test(locale))return 'zh_HK';
  if(/^zh[-_](TW|Hant)/i.test(locale))return 'zh_TW';
  return /^zh/i.test(locale)?'zh_CN':'en_US';
}

/** One immutable message per local day, after the latest due time of that day's active cycles. */
export function miniReminderCalendar(state:InventoryState,now:Date,timezone:string,locale:string):MiniReminderCalendar {
  if(!timezone.trim() || !Number.isFinite(+now))throw new Error('MINI_CALENDAR_INVALID');
  const today=calendarDay(now),days=new Map<string,{day:string;fireAt:string;count:number}>();
  for(const food of activeFoods(state)) {
    const due=new Date(food.dueAt);if(!Number.isFinite(+due))throw new Error('MINI_CALENDAR_INVALID');
    const day=calendarDay(due);if(day<today)continue; // Past-day review cards stay local, never cross-day resends.
    const existing=days.get(day),fireAt=existing && Date.parse(existing.fireAt)>+due?existing.fireAt:due.toISOString();
    days.set(day,{day,fireAt,count:(existing?.count ?? 0)+1});
  }
  return {timezone,language:miniReminderLanguage(locale),days:[...days.values()].sort((a,b)=>a.day.localeCompare(b.day))};
}
