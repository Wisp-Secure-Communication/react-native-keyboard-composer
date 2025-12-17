import * as React from 'react';

import { LaunchHQReactNativeKeyboardComposerViewProps } from './LaunchHQReactNativeKeyboardComposer.types';

export default function LaunchHQReactNativeKeyboardComposerView(props: LaunchHQReactNativeKeyboardComposerViewProps) {
  return (
    <div>
      <iframe
        style={{ flex: 1 }}
        src={props.url}
        onLoad={() => props.onLoad({ nativeEvent: { url: props.url } })}
      />
    </div>
  );
}
