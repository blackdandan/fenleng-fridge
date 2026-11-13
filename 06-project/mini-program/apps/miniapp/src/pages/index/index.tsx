import {activeFoods} from '@fridge/domain';
import {useLoad} from '@tarojs/taro';
import {useEffect} from 'react';
import {cabinetModel, reminderModels, type FridgeRoute} from '@fridge/application';
import {CabinetView, HistoryView, RecordsView, ReviewView, RemindersView} from '@fridge/ui-kit';
import {useFridge} from '../../runtime';
import {PageFrame} from '../../presentation/page-frame';
import {CameraPage} from '../../presentation/camera-page';
import {RecordEditorPage} from '../../presentation/record-editor-page';
import {DisplayChoicesPage, SettingsPage} from '../../presentation/settings-page';
import {FeedbackPage} from '../../presentation/feedback-page';

function InventoryContent() {
  const {controller,state} = useFridge();
  return <>
    <InventoryRoute route={state.route.name === 'detail' ? controller.backgroundRoute : state.route} />
    {state.route.name === 'detail' && state.stage === 'ready' && <RecordEditorPage key={state.route.id} id={state.route.id} />}
  </>;
}
function InventoryRoute({route}: {route: FridgeRoute}) {
  const {controller, state, strings} = useFridge();
  useEffect(()=>{if(route.name==='home' && state.stage==='ready')controller.recordEvent('fridge.home.viewed.v1');},[controller,route.name,state.stage]);
  if (route.name === 'home') return <CabinetView model={cabinetModel(state.inventory, new Date())} strings={strings}
    onOpenZone={controller.openZone} onSettings={() => controller.navigate({name: 'settings'})}
    onReminders={() => controller.navigate({name: 'reminders'})} onReview={() => controller.navigate({name: 'review'})} />;
  if (route.name === 'zone') return <RecordsView zone={route.zone} foods={activeFoods(state.inventory).filter(food => food.zone === route.zone)}
    strings={strings} onBack={controller.back} onAdd={() => controller.openCamera(route.zone)}
    onReview={() => controller.navigate({name: 'review', zone: route.zone})} onOpen={food => controller.navigate({name: 'detail', id: food.id})} />;
  if (route.name === 'camera') return <CameraPage />;
  if (route.name === 'reminders') return <RemindersView items={reminderModels(state.inventory, new Date())} strings={strings}
    onBack={controller.back} onOpen={day => controller.navigate({name: 'review', day})} />;
  if (route.name === 'review') return <ReviewView title={route.zone ? strings.format('organizeZone', {zone: strings.text(route.zone)}) : strings.text('organize')}
    foods={controller.reviewFoods(route)} strings={strings} busy={state.busy} errorKey={state.errorKey} completedReminder={Boolean(route.day)}
    undoRevision={state.undoRevision} onBack={controller.back} onConfirm={controller.organize} onUndo={controller.undo}
    onOpen={food => controller.navigate({name: 'detail', id: food.id})} />;
  if (route.name === 'settings') return <SettingsPage />;
  if (route.name === 'feedback') return <FeedbackPage />;
  if (route.name === 'language' || route.name === 'appearance') return <DisplayChoicesPage appearance={route.name === 'appearance'} />;
  if (route.name === 'history') return <HistoryView state={state.inventory} strings={strings} busy={state.busy} errorKey={state.errorKey}
    onBack={controller.back} onOpen={food => controller.navigate({name:'detail',id:food.id})} onRestore={id => {void controller.restore(id);}} />;
  return null;
}
export default function InventoryPage() {
  const {controller}=useFridge();
  useLoad(query=>{if(typeof query.reminderDay==='string')void controller.requestReminderDay(query.reminderDay);});
  return <PageFrame><InventoryContent /></PageFrame>;
}
