import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {collectManagedPhotos} from '../src/managed-photos';

test('startup collection touches only unreferenced regular managed files in its owned directory',async t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(),'fridge-mini-photo-test-')).replace(/\\/g,'/');
  t.after(() => {
    const actual = fs.realpathSync(directory); const temp = fs.realpathSync(os.tmpdir());
    assert.equal(path.dirname(actual),temp); assert(path.basename(actual).startsWith('fridge-mini-photo-test-'));
    fs.rmSync(actual,{recursive:true,force:true});
  });
  for (const name of ['aaa-1.jpg','aaa-2.jpg','aaa-3.heic','unmanaged.jpg']) fs.writeFileSync(`${directory}/${name}`,Buffer.from([1,2,3]));
  fs.mkdirSync(`${directory}/aaa-dir.jpg`); fs.writeFileSync(`${directory}/aaa-dir.jpg/child.jpg`,'keep');
  const retained = new Set([`${directory}/aaa-1.jpg`]); const removed: string[] = [];
  await collectManagedPhotos(directory,retained,{
    exists: () => true,names: () => fs.readdirSync(directory),isFile: p => fs.lstatSync(p).isFile(),
    remove: async p => {removed.push(path.basename(p)); fs.unlinkSync(p);},
  });
  assert.deepEqual(removed.sort(),['aaa-2.jpg','aaa-3.heic']);
  assert(fs.existsSync(`${directory}/aaa-1.jpg`)); assert(fs.existsSync(`${directory}/unmanaged.jpg`));
  assert(fs.existsSync(`${directory}/aaa-dir.jpg/child.jpg`));
});
