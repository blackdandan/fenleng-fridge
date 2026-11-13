import {useEffect, useState, useSyncExternalStore} from 'react';
import {useFridge} from '../runtime';
import {RecordEditorView} from './record-editor-view';

export function RecordEditorPage({id}: {id: string}) {
  const {controller, strings} = useFridge();
  const [editor] = useState(() => controller.editor(id));
  const state = useSyncExternalStore(editor.subscribe, editor.snapshot, editor.snapshot);
  useEffect(() => () => {void editor.close();}, [editor]);
  useEffect(() => {if (state.saved || state.deleted) controller.back();}, [controller, state.saved, state.deleted]);
  return <RecordEditorView food={editor.food} state={state} strings={strings} onChange={editor.change}
    onPhoto={() => {void editor.choosePhoto();}} onSave={() => {void editor.save();}} onDelete={() => {void editor.delete();}}
    onClose={() => {if (!state.busy) controller.back();}} />;
}
