import {Button, Text, View} from '@tarojs/components';
import type {FoodRecord, StorageZone} from '@fridge/domain';
import type {CabinetModel, CabinetDoorModel} from '@fridge/application';
import {ActionButton, FridgeIcon, FridgePage, HeaderAction, RoundPhoto} from './primitives';
import type {FridgeStrings} from './strings';
import './inventory.scss';

export function CabinetView({model, strings, onOpenZone, onSettings, onReminders, onReview}: {
  model: CabinetModel; strings: FridgeStrings; onOpenZone: (zone: StorageZone) => void;
  onSettings: () => void; onReminders: () => void; onReview: () => void;
}) {
  const hint = model.hintKey;
  return <FridgePage title={strings.text('home')} strings={strings} actions={<>
    <HeaderAction name='bell' label={strings.text('notifications')} onClick={onReminders} badge={model.hasPending} />
    <HeaderAction name='settings' label={strings.text('settings')} onClick={onSettings} />
  </>}>
    {hint && <View className='fridge-home-hint'><Text>{strings.text(hint)}</Text>
      <Button onClick={onReview} hoverClass='fridge-pressed'>{strings.text('goOrganize')}</Button></View>}
    <View className='fridge-cabinet'>
      {model.doors.map(door => <CabinetDoor key={door.zone} model={door} strings={strings} onClick={() => onOpenZone(door.zone)} />)}
      <View className='fridge-feet' />
    </View>
  </FridgePage>;
}
function CabinetDoor({model, strings, onClick}: {model: CabinetDoorModel; strings: FridgeStrings; onClick: () => void}) {
  const {zone, shown, count, extraCount} = model;
  return <Button className={`fridge-door fridge-door--${zone}`} onClick={onClick}
    aria-label={`${strings.text(zone)} ${count ? strings.format('recordCount',{count}) : strings.text('empty')}`} hoverClass='fridge-pressed'>
    <View className='fridge-door-header'><View className='fridge-door-label'><FridgeIcon name={zone} /><Text>{strings.text(zone)}</Text></View>
      {count > 0 && <Text className='fridge-door-count'>{strings.format('recordCountShort', {count})}</Text>}</View>
    <View className={`fridge-door-photos ${!count ? 'fridge-door-photos--empty' : ''}`}>
      {!count ? <Text className='fridge-empty-plus'>+</Text> : <>
        {shown.map(food => <View className='fridge-photo-slot' key={food.id}><RoundPhoto className='fridge-door-photo' src={food.photoPath} errorLabel={strings.text('error')} />
          <Text className='fridge-photo-number'>#{food.id}</Text></View>)}
        {extraCount > 0 && <View className='fridge-photo-slot'><View className='fridge-more-photo'><View className='fridge-square-spacer' /><View className='fridge-square-content'>+{extraCount}</View></View>
          <Text className='fridge-photo-number'>{strings.text('more')}</Text></View>}
      </>}
    </View>
    <Text className='fridge-door-footer'>{strings.text(count ? 'manage' : 'empty')}{count ? ' ↗' : ''}</Text>
    {zone !== 'pantry' && <View className='fridge-door-handle' />}
  </Button>;
}
export function RecordsView({zone, foods, strings, onBack, onAdd, onReview, onOpen}: {
  zone: StorageZone; foods: readonly FoodRecord[]; strings: FridgeStrings; onBack: () => void;
  onAdd: () => void; onReview: () => void; onOpen: (food: FoodRecord) => void;
}) {
  return <FridgePage title={strings.text(`${zone}Zone`)} strings={strings} onBack={onBack} count={strings.format('recordCount', {count: foods.length})}>
    <Text className='fridge-records-hint'>{strings.text('recordsHint')}</Text>
    <View className='fridge-equal-actions'><ActionButton icon='camera' onClick={onAdd}>{strings.text('add')}</ActionButton>
      <ActionButton secondary onClick={onReview}>{strings.text('organize')}</ActionButton></View>
    <View className='fridge-record-grid'>{foods.map(food => <Button className='fridge-record' key={food.id}
      onClick={() => onOpen(food)} hoverClass='fridge-pressed' aria-label={`#${food.id}`}>
      <RoundPhoto className='fridge-record-photo' src={food.photoPath} errorLabel={strings.text('error')} />
      <Text className='fridge-record-number'>#{food.id}</Text>
      <Text className='fridge-record-date'>{strings.format('addedCaption', {date: strings.date(food.addedAt)})}</Text>
    </Button>)}</View>
  </FridgePage>;
}
