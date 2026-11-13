import {Button, Text, View} from '@tarojs/components';
import type {FoodRecord, Remaining} from '@fridge/domain';
import {ActionButton, FridgePage, RoundPhoto} from './primitives';
import type {FridgeStrings} from './strings';
import './review.scss';

const choices: readonly Remaining[] = ['full', 'half', 'small', 'gone'];
export function ReviewView({title, foods, strings, busy, errorKey, completedReminder, undoRevision, onBack, onConfirm, onOpen, onUndo}: {
  title: string; foods: readonly FoodRecord[]; strings: FridgeStrings; busy: boolean; errorKey: string | null;
  completedReminder: boolean; undoRevision: number | null; onBack: () => void;
  onConfirm: (id: string, remaining: Remaining) => void; onOpen: (food: FoodRecord) => void; onUndo: (revision: number) => void;
}) {
  return <FridgePage title={title} strings={strings} onBack={onBack} count={strings.format('recordCount', {count: foods.length})}>
    <Text className='fridge-review-hint'>{strings.text('reviewHint')}</Text>
    {errorKey && <View className='fridge-review-error' role='alert'><Text>{strings.text(errorKey)}</Text></View>}
    {undoRevision !== null && <View className='fridge-undo'><Text>{strings.text('done')}</Text>
      <Button disabled={busy} onClick={() => onUndo(undoRevision)}>{strings.text('undo')}</Button></View>}
    {!foods.length && <View className='fridge-review-empty'><Text>{strings.text(completedReminder ? 'allHandled' : 'emptyReview')}</Text>
      <ActionButton onClick={onBack}>{strings.text('back')}</ActionButton></View>}
    <View className='fridge-review-list'>{foods.map(food => <View className='fridge-review-card' key={food.id}>
      <View className='fridge-review-row'>
        <RoundPhoto className='fridge-review-photo' src={food.photoPath} errorLabel={strings.text('error')} />
        <View className='fridge-review-info'><Text>#{food.id}</Text>
          <Text className='fridge-review-meta'>{strings.format('addedCaption', {date: strings.date(food.addedAt)})} · {strings.text(food.zone)}</Text>
          <Text className='fridge-review-meta'>{food.confirmedAt ? strings.format('lastOrganizedCaption', {date: strings.date(food.confirmedAt, true)}) : strings.text('neverOrganized')}</Text>
        </View>
        <Button className='fridge-review-detail' disabled={busy} onClick={() => onOpen(food)}>{strings.text('detail')}</Button>
      </View>
      <View className='fridge-review-choices'>{choices.map(choice => <Button key={choice}
        className={`fridge-review-choice ${choice === 'gone' ? 'fridge-review-choice--gone' : ''} ${choice === food.remaining ? 'fridge-review-choice--selected' : ''}`}
        disabled={busy} aria-pressed={choice === food.remaining} onClick={() => onConfirm(food.id, choice)}>{strings.text(choice)}</Button>)}</View>
    </View>)}</View>
  </FridgePage>;
}
