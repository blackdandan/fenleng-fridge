import Taro from '@tarojs/taro';
import type {MediaPort} from '@fridge/platform-contracts';
import {collectManagedPhotos} from './managed-photos';

export class WeappMedia implements MediaPort {
  private directory = `${Taro.env.USER_DATA_PATH}/fridge-photos`;
  attachCamera(_id: string): void { /* The root page owns a single native camera component. */ }
  async chooseAlbum(maxCount = 9): Promise<readonly string[]> {
    return this.selectPhotos(maxCount,['album']);
  }
  async chooseReplacement(): Promise<string | null> {
    return (await this.selectPhotos(1,['camera','album']))[0] ?? null;
  }
  private async selectPhotos(count: number, sourceType: ('camera'|'album')[]): Promise<readonly string[]> {
    await Taro.requirePrivacyAuthorize();
    try {
      const result = await Taro.chooseMedia({count, mediaType: ['image'], sourceType});
      return result.tempFiles.map(file => file.tempFilePath);
    } catch (cause) {
      if (/cancel/i.test((cause as {errMsg?: string})?.errMsg || '')) return [];
      throw cause;
    }
  }
  async takePhoto(): Promise<string> {
    return new Promise<string>((resolve, reject) => Taro.createCameraContext().takePhoto({quality: 'high',
      success: photo => resolve(photo.tempImagePath), fail: reject}));
  }
  async persist(source: string): Promise<string> {
    const files = Taro.getFileSystemManager();
    try {files.accessSync(this.directory);} catch {files.mkdirSync(this.directory, true);}
    const extension = /\.(jpe?g|png|webp|gif|heic)$/i.exec(source)?.[1] || 'jpg';
    const target = `${this.directory}/${Date.now().toString(36)}-${Math.random().toString(36).slice(2) || '0'}.${extension}`;
    await new Promise<void>((resolve, reject) => files.copyFile({srcPath: source, destPath: target,
      success: () => resolve(), fail: reject}));
    return target;
  }
  async removeManaged(path: string): Promise<void> {
    if (!path.startsWith(`${this.directory}/`) || !/^[a-z0-9]+-[a-z0-9]+\.(jpe?g|png|webp|gif|heic)$/i.test(path.slice(this.directory.length + 1))) return;
    await new Promise<void>((resolve, reject) => Taro.getFileSystemManager().unlink({filePath: path,
      success: () => resolve(), fail: reject}));
  }
  async collectUnused(retained: ReadonlySet<string>): Promise<void> {
    const files = Taro.getFileSystemManager();
    await collectManagedPhotos(this.directory,retained,{
      exists: () => {try {files.accessSync(this.directory); return true;} catch {return false;}},
      names: () => files.readdirSync(this.directory), isFile: path => files.statSync(path).isFile(),
      remove: path => this.removeManaged(path),
    });
  }
}

export async function requestCamera(): Promise<boolean> {
  try {
    await Taro.requirePrivacyAuthorize();
    await Taro.authorize({scope: 'scope.camera'});
    return true;
  } catch {return false;}
}
export async function cameraGranted(): Promise<boolean> {
  const result = await Taro.getSetting();
  return result.authSetting['scope.camera'] === true;
}
export async function openCameraSettings(): Promise<boolean> {
  const settings = await Taro.openSetting();
  return settings.authSetting['scope.camera'] === true;
}
