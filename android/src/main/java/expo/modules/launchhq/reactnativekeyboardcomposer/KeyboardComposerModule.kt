package expo.modules.launchhq.reactnativekeyboardcomposer

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

/**
 * Expo module for KeyboardComposer.
 */
class KeyboardComposerModule : Module() {

    override fun definition() = ModuleDefinition {
        Name("KeyboardComposer")

        // KeyboardComposerView
        View(KeyboardComposerView::class) {
            Prop("isCustomMode") { view: KeyboardComposerView, value: Boolean? ->
                view.isCustomMode = value ?: false
            }

            Prop("placeholder") { view: KeyboardComposerView, value: String? ->
                value?.let { view.placeholderText = it }
            }

            Prop("minHeight") { view: KeyboardComposerView, value: Float? ->
                value?.let { view.minHeightDp = it }
            }

            Prop("maxHeight") { view: KeyboardComposerView, value: Float? ->
                value?.let { view.maxHeightDp = it }
            }

            Prop("sendButtonEnabled") { view: KeyboardComposerView, value: Boolean? ->
                view.sendButtonEnabled = value ?: true
            }

            Prop("editable") { view: KeyboardComposerView, value: Boolean? ->
                view.editable = value ?: true
            }

            Prop("autoFocus") { view: KeyboardComposerView, value: Boolean? ->
                view.autoFocus = value ?: false
            }

            Prop("blurTrigger") { view: KeyboardComposerView, value: Double? ->
                if (value != null && value > 0) {
                    view.blur()
                }
            }

            Prop("isStreaming") { view: KeyboardComposerView, value: Boolean? ->
                view.isStreaming = value ?: false
            }

            Prop("showPTTButton") { view: KeyboardComposerView, value: Boolean? ->
                view.showPTTButton = value ?: false
            }

            Prop("pttEnabled") { view: KeyboardComposerView, value: Boolean? ->
                view.pttEnabled = value ?: true
            }

            Prop("pttState") { view: KeyboardComposerView, value: String? ->
                value?.let { view.pttState = it }
            }

            Prop("pttPressedScale") { view: KeyboardComposerView, value: Float? ->
                value?.let { view.pttPressedScale = it }
            }

            Prop("pttPressedOpacity") { view: KeyboardComposerView, value: Float? ->
                value?.let { view.pttPressedOpacity = it }
            }

            Events(
                "onChangeText",
                "onSend",
                "onStop",
                "onHeightChange",
                "onKeyboardHeightChange",
                "onComposerFocus",
                "onComposerBlur",
                "onPTTPress",
                "onPTTPressIn",
                "onPTTPressOut"
            )
        }

        // KeyboardAwareWrapper
        // Auto-named as "KeyboardComposer_KeyboardAwareWrapper"
        View(KeyboardAwareWrapper::class) {
            Prop("extraBottomInset") { view: KeyboardAwareWrapper, value: Float? ->
                value?.let { view.extraBottomInset = it }
            }

            Prop("blurUnderlap") { view: KeyboardAwareWrapper, value: Float? ->
                value?.let { view.blurUnderlap = it }
            }

            Prop("scrollToTopTrigger") { view: KeyboardAwareWrapper, value: Double? ->
                value?.let { view.scrollToTopTrigger = it }
            }
        }
    }
}
