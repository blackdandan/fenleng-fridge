export const managedPhotoName = /^[a-z0-9]+-[a-z0-9]+\.(jpe?g|png|webp|gif|heic)$/i;
export interface PhotoDirectory {
  exists(): boolean;
  names(): readonly string[];
  isFile(path: string): boolean;
  remove(path: string): Promise<void>;
}
/** One owned directory, regular managed files only; never recurse. */
export async function collectManagedPhotos(directory: string, retained: ReadonlySet<string>, files: PhotoDirectory): Promise<void> {
  if (!files.exists()) return;
  for (const name of files.names()) {
    if (!managedPhotoName.test(name)) continue;
    const path = `${directory}/${name}`;
    if (!retained.has(path) && files.isFile(path)) await files.remove(path);
  }
}
