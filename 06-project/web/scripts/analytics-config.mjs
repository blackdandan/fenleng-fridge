export function websiteAnalyticsConfig(environment,version) {
  const enabled=environment.FRIDGE_WEB_TELEMETRY_ENABLED==='true';
  const baseUrl=environment.FRIDGE_PLATFORM_URL || '',clientId=environment.FRIDGE_WEBSITE_CLIENT_ID || 'fenleng-fridge-website';
  if(enabled) {
    let url;try {url=new URL(baseUrl);}catch {throw Error('WEBSITE_ANALYTICS_CONFIG_INVALID');}
    if(url.protocol!=='https:' && !['localhost','127.0.0.1'].includes(url.hostname) || url.username || url.password || url.search || url.hash ||
      !/^[A-Za-z0-9][A-Za-z0-9._:-]{2,127}$/.test(clientId))throw Error('WEBSITE_ANALYTICS_CONFIG_INVALID');
  }
  return {enabled,baseUrl:enabled?baseUrl:'',clientId:enabled?clientId:'fenleng-fridge-website',policyVersion:'V0.4',version,buildNumber:'1'};
}
