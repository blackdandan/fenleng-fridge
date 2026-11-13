const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),mini=path.join(root,'06-project/mini-program'),store=path.join(mini,'node_modules/.pnpm');
const pkg=(prefix,name)=>path.join(store,fs.readdirSync(store).find(name=>name.startsWith(prefix)),'node_modules',name);
const esbuild=require(pkg('esbuild@0.28','esbuild')),sass=require(pkg('sass@1.94','sass'));
fs.writeFileSync(path.join(__dirname,'runtime.ts'),'export function useFridge(){return (globalThis as any).__subscriptionFixture;}');
fs.writeFileSync(path.join(__dirname,'components.jsx'),`import React from 'react';
export const Text=({children,...props})=><span {...props}>{children}</span>;
export const View=({children,...props})=><div {...props}>{children}</div>;
export const Button=({children,hoverClass,...props})=><button {...props}>{children}</button>;
export const Image=props=><img {...props}/>;`);
fs.writeFileSync(path.join(__dirname,'taro.js'),'export default {navigateTo:()=>Promise.resolve()};');
const source=path.join(mini,'apps/miniapp/src/presentation/subscription-settings.tsx');
fs.writeFileSync(path.join(__dirname,'entry.jsx'),`import React from 'react';
import {createRoot} from ${JSON.stringify(path.join(pkg('react-dom@18.3.1','react-dom'),'client.js'))};
import {SubscriptionSettings} from ${JSON.stringify(source)};
import {FridgeStrings} from ${JSON.stringify(path.join(mini,'packages/ui-kit/src/strings.ts'))};
import messages from ${JSON.stringify(path.join(mini,'apps/miniapp/src/locales/messages.json'))};
const root=createRoot(document.getElementById('root'));
window.renderFixture=async({locale,theme,scale,state})=>{
 const model={observedAcceptances:0,errorKey:null,messageKey:null,...state};
 const session={snapshot:()=>model,subscribe:()=>()=>{},enable:async()=>{},cancel:async()=>{},refresh:async()=>{},requestPermission:async()=>{}};
 globalThis.__subscriptionFixture={runtime:{online:{reminders:session}},strings:new FridgeStrings(messages,locale)};
 root.render(<div className={'fridge-theme fridge-theme--'+theme} data-rtl={locale==='ar'} dir={locale==='ar'?'rtl':'ltr'} style={{'--fridge-text-scale':scale}}>
  <div className='fridge-page'><SubscriptionSettings/></div></div>);
 await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
};window.fixtureLocales=Object.keys(messages);`);
(async()=>{await esbuild.build({entryPoints:[path.join(__dirname,'entry.jsx')],bundle:true,outfile:path.join(__dirname,'bundle.js'),platform:'browser',format:'iife',jsx:'automatic',
  tsconfig:path.join(mini,'tsconfig.json'),nodePaths:[path.join(mini,'apps/miniapp/node_modules')],loader:{'.scss':'empty'},
  alias:{'@tarojs/components':path.join(__dirname,'components.jsx'),'@tarojs/taro':path.join(__dirname,'taro.js'),
    '@fridge/ui-kit':path.join(mini,'packages/ui-kit/src/primitives.tsx'),'react':pkg('react@18.3.1','react')},
  plugins:[{name:'fixture-runtime',setup(build){build.onResolve({filter:/\/runtime$/},args=>args.importer===source?{path:path.join(__dirname,'runtime.ts')}:undefined);}}]});
const styles=[path.join(mini,'packages/ui-kit/src/theme.scss'),path.join(mini,'packages/ui-kit/src/settings.scss')]
  .map(file=>sass.compile(file,{style:'expanded',silenceDeprecations:['legacy-js-api']}).css).join('\n');
fs.writeFileSync(path.join(__dirname,'index.html'),`<!doctype html><meta charset='utf-8'><style>body{margin:0}*{box-sizing:border-box}${styles}</style><div id='root'></div><script src='./bundle.js'></script>`);
console.log('Built actual subscription component with DOM-only host shims; no native WeChat claims.');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
