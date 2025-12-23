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
    
    /// Top padding when pinning message (0 = message at very top, hiding all previous)
    private let pinTopPadding: CGFloat = 0
    
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
    
    /// Bottom inset excluding the runway reserve (for accurate "at bottom" calculations)
    private func bottomInsetWithoutReserve(_ scrollView: UIScrollView) -> CGFloat {
        max(0, scrollView.contentInset.bottom - responseReserveInset)
    }
    
    private func isNearBottom(_ scrollView: UIScrollView) -> Bool {
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let bottomInset = bottomInsetWithoutReserve(scrollView)
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
        // Use inset without runway so we scroll to actual content bottom, not blank space
        let bottomInset = bottomInsetWithoutReserve(scrollView)
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
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // If user starts scrolling while runway exists, clear it so they can't get stranded in blank space
        if responseReserveInset > 0 {
            NSLog("[ScrollHandler] User started dragging - clearing runway to prevent blank screen")
            clearResponseReserve(animated: true, force: true)
        }
    }
    
    /// Check scroll position and notify delegate if changed
    private func checkAndUpdateScrollPosition() {
        guard let scrollView = scrollView else { return }
        
        // Calculate visible height for messages (excluding runway reserve)
        let topInset = scrollView.adjustedContentInset.top
        let baseInset = bottomInsetWithoutReserve(scrollView)
        let visibleHeightForMessages = scrollView.bounds.height - topInset - baseInset
        
        // Only show button when actual message content exceeds viewport (not runway)
        let contentExceedsViewport = scrollView.contentSize.height > visibleHeightForMessages + 1
        
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
    /// Shows exactly 2 things: user's new message + runway for AI response
    private func performPinAnimation() {
        guard let scrollView = scrollView else { return }
        
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        
        let viewportH = scrollView.bounds.height
        let topInset = scrollView.adjustedContentInset.top
        
        // Find RN content view reliably
        let contentView = scrollView.subviews.max(by: { $0.bounds.height < $1.bounds.height }) ?? scrollView
        
        // Find all message containers
        let messages = findMessageContainers(in: contentView)
            .sorted { $0.frame.maxY < $1.frame.maxY }
        
        NSLog("[Pin] Found %d message containers. Last 5:", messages.count)
        for (idx, msg) in messages.suffix(5).enumerated() {
            NSLog("[Pin]   [%d] Y=%.0f H=%.0f maxY=%.0f", idx, msg.frame.minY, msg.frame.height, msg.frame.maxY)
        }
        NSLog("[Pin] Old contentSize was: %.0f (new message should be near this Y)", contentSizeAtPinRequest.height)
        
        guard let lastMessage = messages.last else {
            NSLog("[Pin] No messages found")
            return
        }
        
        // Check if we found the RIGHT message (should be near old content size)
        let foundCorrectMessage = lastMessage.frame.minY >= contentSizeAtPinRequest.height - 50
        
        if !foundCorrectMessage {
            NSLog("[Pin] New message not found in view tree yet. Using contentSize-based scroll.")
        }
        
        let messageH = foundCorrectMessage ? lastMessage.bounds.height : CGFloat(60)
        
        // Compute runway: viewport minus (padding + message + typing indicator + buffer)
        let typingIndicatorH: CGFloat = 32
        let bottomBuffer: CGFloat = 16
        
        var reserve = (viewportH - topInset) - (pinTopPadding + messageH + typingIndicatorH + bottomBuffer)
        reserve = max(0, reserve)
        reserve = min(reserve, viewportH)
        
        responseReserveInset = reserve
        updateContentInset()
        
        // Pin the LAST message (user's new message) to the top
        // This hides ALL previous messages
        let messageY = lastMessage.frame.minY
        
        // Log all the values to understand what's happening
        NSLog("[Pin] === DEBUG VALUES ===")
        NSLog("[Pin] scrollView.frame=%@", NSCoder.string(for: scrollView.frame))
        NSLog("[Pin] scrollView.bounds=%@", NSCoder.string(for: scrollView.bounds))
        NSLog("[Pin] adjustedContentInset.top=%.0f bottom=%.0f", scrollView.adjustedContentInset.top, scrollView.adjustedContentInset.bottom)
        NSLog("[Pin] contentInset.top=%.0f bottom=%.0f", scrollView.contentInset.top, scrollView.contentInset.bottom)
        NSLog("[Pin] contentSize=%.0f x %.0f", scrollView.contentSize.width, scrollView.contentSize.height)
        NSLog("[Pin] current contentOffset.y=%.0f", scrollView.contentOffset.y)
        NSLog("[Pin] lastMessage.frame=%@", NSCoder.string(for: lastMessage.frame))
        
        // Scroll to pin the new message at the top
        // If we found the actual message, use its position
        // Otherwise, use the old content size (where new content starts)
        let targetY: CGFloat
        if foundCorrectMessage {
            targetY = messageY - pinTopPadding
        } else {
            // New message starts at approximately old content size minus margin
            let messageMargin: CGFloat = 16
            targetY = contentSizeAtPinRequest.height - messageMargin
            NSLog("[Pin] Using contentSize-based offset: %.0f", targetY)
        }
        
        let contentH = scrollView.contentSize.height
        let minOffset = -topInset
        let maxOffset = max(minOffset, contentH - viewportH + scrollView.contentInset.bottom)
        let clampedY = max(minOffset, min(targetY, maxOffset))
        
        NSLog("[Pin] targetY=%.0f minOffset=%.0f maxOffset=%.0f clampedY=%.0f", targetY, minOffset, maxOffset, clampedY)
        
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 1.0,
            initialSpringVelocity: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            self.updateContentInset()
            scrollView.contentOffset = CGPoint(x: 0, y: clampedY)
        }
    }
    
    /// Find all message container views (not text/paragraph views)
    private func findMessageContainers(in contentView: UIView) -> [UIView] {
        let contentWidth = contentView.bounds.width
        let contentHeight = contentView.bounds.height
        
        func walk(_ view: UIView, depth: Int = 0) -> [UIView] {
            var out: [UIView] = []
            
            for sub in view.subviews {
                guard !sub.isHidden, sub.alpha > 0.01 else { continue }
                
                let cls = String(describing: type(of: sub))
                if cls.contains("ScrollIndicator") { continue }
                if cls.contains("Paragraph") || cls.contains("Text") { continue }
                
                let f = sub.frame
                let reasonable = f.height > 20 && f.width > 40
                let fullWidth = abs(f.width - contentWidth) < 10
                let fullHeight = abs(f.height - contentHeight) < 10
                let atOrigin = f.origin.x == 0 && f.origin.y == 0
                
                if reasonable && !fullWidth && !fullHeight && !atOrigin {
                    out.append(sub)
                } else if depth < 2 {
                    out.append(contentsOf: walk(sub, depth: depth + 1))
                }
            }
            
            return out
        }
        
        return walk(contentView)
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
    /// - Parameters:
    ///   - animated: Whether to animate the inset change
    ///   - force: If true, clears reserve regardless of content size (used when user starts scrolling)
    func clearResponseReserve(animated: Bool = true, force: Bool = false) {
        guard let scrollView = scrollView else { return }
        guard responseReserveInset > 0 else { return }
        
        // Gather metrics for intelligent behavior
        let contentHeight = scrollView.contentSize.height
        let viewportHeight = scrollView.bounds.height
        let topInset = scrollView.adjustedContentInset.top
        let currentBottomInset = scrollView.contentInset.bottom
        let baseInsetWithoutReserve = currentBottomInset - responseReserveInset
        
        // Calculate if content exceeds viewport (accounting for insets)
        let visibleHeight = viewportHeight - topInset - baseInsetWithoutReserve
        let contentExceedsViewport = contentHeight > visibleHeight
        
        NSLog("[clearResponseReserve] force=%@ contentExceedsViewport=%@", force ? "YES" : "NO", contentExceedsViewport ? "YES" : "NO")
        
        // Unless forced, only clear reserve if content is SHORT (fits in viewport)
        if !force && contentExceedsViewport {
            NSLog("[clearResponseReserve] Content exceeds viewport - keeping reserve (not forced)")
            return
        }
        
        NSLog("[clearResponseReserve] Clearing reserve (%.0f)", responseReserveInset)
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

