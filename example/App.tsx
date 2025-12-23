import { useState, useCallback } from "react";
import {
  View,
  Text,
  StyleSheet,
  useColorScheme,
  ScrollView,
  StatusBar,
} from "react-native";
import {
  SafeAreaProvider,
  useSafeAreaInsets,
} from "react-native-safe-area-context";
import {
  KeyboardComposer,
  KeyboardAwareWrapper,
  constants,
} from "@launchhq/react-native-keyboard-composer";
import { useResponsive } from "./hooks/useResponsive";

// Mock conversation data
const INITIAL_MESSAGES: Message[] = [
  {
    id: "1",
    text: "What problem does this keyboard composer solve?",
    role: "user",
    timestamp: Date.now() - 120000,
  },
  {
    id: "2",
    text: "Keyboard handling in chat apps is hard. This library ensures your content reacts correctly when the keyboard opens, closes, or when the input grows.",
    role: "assistant",
    timestamp: Date.now() - 115000,
  },
  {
    id: "3",
    text: "What do you mean by 'reacts correctly'?",
    role: "user",
    timestamp: Date.now() - 110000,
  },
  {
    id: "4",
    text: "Three key behaviors:\n\n• Keyboard opens → content pushes up to keep your last message visible\n• Input grows with text → content scrolls to maintain the gap\n• You scroll up then close keyboard → no awkward gaps or jumps",
    role: "assistant",
    timestamp: Date.now() - 105000,
  },
  {
    id: "5",
    text: "Does it know when to push content vs overlay?",
    role: "user",
    timestamp: Date.now() - 100000,
  },
  {
    id: "6",
    text: "Yes! If you're at the bottom reading the latest message, it pushes content up. If you've scrolled up to read history, the keyboard overlays without forcing a scroll.",
    role: "assistant",
    timestamp: Date.now() - 95000,
  },
  {
    id: "7",
    text: "What happens when I type multiple lines?",
    role: "user",
    timestamp: Date.now() - 90000,
  },
  {
    id: "8",
    text: "The composer auto-grows (up to maxHeight), and the content scrolls to maintain the gap between your last message and the input. No shrinking gap, no abrupt snaps.",
    role: "assistant",
    timestamp: Date.now() - 85000,
  },
  {
    id: "9",
    text: "Is this built for AI chat apps?",
    role: "user",
    timestamp: Date.now() - 80000,
  },
  {
    id: "10",
    text: "Exactly. Built for apps like ChatGPT and v0 where you need:\n\n• Auto-growing input for long prompts\n• Streaming support with stop button\n• Scroll-to-bottom button when you scroll away",
    role: "assistant",
    timestamp: Date.now() - 75000,
  },
  {
    id: "11",
    text: "Does it work on both iOS and Android?",
    role: "user",
    timestamp: Date.now() - 70000,
  },
  {
    id: "12",
    text: "Yes, same behavior on both platforms. Native implementations handle the platform differences so you get consistent UX.\n\n• iOS 15+\n• Android API 21+",
    role: "assistant",
    timestamp: Date.now() - 65000,
  },
  {
    id: "13",
    text: "How do I install it?",
    role: "user",
    timestamp: Date.now() - 60000,
  },
  {
    id: "14",
    text: "pnpm add @launchhq/react-native-keyboard-composer\n\nThen 'npx expo prebuild' for Expo projects. That's it!",
    role: "assistant",
    timestamp: Date.now() - 55000,
  },
  {
    id: "15",
    text: "This is exactly what I needed 🎉",
    role: "user",
    timestamp: Date.now() - 50000,
  },
  {
    id: "16",
    text: "Try it out! Type below and watch the content react as you type. Scroll up to see the scroll-to-bottom button appear. 🚀",
    role: "assistant",
    timestamp: Date.now() - 45000,
  },
];

interface Message {
  id: string;
  text: string;
  role: "user" | "assistant";
  timestamp: number;
}

function ChatScreen() {
  const insets = useSafeAreaInsets();
  const colorScheme = useColorScheme();
  const isDark = colorScheme === "dark";
  const { isTablet, isDesktop, width, scaleFont } = useResponsive();

  const [messages, setMessages] = useState<Message[]>(INITIAL_MESSAGES);
  const [composerHeight, setComposerHeight] = useState(
    constants.defaultMinHeight
  );
  const [isStreaming, setIsStreaming] = useState(false);

  const handleHeightChange = useCallback((height: number) => {
    setComposerHeight(height);
  }, []);
  const [scrollTrigger, setScrollTrigger] = useState(0);
  const [pinTrigger, setPinTrigger] = useState(0);
  const [clearReserveTrigger, setClearReserveTrigger] = useState(0);

  // Responsive layout
  const isLargeScreen = isTablet || isDesktop;
  const maxContentWidth = isLargeScreen ? Math.min(600, width - 48) : undefined;

  const colors = {
    background: isDark ? "#000000" : "#ffffff",
    userBubble: "#007AFF",
    assistantBubble: isDark ? "#2c2c2e" : "#e9e9eb",
    userText: "#ffffff",
    assistantText: isDark ? "#ffffff" : "#000000",
    timestamp: isDark ? "#8e8e93" : "#8e8e93",
  };

  const handleSend = useCallback((text: string) => {
    if (!text.trim()) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      text: text.trim(),
      role: "user",
      timestamp: Date.now(),
    };

    setMessages((prev) => [...prev, userMessage]);

    // Trigger pin-to-top (ChatGPT style) - pins user message at top with runway below
    const triggerValue = Date.now();
    console.log("[App] Setting pinTrigger to:", triggerValue);
    setPinTrigger(triggerValue);
    setIsStreaming(true);

    // Simulate streaming assistant response
    const responses = [
      // "That's interesting! Tell me more about what you're building.",
      // "I see what you mean. Good keyboard handling really does make a difference in chat UX. The pin-to-top feature creates that familiar ChatGPT experience where your message stays visible at the top while the response streams in below.",
      // "Great observation! Notice how the content adjusts as you type. This library handles all the edge cases - keyboard opening, input growing, scroll position management.",
      // "Thanks for trying out the keyboard composer! The pin-to-top with runway feature is perfect for AI chat apps where you want the user's message to stay visible while streaming the response.",
      "This is a super long response to test how the pin-to-top feature handles extensive content. When building AI chat applications, keyboard handling is one of the most challenging aspects to get right. Users expect smooth, native-feeling interactions that don't jump or glitch when the keyboard appears or disappears. This library solves that problem by implementing native-level keyboard tracking on both iOS and Android. On iOS, we use keyboardLayoutGuide for frame-accurate positioning, while on Android we leverage WindowInsetsAnimationCompat for synchronized animations. The pin-to-top feature you're testing right now is inspired by ChatGPT's behavior where your message stays visible at the top while the AI response streams in below. This creates a natural reading flow where you can always see what you asked while watching the response appear word by word. The runway space below your message dynamically adjusts based on the viewport height, ensuring the experience feels right on any device from small phones to large tablets. As this response continues to stream, notice how the scroll-to-bottom button appears, giving you an easy way to jump to the latest content. The content inset management ensures there's always proper spacing between the last message and the composer input. This prevents the awkward situation where text gets hidden behind the keyboard or the input field. When streaming completes, the reserve space is cleared intelligently - if the content exceeds the viewport, we keep the reserve to avoid jarring jumps, letting you scroll naturally. If the content is short, the reserve is removed smoothly. All of this happens without any setTimeout hacks or arbitrary delays - everything is event-driven using proper UIKit patterns like KVO for content size changes and NotificationCenter for keyboard events. The result is buttery smooth animations that feel truly native.",
      "This is a super long response to test how the pin-to-top feature handles extensive content. When building AI chat applications, keyboard handling is one of the most challenging aspects to get right. Users expect smooth, native-feeling interactions that don't jump or glitch when the keyboard appears or disappears. This library solves that problem by implementing native-level keyboard tracking on both iOS and Android. On iOS, we use keyboardLayoutGuide for frame-accurate positioning, while on Android we leverage WindowInsetsAnimationCompat for synchronized animations. The pin-to-top feature you're testing right now is inspired by ChatGPT's behavior where your message stays visible at the top while the AI response streams in below. This creates a natural reading flow where you can always see what you asked while watching the response appear word by word. The runway space below your message dynamically adjusts based on the viewport height, ensuring the experience feels right on any device from small phones to large tablets. As this response continues to stream, notice how the scroll-to-bottom button appears, giving you an easy way to jump to the latest content. The content inset management ensures there's always proper spacing between the last message and the composer input. This prevents the awkward situation where text gets hidden behind the keyboard or the input field. When streaming completes, the reserve space is cleared intelligently - if the content exceeds the viewport, we keep the reserve to avoid jarring jumps, letting you scroll naturally. If the content is short, the reserve is removed smoothly. All of this happens without any setTimeout hacks or arbitrary delays - everything is event-driven using proper UIKit patterns like KVO for content size changes and NotificationCenter for keyboard events. The result is buttery smooth animations that feel truly native.",
      "This is a super long response to test how the pin-to-top feature handles extensive content. When building AI chat applications, keyboard handling is one of the most challenging aspects to get right. Users expect smooth, native-feeling interactions that don't jump or glitch when the keyboard appears or disappears. This library solves that problem by implementing native-level keyboard tracking on both iOS and Android. On iOS, we use keyboardLayoutGuide for frame-accurate positioning, while on Android we leverage WindowInsetsAnimationCompat for synchronized animations. The pin-to-top feature you're testing right now is inspired by ChatGPT's behavior where your message stays visible at the top while the AI response streams in below. This creates a natural reading flow where you can always see what you asked while watching the response appear word by word. The runway space below your message dynamically adjusts based on the viewport height, ensuring the experience feels right on any device from small phones to large tablets. As this response continues to stream, notice how the scroll-to-bottom button appears, giving you an easy way to jump to the latest content. The content inset management ensures there's always proper spacing between the last message and the composer input. This prevents the awkward situation where text gets hidden behind the keyboard or the input field. When streaming completes, the reserve space is cleared intelligently - if the content exceeds the viewport, we keep the reserve to avoid jarring jumps, letting you scroll naturally. If the content is short, the reserve is removed smoothly. All of this happens without any setTimeout hacks or arbitrary delays - everything is event-driven using proper UIKit patterns like KVO for content size changes and NotificationCenter for keyboard events. The result is buttery smooth animations that feel truly native.",
    ];
    const responseText =
      responses[Math.floor(Math.random() * responses.length)];

    // Simulate streaming with words appearing one by one
    let currentText = "";
    const words = responseText.split(" ");
    let wordIndex = 0;

    const streamInterval = setInterval(() => {
      if (wordIndex < words.length) {
        currentText += (wordIndex > 0 ? " " : "") + words[wordIndex];
        wordIndex++;

        // Update or add the assistant message
        setMessages((prev) => {
          const existingAssistantIndex = prev.findIndex(
            (m) => m.id === "streaming"
          );
          const streamingMessage: Message = {
            id: "streaming",
            text: currentText,
            role: "assistant",
            timestamp: Date.now(),
          };

          if (existingAssistantIndex >= 0) {
            const updated = [...prev];
            updated[existingAssistantIndex] = streamingMessage;
            return updated;
          } else {
            return [...prev, streamingMessage];
          }
        });
      } else {
        // Streaming complete
        clearInterval(streamInterval);
        setIsStreaming(false);

        // Finalize the message with a real ID
        setMessages((prev) => {
          const updated = prev.map((m) =>
            m.id === "streaming" ? { ...m, id: Date.now().toString() } : m
          );
          return updated;
        });

        // Clear the reserve space
        setClearReserveTrigger(Date.now());
      }
    }, 80); // 80ms per word for realistic streaming
  }, []);

  const renderMessage = (item: Message) => {
    const isUser = item.role === "user";
    const messageContent = (
      <View
        style={[
          styles.messageContainer,
          isUser ? styles.userMessage : styles.assistantMessage,
        ]}
      >
        <View
          style={[
            styles.bubble,
            {
              backgroundColor: isUser
                ? colors.userBubble
                : colors.assistantBubble,
            },
          ]}
        >
          <Text
            style={[
              styles.messageText,
              {
                color: isUser ? colors.userText : colors.assistantText,
                fontSize: scaleFont(16),
                lineHeight: scaleFont(22),
              },
            ]}
          >
            {item.text}
          </Text>
        </View>
      </View>
    );

    // Center content on large screens
    if (isLargeScreen && maxContentWidth) {
      return (
        <View key={item.id} style={styles.messageWrapper}>
          <View style={{ width: maxContentWidth }}>{messageContent}</View>
        </View>
      );
    }

    return <View key={item.id}>{messageContent}</View>;
  };

  // Bottom inset for scroll content - just composer height (gap handled natively)
  const baseBottomInset = composerHeight;

  // Debug log

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <StatusBar barStyle={isDark ? "light-content" : "dark-content"} />

      {/* Header */}
      <View style={[styles.header, { paddingTop: insets.top + 8 }]}>
        <Text
          style={[
            styles.headerTitle,
            { color: isDark ? "#fff" : "#000", fontSize: scaleFont(17) },
          ]}
        >
          Keyboard Composer Example
        </Text>
        <Text
          style={[
            styles.headerSubtitle,
            { color: colors.timestamp, fontSize: scaleFont(12) },
          ]}
        >
          Content-aware keyboard handling
        </Text>
      </View>

      {/* KeyboardAwareWrapper manages both scroll content AND composer animation */}
      <KeyboardAwareWrapper
        style={styles.chatArea}
        extraBottomInset={baseBottomInset}
        scrollToTopTrigger={scrollTrigger}
        pinToTopTrigger={pinTrigger}
        clearReserveTrigger={clearReserveTrigger}
      >
        {/* ScrollView with messages */}
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={[
            styles.messageList,
            isLargeScreen && styles.messageListCentered,
          ]}
        >
          {messages.map(renderMessage)}
        </ScrollView>

        {/* Composer - positioned absolutely, animated by native code */}
        {/* Note: Safe area padding is handled natively by KeyboardAwareWrapper */}
        <View style={styles.composerContainer} pointerEvents="box-none">
          <View
            style={[
              styles.composerInner,
              isLargeScreen && styles.composerInnerCentered,
            ]}
            pointerEvents="box-none"
          >
            <View
              style={[
                styles.composerWrapper,
                { height: composerHeight },
                { backgroundColor: isDark ? "#1C1C1E" : "#F2F2F7" },
                maxContentWidth ? { width: maxContentWidth } : undefined,
              ]}
            >
              <KeyboardComposer
                placeholder="Type a message..."
                onSend={handleSend}
                onHeightChange={handleHeightChange}
                minHeight={constants.defaultMinHeight}
                maxHeight={constants.defaultMaxHeight}
                sendButtonEnabled={true}
                isStreaming={isStreaming}
                onStop={() => {
                  setIsStreaming(false);
                  setClearReserveTrigger(Date.now());
                }}
                style={{ flex: 1 }}
              />
            </View>
          </View>
        </View>
      </KeyboardAwareWrapper>
    </View>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <ChatScreen />
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 16,
    paddingBottom: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#e5e5e5",
  },
  headerTitle: {
    fontWeight: "600",
    textAlign: "center",
  },
  headerSubtitle: {
    textAlign: "center",
    marginTop: 2,
  },
  chatArea: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  messageList: {
    paddingHorizontal: 16,
    paddingTop: 16,
    // No paddingBottom needed - native code handles spacing via extraBottomInset
  },
  messageListCentered: {
    alignItems: "center",
  },
  messageWrapper: {
    alignItems: "center",
    width: "100%",
  },
  messageContainer: {
    marginBottom: 16,
    maxWidth: "80%",
  },
  userMessage: {
    alignSelf: "flex-end",
  },
  assistantMessage: {
    alignSelf: "flex-start",
  },
  bubble: {
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 18,
  },
  messageText: {
    // fontSize and lineHeight set dynamically via scaleFont
  },
  // Composer styles - matches ai-chat.tsx pattern
  composerContainer: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
  },
  composerInner: {
    paddingHorizontal: 16,
  },
  composerInnerCentered: {
    alignItems: "center",
  },
  composerWrapper: {
    borderRadius: 24,
    overflow: "hidden",
  },
});
