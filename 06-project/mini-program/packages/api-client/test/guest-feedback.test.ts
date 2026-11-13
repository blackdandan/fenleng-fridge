import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {MiniIdentity} from '../src/identity.ts';
import {MiniFeedbackGateway} from '../src/feedback.ts';
import type {IdentityDriver} from '../src/identity.ts';

const config={enabled:true,guestEnabled:true,baseUrl:'https://platform.example.test',clientId:'fenleng-fridge-miniapp'};
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function fixture() {
  const values=new Map<string,string>();let nativeLogins=0;
  const driver: IdentityDriver={getStorageSync:key=>values.get(key),setStorageSync:(key,value)=>{values.set(key,value);},
    removeStorageSync:key=>{values.delete(key);},login:async()=>{nativeLogins++;return {code:'one-use-wechat-code'};},
    request:input=>{input.success({statusCode:200,data:{accessToken:'guest-access',refreshToken:'guest-refresh'}});}};
  return {driver,values,nativeLogins:()=>nativeLogins};
}
test('official Taro SDK crosses real local HTTP for guest feedback, restore and optional WeChat', async () => {
  const bodies: {path:string;body:Record<string,unknown>;authorization:string|undefined;key:string|undefined}[]=[];
  const server=createServer((request,response)=>{
    void (async()=>{
      let raw='';for await (const part of request) raw+=part;
      const body=JSON.parse(raw),path=request.url!;
      bodies.push({path,body,authorization:request.headers.authorization,key:request.headers['idempotency-key'] as string|undefined});
      response.setHeader('Content-Type','application/json');
      response.end(JSON.stringify(path.endsWith('/feedback') ? {id:'feedback-real-http-1',status:'RECEIVED'} :
        {accessToken:path.endsWith('/wechat/login')?'account-access':'guest-access',refreshToken:'refresh-token'}));
    })().catch(error=>{response.statusCode=500;response.end(JSON.stringify({code:'TEST_HANDLER_FAILED'}));});
  });
  await new Promise<void>(resolve=>server.listen(0,'127.0.0.1',resolve));
  const address=server.address() as {port:number};const f=fixture();
  f.driver.request=input=>fetch(`http://127.0.0.1:${address.port}${new URL(input.url).pathname}`,{
    method:input.method,headers:input.header,body:JSON.stringify(input.data),
  }).then(async response=>input.success({statusCode:response.status,data:await response.json()}))
    .catch(()=>input.fail({errMsg:'request:fail'}));
  let identity=new MiniIdentity(config,f.driver);
  const gateway=new MiniFeedbackGateway(()=>identity,()=>true);
  try {
    assert.equal(await gateway.submit('feedback text','feedback-http-key-1'),'feedback-real-http-1');
    assert.equal(identity.session.snapshot().identityKind,'guest');assert.equal(f.nativeLogins(),0);
    await identity.close();identity=new MiniIdentity(config,f.driver);
    assert.equal(await gateway.submit('feedback text','feedback-http-key-1'),'feedback-real-http-1');
    await identity.login();assert.equal(identity.session.snapshot().identityKind,'account');
    assert.equal(f.nativeLogins(),1);
    assert.deepEqual(bodies.map(row=>row.path),[
      '/api/platform/v1/auth/guest/login','/api/platform/v1/feedback',
      '/api/platform/v1/auth/refresh','/api/platform/v1/feedback','/api/platform/v1/auth/wechat/login',
    ]);
    assert.deepEqual(bodies[0].body,{applicationCode:'fenleng-fridge',clientId:'fenleng-fridge-miniapp'});
    for (const index of [1,3]) {
      assert.equal(bodies[index].authorization,'Bearer guest-access');assert.equal(bodies[index].key,'feedback-http-key-1');
      assert.deepEqual(bodies[index].body,{projectId:'fenleng-fridge',version:'0.1.0+1',traceId:null,
        message:'feedback text',attachmentConsent:false,attachments:[]});
    }
  } finally {await identity.close();server.closeAllConnections();await new Promise<void>(resolve=>server.close(()=>resolve()));}
});
test('guest ensure is single flight, while disabled guest never invokes wx.login', async () => {
  const f=fixture();let requests=0;
  f.driver.request=input=>{requests++;input.success({statusCode:200,data:{accessToken:'guest',refreshToken:'refresh'}});};
  const identity=new MiniIdentity(config,f.driver);
  try {
    const first=identity.ensureSession(),second=identity.ensureSession();assert.equal(first,second);
    assert.deepEqual(await Promise.all([first,second]),[true,true]);assert.equal(requests,1);assert.equal(f.nativeLogins(),0);
  } finally {await identity.close();}
  const disabled=new MiniIdentity({...config,guestEnabled:false},fixture().driver);
  assert.equal(await disabled.ensureSession(),false);await disabled.close();
});
test('401 feedback invalidates the session without replay; next user retry recovers', async () => {
  const f=fixture(),identity=new MiniIdentity(config,f.driver),paths: string[]=[];
  let rejected=false;
  f.driver.request=input=>{
    paths.push(input.url);
    if (input.url.endsWith('/feedback')) {
      if (!rejected) {rejected=true;input.success({statusCode:401,data:{code:'SESSION_EXPIRED'}});}
      else input.success({statusCode:200,data:{id:'feedback-after-retry',status:'RECEIVED'}});
    } else input.success({statusCode:200,data:{accessToken:'guest',refreshToken:'refresh'}});
  };
  const gateway=new MiniFeedbackGateway(()=>identity,()=>true);
  await assert.rejects(gateway.submit('text','feedback-retry-key'),/feedbackSessionUnavailable/);
  assert.equal(paths.length,2);assert.equal(f.values.size,0);
  assert.equal(await gateway.submit('text','feedback-retry-key'),'feedback-after-retry');
  assert.equal(paths.filter(path=>path.endsWith('/guest/login')).length,2);
  assert.equal(paths.filter(path=>path.endsWith('/feedback')).length,2);
  await identity.close();
});
test('transient restore failure preserves credentials and cannot create a replacement guest', async () => {
  const f=fixture(),identity=new MiniIdentity(config,f.driver);await identity.ensureSession();await identity.close();
  const paths: string[]=[];
  f.driver.request=input=>{paths.push(input.url);input.success({statusCode:503,data:{code:'UNAVAILABLE'}});};
  const reopened=new MiniIdentity(config,f.driver);
  await assert.rejects(reopened.ensureSession());assert.ok(paths.every(path=>path.endsWith('/auth/refresh')));
  assert.equal(f.values.size,3);await reopened.close();
});
test('closing during guest creation fences late tokens and receipt publication', async () => {
  const f=fixture(),identity=new MiniIdentity(config,f.driver);await identity.start();
  let finish!: ()=>void;
  f.driver.request=input=>{finish=()=>input.success({statusCode:200,data:{accessToken:'late',refreshToken:'late-refresh'}});};
  const creating=identity.ensureSession();const rejected=assert.rejects(creating);await tick();
  const closing=identity.close();finish();await rejected;await closing;assert.equal(f.values.size,0);
});
test('page cancellation fences late native code without replacing the existing guest', async () => {
  const f=fixture(),identity=new MiniIdentity(config,f.driver);await identity.ensureSession();
  let finish!: (value:{code:string})=>void;f.driver.login=()=>new Promise(resolve=>{finish=resolve;});
  const login=identity.login();identity.cancelLogin();finish({code:'late-code'});
  await assert.rejects(login,/loginCancelled/);assert.equal(identity.session.snapshot().identityKind,'guest');await identity.close();
});
