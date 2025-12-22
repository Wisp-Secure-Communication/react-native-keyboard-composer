import { requireNativeView } from "expo";
import type { ReactNode } from "react";
import type { ViewStyle, StyleProp } from "react-native";

export interface KeyboardAwareWrapperProps {
  children?: ReactNode;
  style?: StyleProp<ViewStyle>;
  /**
   * Extra bottom inset (composer height + gap).
   * Keyboard height is automatically handled by native code.
   */
  extraBottomInset?: number;
  /**
   * Trigger scroll to bottom when this value changes.
   * Use Date.now() or a counter to trigger.
   */
  scrollToTopTrigger?: number;
  /**
   * Trigger ChatGPT-style pin-to-top behavior.
   * Pins the latest message to the top of the viewport and creates
   * runway space below for the AI response to stream into.
   * Use Date.now() or a counter to trigger after sending a message.
   */
  pinToTopTrigger?: number;
  /**
   * Trigger clearing of the response reserve space.
   * Call when streaming is complete or cancelled.
   * Use Date.now() or a counter to trigger.
   */
  clearReserveTrigger?: number;
}

// Native view - auto-named as "KeyboardComposer_KeyboardAwareWrapper"
const NativeView: React.ComponentType<{
  style?: StyleProp<ViewStyle>;
  extraBottomInset?: number;
  scrollToTopTrigger?: number;
  pinToTopTrigger?: number;
  clearReserveTrigger?: number;
  children?: ReactNode;
}> = requireNativeView("KeyboardComposer_KeyboardAwareWrapper");

/**
 * Native wrapper that handles keyboard adjustments for ScrollView children.
 *
 * Behavior (matching iOS):
 * - When scrolled to bottom + keyboard opens → auto-scroll to keep content at bottom
 * - When NOT at bottom + keyboard opens → keyboard opens over content (no scroll)
 *
 * @example
 * ```tsx
 * <KeyboardAwareWrapper extraBottomInset={composerHeight + gap}>
 *   <ScrollView>...</ScrollView>
 * </KeyboardAwareWrapper>
 * ```
 */
export function KeyboardAwareWrapper({
  children,
  style,
  extraBottomInset = 0,
  scrollToTopTrigger = 0,
  pinToTopTrigger = 0,
  clearReserveTrigger = 0,
}: KeyboardAwareWrapperProps) {
  return (
    <NativeView
      style={style}
      extraBottomInset={extraBottomInset}
      scrollToTopTrigger={scrollToTopTrigger}
      pinToTopTrigger={pinToTopTrigger}
      clearReserveTrigger={clearReserveTrigger}
    >
      {children}
    </NativeView>
  );
}

export default KeyboardAwareWrapper;
