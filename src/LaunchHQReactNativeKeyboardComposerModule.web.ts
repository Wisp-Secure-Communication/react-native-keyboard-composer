import { registerWebModule, NativeModule } from 'expo';

import { LaunchHQReactNativeKeyboardComposerModuleEvents } from './LaunchHQReactNativeKeyboardComposer.types';

class LaunchHQReactNativeKeyboardComposerModule extends NativeModule<LaunchHQReactNativeKeyboardComposerModuleEvents> {
  PI = Math.PI;
  async setValueAsync(value: string): Promise<void> {
    this.emit('onChange', { value });
  }
  hello() {
    return 'Hello world! 👋';
  }
}

export default registerWebModule(LaunchHQReactNativeKeyboardComposerModule, 'LaunchHQReactNativeKeyboardComposerModule');
