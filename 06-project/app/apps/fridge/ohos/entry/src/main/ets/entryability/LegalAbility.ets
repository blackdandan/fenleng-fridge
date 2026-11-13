import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';

// A local document reader can open before Flutter business plugins initialize.
export default class LegalAbility extends UIAbility {
  private document: LocalStorage = new LocalStorage();
  onCreate(want: Want): void {
    this.document.setOrCreate('htmlBase64', (want.parameters?.htmlBase64 as string) || '');
    this.document.setOrCreate('title', (want.parameters?.title as string) || '');
    this.document.setOrCreate('backLabel', (want.parameters?.backLabel as string) || '');
    this.document.setOrCreate('withdrawalEnabled', (want.parameters?.withdrawalEnabled as string) || 'false');
  }
  onWindowStageCreate(stage: window.WindowStage): void {
    stage.loadContent('pages/Legal', this.document);
  }
}
