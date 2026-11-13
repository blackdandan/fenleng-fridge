import {Button, Text, View} from '@tarojs/components';
import type {ReminderModel} from '@fridge/application';
import {ActionButton, FridgePage} from './primitives';
import type {FridgeStrings} from './strings';
import './reminders.scss';

export function RemindersView({items, strings, onBack, onOpen}: {
  items: readonly ReminderModel[]; strings: FridgeStrings; onBack: () => void; onOpen: (day: string) => void;
}) {
  return <FridgePage title={strings.text('notifications')} strings={strings} onBack={onBack}>
    {!items.length && <View className='fridge-reminders-empty'><Text>{strings.text('emptyReview')}</Text>
      <ActionButton onClick={onBack}>{strings.text('back')}</ActionButton></View>}
    <View className='fridge-reminders-list'>{items.map(item => <View className='fridge-reminder' key={item.day}>
      <Text className='fridge-reminder-date'>{strings.date(`${item.day}T12:00:00`, true)}</Text>
      <Text className='fridge-reminder-title'>{strings.text('notifications')}</Text>
      <Text className='fridge-reminder-count'>{strings.format('originalCount', {count: item.originalCount})}</Text>
      <View className='fridge-reminder-status'><Text>{strings.format('pendingCount', {count: item.pendingCount})}</Text>
        {item.stateKey !== 'pendingCount' && <Text>{strings.text(item.stateKey)}</Text>}</View>
      {item.pendingCount > 0 && <Button className='fridge-reminder-open' onClick={() => onOpen(item.day)}>{strings.text('organize')} ↗</Button>}
    </View>)}</View>
  </FridgePage>;
}
