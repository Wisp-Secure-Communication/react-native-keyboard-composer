import { NativeModule, requireNativeModule } from 'expo';

import { LaunchHQReactNativeKeyboardComposerModuleEvents } from './LaunchHQReactNativeKeyboardComposer.types';

declare class LaunchHQReactNativeKeyboardComposerModule extends NativeModule<LaunchHQReactNativeKeyboardComposerModuleEvents> {
  PI: number;
  hello(): string;
  setValueAsync(value: string): Promise<void>;
}

// This call loads the native module object from the JSI.
export default requireNativeModule<LaunchHQReactNativeKeyboardComposerModule>('LaunchHQReactNativeKeyboardComposer');
