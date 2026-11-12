(() => {
const now=new Date('2026-11-12T10:00:00+08:00').getTime();
const days=86400000;
window.FRIDGE_DEMO={now,defaults:{cold:3,frozen:14,pantry:3,time:'17:30'},foods:Array.from({length:14},(_,i)=>({id:'r'+(i+1),number:String(i+1).padStart(3,'0'),photo:[0,1,2,3,8,0,1,2,4,5,4,6,7,6][i],zone:i<8?'cold':i<11?'frozen':'pantry',createdAt:now-(i%4+1)*days,lastCheckedAt:now-(i%3)*days,checkDays:i>=8&&i<11?14:3,reminderTime:'17:30',nextCheckAt:now+(i>=8&&i<11?12:2)*days+7.5*3600000,notifiedFor:null,amount:'full',status:'active'})),notifications:[],lastInventoryAt:now,lastReviewAt:now};
})();
