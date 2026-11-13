import fs from 'node:fs';
const file=new URL('../contracts/locales/messages.json',import.meta.url);
const m=JSON.parse(fs.readFileSync(file,'utf8'));
const labels={'zh-CN':'重试提交','zh-TW':'重試提交','en':'Retry submission','es':'Reintentar envío','fr':'Réessayer l’envoi','de':'Erneut senden','pt-BR':'Tentar enviar novamente','it':'Riprova invio','ja':'送信を再試行','ko':'다시 보내기','ar':'إعادة الإرسال','hi':'फिर भेजें','id':'Coba kirim lagi','ru':'Повторить отправку','tr':'Yeniden gönder','vi':'Thử gửi lại','th':'ลองส่งอีกครั้ง','nl':'Opnieuw versturen','pl':'Wyślij ponownie','uk':'Повторити надсилання'};
for(const[locale,label]of Object.entries(labels))m[locale].feedbackRetrySubmit=label;
fs.writeFileSync(file,JSON.stringify(m,null,2)+'\n');
