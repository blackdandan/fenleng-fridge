import {Button, Text, View} from '@tarojs/components';
import {useState} from 'react';
import {activeFoods, historyFoods, type InventoryState, type FoodRecord} from '@fridge/domain';
import {FridgePage, RoundPhoto} from './primitives';
import type {FridgeStrings} from './strings';
import './history.scss';

export function HistoryView({state, strings, busy, errorKey, onBack, onOpen, onRestore}: {
  state: InventoryState; strings: FridgeStrings; busy: boolean; errorKey: string | null;
  onBack: () => void; onOpen: (food: FoodRecord) => void; onRestore: (id: string) => void;
}) {
  const [historical, setHistorical] = useState(true);
  const active = activeFoods(state); const history = historyFoods(state);
  const foods = [...(historical ? history : active)].sort((a,b) => +new Date(b.confirmedAt || b.addedAt) - +new Date(a.confirmedAt || a.addedAt));
  return <FridgePage title={strings.text('foodRecords')} strings={strings} onBack={onBack}>
    <View className='fridge-history-tabs' role='tablist'>
      {[false, true].map(value => <Button key={String(value)} aria-pressed={historical === value}
        className={historical === value ? 'fridge-history-tab fridge-history-tab--selected' : 'fridge-history-tab'}
        disabled={busy} onClick={() => setHistorical(value)}>
        {strings.format(value ? 'historyRecords' : 'activeRecords', {count: value ? history.length : active.length})}
      </Button>)}
    </View>
    <Text className='fridge-history-hint'>{strings.text(historical ? 'historyHint' : 'recordsHint')}</Text>
    {errorKey && <View role='alert' className='fridge-history-error'><Text>{strings.text(errorKey)}</Text></View>}
    {!foods.length && <Text className='fridge-history-empty'>{strings.text(historical ? 'emptyHistory' : 'emptyReview')}</Text>}
    <View className='fridge-history-list'>{foods.map(food => <View className='fridge-history-card' key={food.id}>
      <RoundPhoto src={food.photoPath} className='fridge-history-photo' errorLabel={strings.text('error')} />
      <Button className='fridge-history-info' disabled={busy} onClick={() => onOpen(food)}>
        <Text>#{food.id} <Text className='fridge-history-meta'>· {strings.text(food.zone)}</Text></Text>
        <Text className='fridge-history-meta'>{strings.format('addedCaption', {date: strings.date(food.addedAt)})}{historical ? ` · ${strings.text('removed')}` : ''}</Text>
      </Button>
      {historical && <Button className='fridge-history-restore' disabled={busy} onClick={() => onRestore(food.id)}>{strings.text('restore')}</Button>}
    </View>)}</View>
  </FridgePage>;
}
