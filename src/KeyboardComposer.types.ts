import type { ReactNode, StyleProp, ViewStyle } from "react-native";

// Event payloads from native
export type TextEventPayload = {
  text: string;
};

export type HeightEventPayload = {
  height: number;
};

export type PTTState = "available" | "talking" | "listening";

// Context provided to custom composer children
export type KeyboardComposerContext = {
  /** Current keyboard height */
  keyboardHeight: number;
  /** Whether the keyboard is currently visible */
  keyboardVisible: boolean;
  /** Method to focus the input (if applicable) */
  focus: () => void;
  /** Method to blur/dismiss keyboard */
  blur: () => void;
};

// Props for the native view
export type KeyboardComposerViewProps = {
  /** Whether to use custom composer mode (hides native UI) */
  isCustomMode?: boolean;

  /** Placeholder text shown when empty */
  placeholder?: string;

  /** Controlled text value */
  text?: string;

  /** Minimum height of the composer */
  minHeight?: number;

  /** Maximum height before scrolling */
  maxHeight?: number;

  /** Whether the send button is enabled */
  sendButtonEnabled?: boolean;

  /** Whether the text input is editable */
  editable?: boolean;

  /** Whether to auto focus the input on mount */
  autoFocus?: boolean;

  /** Trigger to blur the input - change value to trigger blur */
  blurTrigger?: number;

  /** Whether the AI is currently streaming (shows stop button) */
  isStreaming?: boolean;

  /** Whether to show the PTT (Push-to-Talk) button */
  showPTTButton?: boolean;

  /** Whether the PTT button is enabled */
  pttEnabled?: boolean;

  /** PTT state controls appearance and behavior */
  pttState?: PTTState;

  /** Visual feedback when pressing the PTT button */
  pttPressedScale?: number;
  pttPressedOpacity?: number;

  /** Called when text changes */
  onChangeText?: (event: { nativeEvent: TextEventPayload }) => void;

  /** Called when send button is pressed */
  onSend?: (event: { nativeEvent: TextEventPayload }) => void;

  /** Called when stop button is pressed */
  onStop?: () => void;

  /** Called when composer height changes (for auto-grow) */
  onHeightChange?: (event: { nativeEvent: HeightEventPayload }) => void;

  /** Called when keyboard height changes (for list footer) */
  onKeyboardHeightChange?: (event: { nativeEvent: HeightEventPayload }) => void;

  /** Called when text input gains focus */
  onComposerFocus?: () => void;

  /** Called when text input loses focus */
  onComposerBlur?: () => void;

  /** Called when PTT button is tapped */
  onPTTPress?: () => void;

  /** Called when PTT button touch begins */
  onPTTPressIn?: () => void;

  /** Called when PTT button touch ends */
  onPTTPressOut?: () => void;

  /** Style for the container */
  style?: StyleProp<ViewStyle>;

  /** Children to render (for custom composer mode) */
  children?: ReactNode;
};

// Simplified props for the wrapper component
export type KeyboardComposerProps = {
  /**
   * Custom composer component to render instead of the native UI.
   * When provided, the native text input and buttons are hidden,
   * and your custom component is rendered inside the native container.
   * The container still handles keyboard tracking and positioning.
   */
  children?: ReactNode;

  /** Placeholder text shown when empty (native mode only) */
  placeholder?: string;

  /** Controlled text value (native mode only) */
  text?: string;

  /** Minimum height of the composer */
  minHeight?: number;

  /** Maximum height before scrolling */
  maxHeight?: number;

  /** Whether the send button is enabled (native mode only) */
  sendButtonEnabled?: boolean;

  /** Whether the text input is editable (native mode only) */
  editable?: boolean;

  /** Whether to auto focus the input on mount (native mode only) */
  autoFocus?: boolean;

  /** Trigger to blur the input - change value to trigger blur (native mode only) */
  blurTrigger?: number;

  /** Whether the AI is currently streaming (shows stop button, native mode only) */
  isStreaming?: boolean;

  /** Whether to show the PTT (Push-to-Talk) button (native mode only) */
  showPTTButton?: boolean;

  /** Whether the PTT button is enabled (native mode only) */
  pttEnabled?: boolean;

  /** PTT state controls appearance and behavior (native mode only) */
  pttState?: PTTState;

  /** Visual feedback when pressing the PTT button (native mode only) */
  pttPressedScale?: number;
  pttPressedOpacity?: number;

  /** Called when text changes (native mode only) */
  onChangeText?: (text: string) => void;

  /** Called when send button is pressed with the text (native mode only) */
  onSend?: (text: string) => void;

  /** Called when stop button is pressed (native mode only) */
  onStop?: () => void;

  /** Called when composer height changes */
  onHeightChange?: (height: number) => void;

  /** Called when keyboard height changes */
  onKeyboardHeightChange?: (height: number) => void;

  /** Called when text input gains focus (native mode only) */
  onComposerFocus?: () => void;

  /** Called when text input loses focus (native mode only) */
  onComposerBlur?: () => void;

  /** Called when PTT button is tapped (native mode only) */
  onPTTPress?: () => void;

  /** Called when PTT button touch begins (native mode only) */
  onPTTPressIn?: () => void;

  /** Called when PTT button touch ends (native mode only) */
  onPTTPressOut?: () => void;

  /** Style for the container */
  style?: StyleProp<ViewStyle>;
};

// Ref methods exposed by the composer
export type KeyboardComposerRef = {
  focus: () => void;
  blur: () => void;
  clear: () => void;
};

// Module constants
export type KeyboardComposerConstants = {
  defaultMinHeight: number;
  defaultMaxHeight: number;
  contentGap: number;
};
