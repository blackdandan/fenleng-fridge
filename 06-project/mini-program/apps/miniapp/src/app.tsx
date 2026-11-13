import {useEffect, useState, type PropsWithChildren} from 'react';
import {useDidHide, useDidShow} from '@tarojs/taro';
import {createRuntime, RuntimeContext} from './runtime';
import './app.scss';

export default function App({children}: PropsWithChildren) {
  const [runtime] = useState(createRuntime);
  useEffect(() => {void runtime.controller.initialize(); return () => {void runtime.online.close();runtime.controller.close();};}, [runtime]);
  useDidShow((options?:{query?:Record<string,string>}) => {
    runtime.controller.resume();runtime.online.resume();
    const day=options?.query?.reminderDay;if(day)void runtime.controller.requestReminderDay(day);
  });
  useDidHide(() => {runtime.controller.suspend();runtime.online.suspend();});
  return <RuntimeContext.Provider value={runtime}>{children}</RuntimeContext.Provider>;
}
