import test from 'node:test';
import assert from 'node:assert/strict';
import {emptyInventory,miniReminderCalendar,miniReminderLanguage,type FoodRecord} from '../src/index';

const food=(id:string,dueAt:string,remaining:FoodRecord['remaining']='full'):FoodRecord=>({id,dueAt,remaining,
  photoPath:`private/${id}.jpg`,zone:'cold',addedAt:'2026-11-01T00:00:00Z',confirmedAt:null,intervalDays:3,cycle:1});
test('calendar groups active cycles by local natural day and waits until all counted items are due',()=>{
  const previous=process.env.TZ;process.env.TZ='Asia/Shanghai';
  try {
    const inventory={...emptyInventory(),foods:{one:food('one','2026-11-13T08:00:00+08:00'),two:food('two','2026-11-13T17:30:00+08:00'),
      future:food('future','2026-11-14T17:30:00+08:00'),old:food('old','2026-11-12T17:30:00+08:00'),gone:food('gone','2026-11-14T17:30:00+08:00','gone')}};
    const before=JSON.stringify(inventory),plan=miniReminderCalendar(inventory,new Date('2026-11-13T18:00:00+08:00'),'Asia/Shanghai','zh-CN');
    assert.deepEqual(plan.days,[{day:'2026-11-13',fireAt:'2026-11-13T09:30:00.000Z',count:2},
      {day:'2026-11-14',fireAt:'2026-11-14T09:30:00.000Z',count:1}]);
    assert.equal(JSON.stringify(inventory),before);assert.ok(!JSON.stringify(plan).includes('private'));assert.ok(!JSON.stringify(plan).includes('foodId'));
  }finally {if(previous===undefined)delete process.env.TZ;else process.env.TZ=previous;}
});
test('DST fall-back times stay on one local day and preserve the later absolute due instant',()=>{
  const previous=process.env.TZ;process.env.TZ='America/New_York';
  try {
    const inventory={...emptyInventory(),foods:{a:food('a','2026-11-01T01:30:00-04:00'),b:food('b','2026-11-01T01:30:00-05:00')}};
    assert.deepEqual(miniReminderCalendar(inventory,new Date('2026-10-31T17:00:00-04:00'),'America/New_York','en').days,
      [{day:'2026-11-01',fireAt:'2026-11-01T06:30:00.000Z',count:2}]);
  }finally {if(previous===undefined)delete process.env.TZ;else process.env.TZ=previous;}
});
test('provider language is explicit and empty inventories never invent remote work',()=>{
  assert.equal(miniReminderLanguage('zh-Hant-HK'),'zh_HK');assert.equal(miniReminderLanguage('zh-TW'),'zh_TW');
  assert.equal(miniReminderLanguage('ar'),'en_US');assert.equal(miniReminderLanguage('zh-CN'),'zh_CN');
  assert.deepEqual(miniReminderCalendar(emptyInventory(),new Date(),'UTC','en').days,[]);
});
