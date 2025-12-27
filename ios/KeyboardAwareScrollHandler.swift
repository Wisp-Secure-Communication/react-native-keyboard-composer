import ExpoModulesCore
import UIKit

/// Delegate to notify when scroll position changes
protocol KeyboardAwareScrollHandlerDelegate: AnyObject {
    func scrollHandler(_ handler: KeyboardAwareScrollHandler, didUpdateScrollPosition isAtBottom: Bool)
}

/// Native keyboard handler that directly controls a UIScrollView's contentInset.
/// This bypasses React Native's JS bridge for smooth keyboard animations.
class KeyboardAwareScrollHandler: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    weak var scrollView: UIScrollView?
    weak var delegate: KeyboardAwareScrollHandlerDelegate?
    /// Base inset WITHOUT safe area (composer + gap)
    var baseBottomInset: CGFloat = 64 // 48 + 16
    private var keyboardHeight: CGFloat = 0
    private var wasAtBottom = false
    private var isAtBottom = true
    private var isKeyboardVisible = false  // Track if keyboard is already showing
    
    /// Get safe area bottom from window
    private var safeAreaBottom: CGFloat {
        scrollView?.window?.safeAreaInsets.bottom ?? 34
    }
    
    override init() {
        super.init()
        setupKeyboardObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        contentSizeObservation?.invalidate()
        contentSizeObservation = nil
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let scrollView = scrollView,
              let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }
        
        // Calculate effective keyboard height (keyboard frame is in screen coordinates)
        let screenHeight = UIScreen.main.bounds.height
        let keyboardTop = keyboardFrame.origin.y
        let newKeyboardHeight = max(0, screenHeight - keyboardTop)
        
        #if DEBUG
        NSLog("[ScrollHandler] keyboard show: frame=%.0f newHeight=%.0f wasVisible=%@", 
              keyboardFrame.height, newKeyboardHeight, isKeyboardVisible ? "yes" : "no")
        #endif
        
        // With inputAccessoryView, we get notifications for just the accessory (~90pt)
        // before the actual keyboard shows (~300+pt). Only treat it as "initial show"
        // when we go from no keyboard to actual keyboard (not just accessory)
        let minRealKeyboardHeight: CGFloat = 200  // Real keyboards are at least 200pt
        let isRealKeyboard = newKeyboardHeight >= minRealKeyboardHeight
        let wasRealKeyboardVisible = isKeyboardVisible && keyboardHeight >= minRealKeyboardHeight
        let isInitialShow = isRealKeyboard && !wasRealKeyboardVisible
        
        // Check if at bottom BEFORE animation (only on initial real keyboard show)
        if isInitialShow {
            wasAtBottom = isNearBottom(scrollView)
            #if DEBUG
            NSLog("[ScrollHandler] initial keyboard show, wasAtBottom=%@", wasAtBottom ? "yes" : "no")
            #endif
        }
        
        isKeyboardVisible = true
        keyboardHeight = newKeyboardHeight
        
        // Use raw UIView.animate with keyboard's exact animation curve
        let animationOptions = UIView.AnimationOptions(rawValue: curveValue << 16)
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: animationOptions,
            animations: {
                // Update content inset
                self.updateContentInset()
                
                // Scroll to bottom INSIDE animation block - ONLY on initial keyboard show
                if isInitialShow && self.wasAtBottom {
                    let contentHeight = scrollView.contentSize.height
                    let scrollViewHeight = scrollView.bounds.height
                    let bottomInset = scrollView.contentInset.bottom
                    let maxOffset = max(0, contentHeight - scrollViewHeight + bottomInset)
                    scrollView.contentOffset = CGPoint(x: 0, y: maxOffset)
                }
            },
            completion: nil
        )
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }
        
        #if DEBUG
        NSLog("[ScrollHandler] keyboard hide")
        #endif
        
        keyboardHeight = 0
        isKeyboardVisible = false
        
        let animationOptions = UIView.AnimationOptions(rawValue: curveValue << 16)
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: animationOptions,
            animations: {
                self.updateContentInset()
            },
            completion: nil
        )
    }
    
    private func isNearBottom(_ scrollView: UIScrollView) -> Bool {
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let bottomInset = scrollView.contentInset.bottom
        let currentOffset = scrollView.contentOffset.y
        let maxOffset = max(0, contentHeight - scrollViewHeight + bottomInset)
        
        // Consider "at bottom" if within 100pt
        return (maxOffset - currentOffset) < 100
    }
    
    private func updateContentInset(preserveScrollPosition: Bool = false) {
        guard let scrollView = scrollView else { return }
        
        // Save current scroll position if we need to preserve it
        let savedOffset = preserveScrollPosition ? scrollView.contentOffset : nil
        
        let totalInset: CGFloat
        if keyboardHeight > 0 {
            // Keyboard open: keyboardHeight already includes full covered area
            // (keyboard + inputAccessory if present)
            // Add small gap for visual breathing room
            totalInset = keyboardHeight + 8
        } else {
            // Keyboard closed: base (composer) + safe area + gap
            totalInset = baseBottomInset + safeAreaBottom + 8
        }
        
        scrollView.contentInset.bottom = totalInset
        scrollView.verticalScrollIndicatorInsets.bottom = totalInset
        
        // Restore scroll position if needed (prevents visual jump when not at bottom)
        if let savedOffset = savedOffset {
            scrollView.contentOffset = savedOffset
        }
    }
    
    private func scrollToBottom(animated: Bool) {
        guard let scrollView = scrollView else { return }
        
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let bottomInset = scrollView.contentInset.bottom
        let maxOffset = max(0, contentHeight - scrollViewHeight + bottomInset)
        
        scrollView.setContentOffset(CGPoint(x: 0, y: maxOffset), animated: animated)
    }
    
    // MARK: - Public API
    
    private var tapGesture: UITapGestureRecognizer?
    private var contentSizeObservation: NSKeyValueObservation?
    
    func attach(to scrollView: UIScrollView) {
        self.scrollView = scrollView
        scrollView.delegate = self
        
        // Disable automatic content inset adjustment - we manage it ourselves
        scrollView.contentInsetAdjustmentBehavior = .never
        
        updateContentInset()

        // Enable interactive keyboard dismissal via swipe
        scrollView.keyboardDismissMode = .interactive

        // Add tap gesture to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false // Allow other touches to pass through
        tap.delegate = self
        scrollView.addGestureRecognizer(tap)
        tapGesture = tap
        
        // Observe content size changes
        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .old]) { [weak self] scrollView, change in
            guard let self = self else { return }
            // Check position when content size changes
            DispatchQueue.main.async {
                self.checkAndUpdateScrollPosition()
            }
        }
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        checkAndUpdateScrollPosition()
    }
    
    /// Check scroll position and notify delegate if changed
    private func checkAndUpdateScrollPosition() {
        guard let scrollView = scrollView else { return }
        
        // Only show button if content exceeds viewport
        let contentExceedsViewport = scrollView.contentSize.height > scrollView.bounds.height
        
        if !contentExceedsViewport {
            if !isAtBottom {
                isAtBottom = true
                delegate?.scrollHandler(self, didUpdateScrollPosition: true)
            }
            return
        }
        
        let newIsAtBottom = isNearBottom(scrollView)
        if newIsAtBottom != isAtBottom {
            isAtBottom = newIsAtBottom
            delegate?.scrollHandler(self, didUpdateScrollPosition: isAtBottom)
        }
    }
    
    /// Public method to scroll to bottom
    func scrollToBottomAnimated() {
        scrollToBottom(animated: true)
    }
    
    /// Called to recheck position (e.g., after content changes)
    func recheckScrollPosition() {
        checkAndUpdateScrollPosition()
    }
    
    /// Check if user is currently near the bottom of the scroll view
    func isUserNearBottom() -> Bool {
        guard let scrollView = scrollView else { return true }
        return isNearBottom(scrollView)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // Dismiss keyboard by ending editing on the window
        scrollView?.window?.endEditing(true)
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow tap gesture to work alongside scroll gestures
        return true
    }
    
    func setBaseInset(_ inset: CGFloat, preserveScrollPosition: Bool = false) {
        baseBottomInset = inset
        updateContentInset(preserveScrollPosition: preserveScrollPosition)
    }
    
    /// Adjust scroll position when composer grows to keep content visible.
    /// Only adjusts if user is near the bottom (within 100pt).
    func adjustScrollForComposerGrowth(delta: CGFloat) {
        guard let scrollView = scrollView, delta > 0 else { return }
        
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let currentInset = scrollView.contentInset.bottom
        let currentOffset = scrollView.contentOffset.y
        
        // Check if near bottom - only adjust scroll if user is already at/near bottom
        let currentMaxOffset = max(0, contentHeight - scrollViewHeight + currentInset)
        let distanceFromBottom = currentMaxOffset - currentOffset
        let nearBottom = distanceFromBottom < 100
        
        guard nearBottom else {
            return
        }
        
        // Scroll up by the delta amount to compensate for composer growth
        let newOffset = currentOffset + delta
        
        // Clamp to valid range - account for the pending inset increase (delta)
        let bottomInset = currentInset + delta
        let maxOffset = max(0, contentHeight - scrollViewHeight + bottomInset)
        let clampedOffset = max(0, min(newOffset, maxOffset))
        
        // Apply immediately
        scrollView.setContentOffset(CGPoint(x: 0, y: clampedOffset), animated: false)
    }
    
    /// Scroll so that new content appears at the top of the visible area (ChatGPT-style).
    /// This leaves empty space below for the response to stream in.
    /// - Parameter estimatedNewContentHeight: Approximate height of new content to show at top
    func scrollNewContentToTop(estimatedHeight: CGFloat = 100) {
        guard let scrollView = scrollView else { return }
        
        // Small delay to let content layout settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self, let scrollView = self.scrollView else { return }
            
            let contentHeight = scrollView.contentSize.height
            let visibleHeight = scrollView.bounds.height
            let topInset = scrollView.contentInset.top
            
            // Calculate offset to show new content at top:
            // We want the bottom portion of content (new messages) to appear at the top of screen
            // Offset = total content - visible area + top inset + small padding for the message
            let targetOffset = contentHeight - visibleHeight + topInset + estimatedHeight
            
            // Only scroll if content is tall enough
            let minOffset = -topInset
            let offset = max(minOffset, targetOffset)
            
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                scrollView.contentOffset = CGPoint(x: 0, y: offset)
            }
        }
    }
}

