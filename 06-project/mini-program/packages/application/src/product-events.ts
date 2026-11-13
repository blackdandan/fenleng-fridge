export type ProductEventSink=(event:string,properties:Readonly<Record<string,string>>)=>unknown;
export function emitProductEvent(sink:ProductEventSink,event:string,properties:Readonly<Record<string,string>>):void {
  try {sink(event,properties);}catch { /* Analysis cannot block a local inventory action. */ }
}
