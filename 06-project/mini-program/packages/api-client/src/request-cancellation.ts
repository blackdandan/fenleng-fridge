/** The official Taro transport only needs this signal surface, without browser globals. */
export function requestCancellation(){
  const listeners=new Set<()=>void>();
  const signal={aborted:false,addEventListener:(_type:string,listener:()=>void)=>{listeners.add(listener);},
    removeEventListener:(_type:string,listener:()=>void)=>{listeners.delete(listener);}};
  return {signal:signal as unknown as AbortSignal,abort:()=>{
    if(signal.aborted)return;signal.aborted=true;listeners.forEach(listener=>listener());listeners.clear();
  }};
}
