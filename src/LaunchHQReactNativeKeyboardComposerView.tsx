import { requireNativeView } from 'expo';
import * as React from 'react';

import { LaunchHQReactNativeKeyboardComposerViewProps } from './LaunchHQReactNativeKeyboardComposer.types';

const NativeView: React.ComponentType<LaunchHQReactNativeKeyboardComposerViewProps> =
  requireNativeView('LaunchHQReactNativeKeyboardComposer');

export default function LaunchHQReactNativeKeyboardComposerView(props: LaunchHQReactNativeKeyboardComposerViewProps) {
  return <NativeView {...props} />;
}
