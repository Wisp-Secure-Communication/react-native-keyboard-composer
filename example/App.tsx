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
    text: "Hey! What is this keyboard composer library?",
    role: "user",
    timestamp: Date.now() - 120000,
  },
  {
    id: "2",
    text: "It's a native keyboard-aware composer for React Native! It provides smooth, 60fps keyboard animations that match system apps like iMessage and WhatsApp.",
    role: "assistant",
    timestamp: Date.now() - 115000,
  },
  {
    id: "3",
    text: "How is it different from other keyboard libraries?",
    role: "user",
    timestamp: Date.now() - 110000,
  },
  {
    id: "4",
    text: "Great question! Unlike JS-based solutions, this uses native APIs:\n\n• iOS: KeyboardLayoutGuide + CADisplayLink for 60fps tracking\n• Android: WindowInsetsAnimationCompat for frame-perfect sync\n\nNo JavaScript bridge delays means buttery smooth animations.",
    role: "assistant",
    timestamp: Date.now() - 105000,
  },
  {
    id: "5",
    text: "Does it handle multiline input?",
    role: "user",
    timestamp: Date.now() - 100000,
  },
  {
    id: "6",
    text: "Yes! The composer auto-grows as you type. You can configure:\n\n• minHeight - default 48pt\n• maxHeight - default 120pt\n\nOnce it hits max height, it becomes scrollable internally.",
    role: "assistant",
    timestamp: Date.now() - 95000,
  },
  {
    id: "7",
    text: "What about the scroll behavior when keyboard opens?",
    role: "user",
    timestamp: Date.now() - 90000,
  },
  {
    id: "8",
    text: "The KeyboardAwareWrapper handles that intelligently:\n\n• At bottom + keyboard opens → stays at bottom\n• Scrolled up + keyboard opens → keyboard opens over content, no forced scroll\n\nThis matches iOS Messages behavior exactly!",
    role: "assistant",
    timestamp: Date.now() - 85000,
  },
  {
    id: "9",
    text: "Can I use it for AI chat apps with streaming?",
    role: "user",
    timestamp: Date.now() - 80000,
  },
  {
    id: "10",
    text: "Absolutely! There's built-in streaming support:\n\n• isStreaming prop shows a stop button\n• onStop callback to cancel generation\n• The send button transforms into a stop button automatically",
    role: "assistant",
    timestamp: Date.now() - 75000,
  },
  {
    id: "11",
    text: "What platforms does it support?",
    role: "user",
    timestamp: Date.now() - 70000,
  },
  {
    id: "12",
    text: "iOS and Android only - no web support. This is intentional because the library relies on native keyboard APIs that don't exist on web.\n\n• iOS 15+\n• Android API 21+\n• Expo SDK 48+",
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
    text: "Simple!\n\npnpm add @launchhq/react-native-keyboard-composer\n\nThen run 'npx expo prebuild' to generate native code. That's it!",
    role: "assistant",
    timestamp: Date.now() - 55000,
  },
  {
    id: "15",
    text: "This is exactly what I needed! 🎉",
    role: "user",
    timestamp: Date.now() - 50000,
  },
  {
    id: "16",
    text: "Happy to help! Try typing a message below to see it in action. The composer will smoothly follow the keyboard. 🚀",
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

  // Debug: log height changes
  const handleHeightChange = useCallback(
    (height: number) => {
      console.log(
        `📐 [JS] Composer height changed: ${composerHeight} -> ${height}, delta=${height - composerHeight}`
      );
      setComposerHeight(height);
    },
    [composerHeight]
  );
  const [scrollTrigger, setScrollTrigger] = useState(0);

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
    setTimeout(() => setScrollTrigger(Date.now()), 100);

    // Simulate assistant response
    setTimeout(() => {
      const responses = [
        "That's interesting! Tell me more.",
        "I see what you mean. The keyboard handling really does make a difference in the user experience.",
        "Great question! This library uses native APIs for the smoothest possible animations.",
        "Thanks for trying out the keyboard composer! 🚀",
      ];
      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        text: responses[Math.floor(Math.random() * responses.length)],
        role: "assistant",
        timestamp: Date.now(),
      };
      setMessages((prev) => [...prev, assistantMessage]);
      setTimeout(() => setScrollTrigger(Date.now()), 100);
    }, 1000);
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
  console.log(`📐 [JS] Rendering with extraBottomInset=${baseBottomInset}`);

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
          Smooth keyboard animations
        </Text>
      </View>

      {/* KeyboardAwareWrapper manages both scroll content AND composer animation */}
      <KeyboardAwareWrapper
        style={styles.chatArea}
        extraBottomInset={baseBottomInset}
        scrollToTopTrigger={scrollTrigger}
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
        <View
          style={[
            styles.composerContainer,
            { paddingBottom: Math.max(insets.bottom, 16) },
          ]}
          pointerEvents="box-none"
        >
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
