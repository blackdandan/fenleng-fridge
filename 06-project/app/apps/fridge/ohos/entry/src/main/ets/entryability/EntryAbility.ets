
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import BootstrapChannel from './BootstrapChannel';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';

export default class EntryAbility extends FlutterAbility {
  private bootstrap: BootstrapChannel | null = null;
  private reminderUri: string = '';
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.reminderUri = want.uri || '';
    super.onCreate(want, launchParam);
    if (this.bootstrap && this.reminderUri) {
      this.bootstrap.receiveReminder(this.reminderUri);
      this.reminderUri = '';
    }
  }
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParam);
    this.reminderUri = want.uri || '';
    if (this.bootstrap) {
      this.bootstrap.receiveReminder(this.reminderUri);
      this.reminderUri = '';
    }
  }
  configureFlutterEngine(flutterEngine: FlutterEngine): void {
    this.bootstrap = new BootstrapChannel(this.context, flutterEngine);
    this.bootstrap.receiveReminder(this.reminderUri);
    this.reminderUri = '';
  }
}
