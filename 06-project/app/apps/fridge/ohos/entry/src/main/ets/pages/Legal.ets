import common from '@ohos.app.ability.common';
import webview from '@ohos.web.webview';

@Entry
@Component
struct Legal {
  @LocalStorageProp('htmlBase64') htmlBase64: string = '';
  @LocalStorageProp('title') title: string = '';
  @LocalStorageProp('backLabel') backLabel: string = '';
  @LocalStorageProp('withdrawalEnabled') withdrawalEnabled: string = 'false';
  private finishing: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();
  private close(action: string = ''): void {
    if (this.finishing) return;
    this.finishing = true;
    (getContext(this) as common.UIAbilityContext).terminateSelfWithResult({
      resultCode: 0, want: { parameters: { action: action } }
    }).catch(() => { this.finishing = false; });
  }

  build() {
    Column() {
      Row({ space: 16 }) {
        Button(this.backLabel).onClick(() => {
          this.close();
        }).height(48)
        Text(this.title).fontSize(20).layoutWeight(1)
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
      Web({ src: 'about:blank', controller: this.controller })
        .javaScriptAccess(false)
        .domStorageAccess(false)
        .blockNetwork(true)
        .onLoadIntercept((event) => {
          const url = event?.data.getRequestUrl() || '';
          if (this.withdrawalEnabled === 'true' && url === 'fridge://privacy/withdraw') {
            this.close('withdraw'); return true;
          }
          return url.length > 0 && !url.startsWith('about:');
        })
        .onControllerAttached(() => {
          this.controller.loadData(this.htmlBase64, 'text/html', 'base64');
        })
        .layoutWeight(1).width('100%')
    }.height('100%').width('100%')
  }
}
