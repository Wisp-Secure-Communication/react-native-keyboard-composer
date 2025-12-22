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
    
    /// Extra inset reserved for streaming response (ChatGPT-style runway)
    private var responseReserveInset: CGFloat = 0
    
    /// Maximum reserve space (prevents excessive empty space)
    private let maxReserveInset: CGFloat = 520
    
    /// Top padding when pinning message
    private let pinTopPadding: CGFloat = 16
    
    /// Flag: pin-to-top is pending, waiting for content to be added
    private var pendingPinToTop = false
    
    /// Content size when pin was requested (to detect new content)
    private var contentSizeAtPinRequest: CGSize = .zero
    
    /// Flag: waiting for keyboard to hide before pinning
    private var waitingForKeyboardHide = false
    
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
        
        // Also observe keyboardDidHide to know when keyboard is fully hidden
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidHide(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardDidHide(_ notification: Notification) {
        // If we were waiting for keyboard to hide before pinning, now we can proceed
        if waitingForKeyboardHide && pendingPinToTop {
            waitingForKeyboardHide = false
            NSLog("[KeyboardAwareScrollHandler] keyboardDidHide: now checking if content is ready for pin")
            checkAndPerformPinToTop()
        }
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let scrollView = scrollView,
              let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }
        
        let newKeyboardHeight = keyboardFrame.height
        
        // Only do scroll-to-bottom logic on INITIAL keyboard show, not on subsequent height changes
        let isInitialShow = !isKeyboardVisible
        isKeyboardVisible = true
        
        // Check if at bottom BEFORE animation (only on initial show)
        if isInitialShow {
            wasAtBottom = isNearBottom(scrollView)
        }
        keyboardHeight = newKeyboardHeight
        
        // Use raw UIView.animate with keyboard's exact animation curve
        // The curve value (7) is converted to animation options by shifting left 16 bits
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
                    let keyboardOpenPadding: CGFloat = 8
                    let bottomInset = self.baseBottomInset + self.keyboardHeight + keyboardOpenPadding
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
        
        keyboardHeight = 0
        isKeyboardVisible = false  // Reset flag when keyboard hides
        
        // Use raw UIView.animate with keyboard's exact animation curve
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
        
        // The composer's paddingBottom from animatedPaddingStyle:
        // - Keyboard closed: safeAreaBottom + Spacing.sm
        // - Keyboard open: Spacing.sm (8)
        let keyboardOpenPadding: CGFloat = 8  // Spacing.sm from JS
        
        let totalInset: CGFloat
        if keyboardHeight > 0 {
            // Keyboard open: base + keyboard + small padding + reserve
            totalInset = baseBottomInset + keyboardHeight + keyboardOpenPadding + responseReserveInset
        } else {
            // Keyboard closed: base + safe area + reserve
            totalInset = baseBottomInset + safeAreaBottom + responseReserveInset
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
        updateContentInset()
        
        // Add tap gesture to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false // Allow other touches to pass through
        tap.delegate = self
        scrollView.addGestureRecognizer(tap)
        tapGesture = tap
        
        // Observe content size changes
        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new, .old]) { [weak self] scrollView, change in
            guard let self = self else { return }
            
            // Check if content size increased (new content added)
            if let oldSize = change.oldValue, let newSize = change.newValue {
                let contentIncreased = newSize.height > oldSize.height
                
                // If we're pending pin-to-top and content was added, check if ready
                if contentIncreased && self.pendingPinToTop {
                    NSLog("[KeyboardAwareScrollHandler] contentSize increased: %.0f -> %.0f, checking pin conditions", oldSize.height, newSize.height)
                    self.checkAndPerformPinToTop()
                }
            }
            
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
    
    // MARK: - ChatGPT-style Pin to Top with Runway
    
    /// Request pin-to-top. Uses event-driven approach:
    /// 1. Waits for keyboard to hide (via keyboardDidHide notification)
    /// 2. Waits for new content (via contentSize KVO)
    /// Then performs the animation when both conditions are met.
    func pinLatestMessageToTop() {
        NSLog("[KeyboardAwareScrollHandler] *** pinLatestMessageToTop requested ***")
        
        guard let scrollView = scrollView else {
            NSLog("[KeyboardAwareScrollHandler] pinLatestMessageToTop: no scrollView")
            return
        }
        
        // Set flags for event-driven triggering
        pendingPinToTop = true
        contentSizeAtPinRequest = scrollView.contentSize
        
        // Check if keyboard is visible
        if isKeyboardVisible {
            NSLog("[KeyboardAwareScrollHandler] pinLatestMessageToTop: keyboard visible, waiting for keyboardDidHide")
            waitingForKeyboardHide = true
        } else {
            // Keyboard already hidden, check if content is ready
            waitingForKeyboardHide = false
            checkAndPerformPinToTop()
        }
    }
    
    /// Check if all conditions are met to perform pin-to-top.
    /// Called when: contentSize increases OR keyboard did hide
    private func checkAndPerformPinToTop() {
        guard pendingPinToTop else { return }
        guard let scrollView = scrollView else { return }
        
        // Condition 1: Keyboard must be hidden
        if isKeyboardVisible {
            NSLog("[KeyboardAwareScrollHandler] checkAndPerformPinToTop: keyboard still visible")
            return
        }
        
        // Condition 2: New content must be added
        let currentContentSize = scrollView.contentSize
        if currentContentSize.height <= contentSizeAtPinRequest.height {
            NSLog("[KeyboardAwareScrollHandler] checkAndPerformPinToTop: waiting for content (%.0f <= %.0f)", 
                  currentContentSize.height, contentSizeAtPinRequest.height)
            return
        }
        
        // All conditions met!
        NSLog("[KeyboardAwareScrollHandler] checkAndPerformPinToTop: all conditions met, performing animation")
        pendingPinToTop = false
        waitingForKeyboardHide = false
        performPinAnimation()
    }
    
    /// Perform the actual pin-to-top animation (no delays, called when ready)
    private func performPinAnimation() {
        guard let scrollView = scrollView else { return }
        
        // Force layout
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        
        // Find the last message
        guard let contentView = scrollView.subviews.first,
              let lastMessageView = findLastMessageView(in: contentView) else {
            NSLog("[KeyboardAwareScrollHandler] performPinAnimation: no message view found")
            return
        }
        
        // Measurements
        let viewportHeight = scrollView.bounds.height
        let topInset = scrollView.adjustedContentInset.top
        let messageHeight = lastMessageView.bounds.height
        let messageFrameInContent = lastMessageView.convert(lastMessageView.bounds, to: contentView)
        
        NSLog("[KeyboardAwareScrollHandler] performPinAnimation: viewport=%.0f msgH=%.0f msgY=%.0f", 
              viewportHeight, messageHeight, messageFrameInContent.minY)
        
        // Calculate reserve space
        let typingIndicatorHeight: CGFloat = 32
        let bottomBuffer: CGFloat = 16
        var reserve = viewportHeight - pinTopPadding - messageHeight - typingIndicatorHeight - bottomBuffer
        reserve = max(0, min(reserve, maxReserveInset))
        
        // Calculate target scroll offset
        let targetOffset = messageFrameInContent.minY - pinTopPadding
        let clampedOffset = max(-topInset, targetOffset)
        
        NSLog("[KeyboardAwareScrollHandler] performPinAnimation: reserve=%.0f offset=%.0f", reserve, clampedOffset)
        
        // Apply reserve
        responseReserveInset = reserve
        
        // Animate with critically damped spring (no bounce, just smooth)
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.updateContentInset()
            scrollView.contentOffset = CGPoint(x: 0, y: clampedOffset)
        }
    }
    
    /// Debug helper to print view hierarchy
    private func debugPrintViewHierarchy(_ view: UIView, indent: Int = 0) {
        let indentStr = String(repeating: "  ", count: indent)
        let typeName = String(describing: type(of: view))
        NSLog("%@%@ frame=%@ hidden=%@", indentStr, typeName, NSCoder.string(for: view.frame), view.isHidden ? "YES" : "NO")
        
        // Only go 3 levels deep to avoid spam
        if indent < 3 {
            for subview in view.subviews {
                debugPrintViewHierarchy(subview, indent: indent + 1)
            }
        }
    }
    
    /// Clear the response reserve inset (call when streaming is complete or cancelled)
    func clearResponseReserve(animated: Bool = true) {
        guard let scrollView = scrollView else { return }
        guard responseReserveInset > 0 else { return }
        
        // Gather metrics for intelligent behavior
        let contentHeight = scrollView.contentSize.height
        let viewportHeight = scrollView.bounds.height
        let currentOffset = scrollView.contentOffset.y
        let topInset = scrollView.adjustedContentInset.top
        let currentBottomInset = scrollView.contentInset.bottom
        let baseInsetWithoutReserve = currentBottomInset - responseReserveInset
        
        // Calculate if content exceeds viewport (accounting for insets)
        let visibleHeight = viewportHeight - topInset - baseInsetWithoutReserve
        let contentExceedsViewport = contentHeight > visibleHeight
        
        // Calculate max scrollable offset (what "bottom" means)
        let maxOffset = max(-topInset, contentHeight - viewportHeight + baseInsetWithoutReserve)
        let isNearBottom = currentOffset >= maxOffset - 50
        
        NSLog("[clearResponseReserve] === METRICS ===")
        NSLog("[clearResponseReserve] contentHeight=%.0f viewportHeight=%.0f", contentHeight, viewportHeight)
        NSLog("[clearResponseReserve] visibleHeight=%.0f (viewport - topInset - baseInset)", visibleHeight)
        NSLog("[clearResponseReserve] contentExceedsViewport=%@", contentExceedsViewport ? "YES" : "NO")
        NSLog("[clearResponseReserve] currentOffset=%.0f maxOffset=%.0f isNearBottom=%@", currentOffset, maxOffset, isNearBottom ? "YES" : "NO")
        NSLog("[clearResponseReserve] reserveBeingRemoved=%.0f baseInsetWithoutReserve=%.0f", responseReserveInset, baseInsetWithoutReserve)
        
        // Only clear reserve if content is SHORT (fits in viewport)
        // For long content, leave the reserve - user is scrolling manually anyway
        // and the extra bottom space isn't jarring
        if contentExceedsViewport {
            NSLog("[clearResponseReserve] Content exceeds viewport - keeping reserve to avoid snap. User can scroll manually.")
            // Don't clear the reserve - let user scroll naturally
            // The reserve provides extra bottom padding which is fine for long content
            return
        }
        
        // Content is short - clear reserve gently
        NSLog("[clearResponseReserve] Content fits in viewport - clearing reserve")
        responseReserveInset = 0
        
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                self.updateContentInset()
            }
        } else {
            updateContentInset()
        }
    }
    
    /// Get current reserve inset value
    var currentReserveInset: CGFloat {
        return responseReserveInset
    }
    
    /// Find the last message view in the content hierarchy.
    /// This looks for the last view that appears to be a message bubble.
    private func findLastMessageView(in contentView: UIView) -> UIView? {
        // React Native Fabric structure:
        // ScrollView > UIView (content) > RCTViewComponentView (container) > [Message views...]
        // We need to find the actual message bubbles, not the container
        
        let contentWidth = contentView.bounds.width
        let contentHeight = contentView.bounds.height
        
        // Recursively search for message-like views
        func findMessages(in view: UIView, depth: Int = 0) -> [UIView] {
            var messages: [UIView] = []
            
            for subview in view.subviews {
                let frame = subview.frame
                
                // Skip hidden views
                guard !subview.isHidden else { continue }
                
                // Skip scroll indicators
                let className = String(describing: type(of: subview))
                if className.contains("ScrollIndicator") { continue }
                
                // Check if this looks like a message bubble:
                // 1. Not at origin (0, 0) - containers start at origin
                // 2. Not full width - containers span full width
                // 3. Not full height - containers span full content height
                // 4. Reasonable size - height > 20, width > 40
                let isAtOrigin = frame.origin.x == 0 && frame.origin.y == 0
                let isFullWidth = abs(frame.width - contentWidth) < 10
                let isFullHeight = abs(frame.height - contentHeight) < 10
                let hasReasonableSize = frame.height > 20 && frame.width > 40
                
                if !isAtOrigin && !isFullWidth && !isFullHeight && hasReasonableSize {
                    // This looks like a message bubble
                    messages.append(subview)
                } else if depth < 2 {
                    // This might be a container, search inside (limit depth to avoid going too deep)
                    messages.append(contentsOf: findMessages(in: subview, depth: depth + 1))
                }
            }
            
            return messages
        }
        
        let candidateViews = findMessages(in: contentView)
        
        NSLog("[KeyboardAwareScrollHandler] findLastMessageView: found %d candidate messages", candidateViews.count)
        
        // Sort by Y position (bottom-most = latest)
        let sorted = candidateViews.sorted { $0.frame.maxY < $1.frame.maxY }
        
        if let last = sorted.last {
            NSLog("[KeyboardAwareScrollHandler] findLastMessageView: selected view at Y=%.0f H=%.0f", last.frame.origin.y, last.frame.height)
        }
        
        return sorted.last
    }
    
    /// Gradually reduce reserve as content fills in (call during streaming)
    /// - Parameter newContentHeight: Height of new content added since pinning
    func adjustReserveForNewContent(addedHeight: CGFloat) {
        guard responseReserveInset > 0 else { return }
        
        // Reduce reserve by the amount of new content
        let newReserve = max(0, responseReserveInset - addedHeight)
        
        if newReserve != responseReserveInset {
            responseReserveInset = newReserve
            updateContentInset()
            
            #if DEBUG
            NSLog("[KeyboardAwareScrollHandler] adjustReserveForNewContent: added=%.0f newReserve=%.0f", 
                  addedHeight, newReserve)
            #endif
        }
    }
}

