import {useState} from 'react';
import {Button, Input, Picker, ScrollView, Text, View} from '@tarojs/components';
import {zones, type FoodRecord} from '@fridge/domain';
import type {EditorDraft, EditorSnapshot} from '@fridge/application';
import {ActionButton, FridgeDialog, FridgeIcon, RoundPhoto, type FridgeStrings} from '@fridge/ui-kit';
import './record-editor.scss';

function DateField({label, day, time, disabled, onDay, onTime}: {
  label: string; day: string; time: string; disabled: boolean; onDay: (v: string) => void; onTime: (v: string) => void;
}) {
  return <View className='fridge-editor-field'>
    <Text className='fridge-editor-label'>{label}</Text>
    <View className='fridge-editor-datetime'>
      <Picker mode='date' value={day} disabled={disabled} onChange={e => onDay(e.detail.value)}>
        <View className='fridge-editor-date-control' aria-label={label}><Text>{day.replace(/-/g, '/')}</Text><View className='fridge-editor-calendar-slot'><FridgeIcon name='calendar' /></View></View>
      </Picker>
      <Picker mode='time' value={time} disabled={disabled} onChange={e => onTime(e.detail.value)}>
        <View className='fridge-editor-time-control' aria-label={label}><Text>{time}</Text></View>
      </Picker>
    </View>
  </View>;
}
export function RecordEditorView({food, state, strings, onChange, onPhoto, onSave, onDelete, onClose}: {
  food: FoodRecord; state: EditorSnapshot; strings: FridgeStrings;
  onChange: (change: Partial<EditorDraft>) => void; onPhoto: () => void; onSave: () => void; onDelete: () => void; onClose: () => void;
}) {
  const [confirming, setConfirming] = useState(false);
  const {draft, busy, errorKey} = state;
  return <FridgeDialog className='fridge-editor-dialog'>
    <ScrollView scrollY className='fridge-editor-scroll'>
      <View className='fridge-editor-content'>
        <View className='fridge-editor-handle' />
        <View className='fridge-editor-header'><Text className='fridge-editor-title'>#{food.id}</Text>
          <Button disabled={busy} className='fridge-editor-close' aria-label={strings.text('cancel')} onClick={onClose}>×</Button>
        </View>
        {confirming ? <View className='fridge-editor-confirm'>
          <Text>{strings.text('confirmDelete')}</Text>
          {errorKey && <View role='alert'><Text>{strings.text(errorKey)}</Text></View>}
          <ActionButton disabled={busy} onClick={onDelete}>{strings.text(busy ? 'loading' : 'delete')}</ActionButton>
          <ActionButton disabled={busy} secondary onClick={() => setConfirming(false)}>{strings.text('cancel')}</ActionButton>
        </View> : <>
          <RoundPhoto src={draft.photoPath} className='fridge-editor-photo' errorLabel={strings.text('error')} />
          <Button className='fridge-editor-photo-link' disabled={busy} onClick={onPhoto}>{strings.text('replacePhoto')}</Button>
          <View className='fridge-editor-fields'>
            <DateField label={strings.text('addedAt')} day={draft.addedDay} time={draft.addedTime} disabled={busy}
              onDay={addedDay => onChange({addedDay})} onTime={addedTime => onChange({addedTime})} />
            <View className='fridge-editor-columns'>
              <View className='fridge-editor-field'><Text className='fridge-editor-label'>{strings.text('storageZone')}</Text>
                <Picker mode='selector' range={zones.map(z => strings.text(z))} value={zones.indexOf(draft.zone)} disabled={busy}
                  onChange={e => {const zone = zones[Number(e.detail.value)]; if (zone) onChange({zone});}}>
                  <View className='fridge-editor-control'><Text>{strings.text(draft.zone)}</Text><FridgeIcon name='editorChevron' /></View>
                </Picker>
              </View>
              <View className='fridge-editor-field'><Text className='fridge-editor-label'>{strings.text('interval')}</Text>
                <Input className='fridge-editor-number' type='number' value={draft.interval} disabled={busy} cursorSpacing={24}
                  aria-label={strings.text('interval')} onInput={e => onChange({interval: e.detail.value})} />
              </View>
            </View>
            <DateField label={strings.text('nextCheck')} day={draft.dueDay} time={draft.dueTime} disabled={busy}
              onDay={dueDay => onChange({dueDay})} onTime={dueTime => onChange({dueTime})} />
          </View>
          <View className='fridge-editor-hint'><Text>{strings.text('editorHint')}</Text>
            <Text>{food.confirmedAt ? strings.format('editorLastOrganized', {date: strings.date(food.confirmedAt, true)}) : strings.text('neverOrganized')}</Text>
          </View>
          <View className='fridge-editor-status' role='alert'>{errorKey && <Text>{strings.text(errorKey)}</Text>}</View>
          <ActionButton disabled={busy} onClick={onSave}>{strings.text(busy ? 'loading' : 'saveChanges')}</ActionButton>
          <Button className='fridge-editor-delete' disabled={busy} onClick={() => setConfirming(true)}>{strings.text('deleteRecordAction')}</Button>
        </>}
      </View>
    </ScrollView>
  </FridgeDialog>;
}
