import ExpoModulesCore
import UIKit

// MARK: - Input Accessory Host Controller

/// Controller that hosts the composer as an inputAccessoryView.
/// This provides proper interactive dismiss - dragging on the composer dismisses the keyboard.
class InputAccessoryHostController: UIViewController {
    
    private let accessoryContainer = InputAccessoryContainerView()
    
    override var canBecomeFirstResponder: Bool { true }
    
    override var inputAccessoryView: UIView? { accessoryContainer }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }
    
    /// Set the composer view to be displayed in the input accessory
    func setComposerView(_ composer: UIView) {
        accessoryContainer.setComposer(composer)
    }
    
    /// Update the accessory height when composer size changes
    func updateHeight() {
        accessoryContainer.invalidateIntrinsicContentSize()
    }
}

// MARK: - Input Accessory Container View

/// Container view for the composer that provides proper intrinsic content size
/// Handles safe area insets and keyboard gap padding
class InputAccessoryContainerView: UIView {
    
    private weak var composerView: UIView?
    
    // Padding between composer and keyboard
    private let keyboardGap: CGFloat = 8
    // Minimum padding at bottom when keyboard is closed (in addition to safe area)
    private let bottomPadding: CGFloat = 8
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        autoresizingMask = .flexibleHeight
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setComposer(_ composer: UIView) {
        // Remove old composer if any
        composerView?.removeFromSuperview()
        
        // Add new composer
        composerView = composer
        addSubview(composer)
        
        invalidateIntrinsicContentSize()
    }
    
    override var intrinsicContentSize: CGSize {
        let composerHeight = composerView?.bounds.height ?? 48
        // Include safe area at bottom + padding + keyboard gap
        let safeBottom = safeAreaInsets.bottom
        // When keyboard is closed: safe area + bottom padding
        // When keyboard is open: keyboard gap (safe area will be 0 above keyboard)
        let bottomSpace = max(safeBottom + bottomPadding, keyboardGap)
        let totalHeight = composerHeight + bottomSpace
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let composer = composerView else { return }
        
        // Position composer at top, leaving space at bottom for safe area/keyboard gap
        composer.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: composer.bounds.height
        )
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Forward all touches to children
        let result = super.hitTest(point, with: event)
        return result == self ? nil : result
    }
    
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}

// MARK: - Keyboard Aware Wrapper

/// A native wrapper view that finds UIScrollView children and attaches keyboard handling.
/// Uses inputAccessoryView pattern for proper interactive dismiss support.
class KeyboardAwareWrapper: ExpoView, KeyboardAwareScrollHandlerDelegate {
    private let keyboardHandler = KeyboardAwareScrollHandler()
    private var hasAttached = false
    private var scrollToBottomButton: UIButton?
    private var isScrollButtonVisible = false
    private var isAnimatingScrollButton = false
    private var currentKeyboardHeight: CGFloat = 0
    private var isKeyboardOpen = false
    
    // Input accessory controller for proper keyboard attachment
    private var accessoryController: InputAccessoryHostController?
    private var isUsingInputAccessory = false
    private weak var originalComposerSuperview: UIView?
    private var originalComposerIndex: Int = 0
    
    // Composer handling
    private weak var composerContainer: UIView?
    private weak var composerView: UIView?
    private var safeAreaBottom: CGFloat = 0
    
    // Track composer height to detect changes
    private var lastComposerHeight: CGFloat = 0
    
    // Constants matching Android
    private let CONTENT_GAP: CGFloat = 24
    private let COMPOSER_KEYBOARD_GAP: CGFloat = 10
    private let MIN_BOTTOM_PADDING: CGFloat = 16
    
    // KVO observations
    private var extraBottomInsetObservation: NSKeyValueObservation?
    private var scrollToTopTriggerObservation: NSKeyValueObservation?
    
    // Base inset: composer height only (from JS)
    @objc dynamic var extraBottomInset: CGFloat = 48
    
    /// Trigger scroll to top when this value changes (use timestamp/counter from JS)
    @objc dynamic var scrollToTopTrigger: Double = 0
    
    required init(appContext: AppContext? = nil) {
        super.init(appContext: appContext)
        keyboardHandler.delegate = self
        setupScrollToBottomButton()
        setupKeyboardObservers()
        setupPropertyObservers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        extraBottomInsetObservation?.invalidate()
        scrollToTopTriggerObservation?.invalidate()
        
        // Restore composer to original parent if needed
        restoreComposerFromAccessory()
        accessoryController?.resignFirstResponder()
    }
    
    // MARK: - Property Observers (KVO)
    
    /// Set up KVO observers for properties that need side effects when changed.
    /// This is necessary because React Native/Expo sets props via Objective-C KVC,
    /// which bypasses Swift's didSet observers.
    private func setupPropertyObservers() {
        extraBottomInsetObservation = observe(\.extraBottomInset, options: [.old, .new]) { [weak self] _, change in
            guard let self = self,
                  let oldValue = change.oldValue,
                  let newValue = change.newValue,
                  oldValue != newValue else { return }
            
            let delta = newValue - oldValue
            
            // When composer grows (delta > 0), scroll content up to keep last message visible
            // Do this BEFORE updating insets so we can scroll properly
            if delta > 0 {
                self.keyboardHandler.adjustScrollForComposerGrowth(delta: delta)
            }
            
            // Note: scroll handler adds safeAreaBottom internally when keyboard is closed
            self.keyboardHandler.setBaseInset(newValue + self.CONTENT_GAP)
            self.updateScrollButtonBasePosition()
        }
        
        scrollToTopTriggerObservation = observe(\.scrollToTopTrigger, options: [.new]) { [weak self] _, change in
            guard let self = self,
                  let newValue = change.newValue,
                  newValue > 0 else { return }
            
            self.keyboardHandler.scrollNewContentToTop(estimatedHeight: 100)
        }
    }
    
    // MARK: - Keyboard Observers
    
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        handleKeyboardChange(notification: notification, isShowing: true)
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        handleKeyboardChange(notification: notification, isShowing: false)
    }
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        // Track keyboard height changes for scroll button
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let screenHeight = UIScreen.main.bounds.height
        let keyboardTop = keyboardFrame.origin.y
        currentKeyboardHeight = max(0, screenHeight - keyboardTop)
        
        // Update scroll button position (composer is handled by inputAccessoryView)
        updateScrollButtonTransform()
    }
    
    private func handleKeyboardChange(notification: Notification, isShowing: Bool) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        
        isKeyboardOpen = isShowing
        currentKeyboardHeight = isShowing ? keyboardFrame.height : 0
        
        #if DEBUG
        NSLog("[KeyboardWrapper] keyboard %@ height=%.0f accessory=%@", 
              isShowing ? "show" : "hide", currentKeyboardHeight, 
              isUsingInputAccessory ? "yes" : "no")
        #endif
        
        // Animate scroll button (composer is handled by inputAccessoryView)
        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.updateScrollButtonTransform()
        }
    }
    
    // MARK: - Input Accessory Management
    
    /// Move composer into inputAccessoryView for proper keyboard attachment
    private func setupInputAccessory() {
        guard !isUsingInputAccessory else { return }
        guard let composer = composerView, let container = composerContainer else { return }
        
        // Store original parent info for restoration
        originalComposerSuperview = container.superview
        if let parent = originalComposerSuperview {
            originalComposerIndex = parent.subviews.firstIndex(of: container) ?? 0
        }
        
        // Create and setup accessory controller
        let controller = InputAccessoryHostController()
        accessoryController = controller
        
        // Add controller's view (invisible) to our hierarchy
        controller.view.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0)
        addSubview(controller.view)
        
        // Move the composer container to the input accessory
        container.removeFromSuperview()
        controller.setComposerView(container)
        
        // Become first responder to show the accessory
        controller.becomeFirstResponder()
        
        isUsingInputAccessory = true
        
        #if DEBUG
        NSLog("[KeyboardWrapper] moved composer to inputAccessoryView")
        #endif
    }
    
    /// Restore composer from inputAccessoryView back to React Native hierarchy
    private func restoreComposerFromAccessory() {
        guard isUsingInputAccessory else { return }
        guard let container = composerContainer else { return }
        
        // Remove from accessory
        container.removeFromSuperview()
        
        // Restore to original parent
        if let parent = originalComposerSuperview {
            parent.insertSubview(container, at: originalComposerIndex)
        }
        
        // Clean up controller
        accessoryController?.view.removeFromSuperview()
        accessoryController?.resignFirstResponder()
        accessoryController = nil
        
        isUsingInputAccessory = false
        
        #if DEBUG
        NSLog("[KeyboardWrapper] restored composer from inputAccessoryView")
        #endif
    }
    
    
    // MARK: - Scroll to Bottom Button
    
    private var buttonBottomConstraint: NSLayoutConstraint?
    
    private func setupScrollToBottomButton() {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure button appearance - use arrow.down for clearer visual
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let arrowImage = UIImage(systemName: "arrow.down", withConfiguration: config)
        button.setImage(arrowImage, for: .normal)
        button.tintColor = UIColor.label
        
        // Style the button
        button.backgroundColor = UIColor.systemBackground
        button.layer.cornerRadius = 16
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.15
        button.layer.shadowRadius = 4
        
        // Add action
        button.addTarget(self, action: #selector(scrollToBottomTapped), for: .touchUpInside)
        
        // Initially hidden
        button.alpha = 0
        button.isHidden = true
        
        addSubview(button)
        scrollToBottomButton = button
        
        // Constraints - base position at bottom, we'll use transform for keyboard animation
        let bottomConstraint = button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -calculateBaseButtonOffset())
        buttonBottomConstraint = bottomConstraint
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            bottomConstraint
        ])
    }
    
    /// Base button offset (when keyboard is closed) - used for constraint
    private func calculateBaseButtonOffset() -> CGFloat {
        let composerHeight = lastComposerHeight > 0 ? lastComposerHeight : extraBottomInset
        // Button sits just above the composer
        // Since composer is transformed up by (safeAreaBottom or minPadding), 
        // button needs same offset + composer height + gap
        let bottomOffset = max(safeAreaBottom, MIN_BOTTOM_PADDING)
        let buttonGap: CGFloat = 8
        return bottomOffset + composerHeight + buttonGap
    }
    
    /// Update button transform to animate with keyboard (called inside animation block)
    private func updateScrollButtonTransform() {
        // Don't update transform during show/hide animation
        guard !isAnimatingScrollButton else { return }
        guard let button = scrollToBottomButton else { return }
        
        // Calculate how much to translate the button up when keyboard is open
        let effectiveKeyboard = max(currentKeyboardHeight - safeAreaBottom, 0)
        
        if effectiveKeyboard > 0 {
            // Keyboard is open - translate up by keyboard height + gap
            let translation = -(effectiveKeyboard + COMPOSER_KEYBOARD_GAP)
            button.transform = CGAffineTransform(translationX: 0, y: translation)
        } else {
            // Keyboard closed - no transform needed
            button.transform = .identity
        }
    }
    
    /// Get the current keyboard transform for the button
    private func currentButtonKeyboardTransform() -> CGAffineTransform {
        let effectiveKeyboard = max(currentKeyboardHeight - safeAreaBottom, 0)
        if effectiveKeyboard > 0 {
            let translation = -(effectiveKeyboard + COMPOSER_KEYBOARD_GAP)
            return CGAffineTransform(translationX: 0, y: translation)
        }
        return .identity
    }
    
    /// Update button's base constraint when composer height changes (outside animation)
    private func updateScrollButtonBasePosition() {
        buttonBottomConstraint?.constant = -calculateBaseButtonOffset()
    }
    
    @objc private func scrollToBottomTapped() {
        keyboardHandler.scrollToBottomAnimated()
    }
    
    private func showScrollButton() {
        guard !isScrollButtonVisible else { return }
        isScrollButtonVisible = true
        isAnimatingScrollButton = true
        
        guard let button = scrollToBottomButton else {
            isAnimatingScrollButton = false
            return
        }
        
        // Get the final keyboard transform
        let keyboardTransform = currentButtonKeyboardTransform()
        
        // Start 12pt below final position + faded out
        button.isHidden = false
        button.alpha = 0
        button.transform = keyboardTransform.concatenating(CGAffineTransform(translationX: 0, y: 12))
        
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            button.alpha = 1
            button.transform = keyboardTransform  // Final position
        } completion: { _ in
            self.isAnimatingScrollButton = false
        }
    }
    
    private func hideScrollButton() {
        guard isScrollButtonVisible else { return }
        isScrollButtonVisible = false
        isAnimatingScrollButton = true
        
        guard let button = scrollToBottomButton else {
            isAnimatingScrollButton = false
            return
        }
        
        // Get current keyboard transform (our starting point)
        let keyboardTransform = currentButtonKeyboardTransform()
        
        // Animate 12pt down from current position + fade out
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: .curveEaseIn
        ) {
            button.alpha = 0
            button.transform = keyboardTransform.concatenating(CGAffineTransform(translationX: 0, y: 12))
        } completion: { _ in
            button.isHidden = true
            // Reset to correct keyboard position for next show
            button.transform = keyboardTransform
            self.isAnimatingScrollButton = false
        }
    }
    
    // MARK: - KeyboardAwareScrollHandlerDelegate
    
    func scrollHandler(_ handler: KeyboardAwareScrollHandler, didUpdateScrollPosition isAtBottom: Bool) {
        DispatchQueue.main.async {
            if isAtBottom {
                self.hideScrollButton()
            } else {
                self.showScrollButton()
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update safe area
        safeAreaBottom = window?.safeAreaInsets.bottom ?? 34
        
        // Re-find composer if lost (weak reference might have been cleared)
        if composerView == nil || composerContainer == nil {
            if let comp = findComposerView(in: self) {
                composerView = comp
                var container: UIView? = comp
                while let parent = container?.superview, parent !== self {
                    container = parent
                }
                composerContainer = container
            }
        }
        
        // Detect composer height changes from actual KeyboardComposerView frame
        if let composer = composerView {
            let currentHeight = composer.bounds.height
            if currentHeight > 0 && abs(currentHeight - lastComposerHeight) > 0.5 {
                let delta = currentHeight - lastComposerHeight
                
                // Update insets and scroll position
                handleComposerHeightChange(newHeight: currentHeight, delta: delta)
                lastComposerHeight = currentHeight
                
                // Update accessory height if using input accessory
                accessoryController?.updateHeight()
            }
        }
        
        // Update scroll button position
        updateScrollButtonBasePosition()
        updateScrollButtonTransform()
        
        // Bring button to front
        if let button = scrollToBottomButton {
            bringSubviewToFront(button)
        }
        
        // Find and attach to scroll view and composer (only once)
        if !hasAttached {
            DispatchQueue.main.async { [weak self] in
                self?.findAndAttachViews()
            }
        }
    }
    
    /// Handle composer height changes detected from frame
    private func handleComposerHeightChange(newHeight: CGFloat, delta: CGFloat) {
        // Check if user is near bottom before making changes
        let isNearBottom = keyboardHandler.isUserNearBottom()
        
        #if DEBUG
        NSLog("[KeyboardWrapper] composer height=%.0f delta=%.0f atBottom=%@", newHeight, delta, isNearBottom ? "yes" : "no")
        #endif
        
        if delta > 0 && isNearBottom {
            // When composer grows AND user is at bottom, scroll content up to keep last message visible
            keyboardHandler.adjustScrollForComposerGrowth(delta: delta)
        }
        
        // Update base inset with new composer height
        // Preserve scroll position if user is NOT at bottom (prevents visual jump)
        keyboardHandler.setBaseInset(newHeight + CONTENT_GAP, preserveScrollPosition: !isNearBottom)
    }
    
    private func findAndAttachViews() {
        guard !hasAttached else { return }
        
        let scrollView = findScrollView(in: self)
        let composer = findComposerView(in: self)
        
        if let sv = scrollView {
            // Use actual composer view height if available
            let composerHeight = composerView?.bounds.height ?? extraBottomInset
            let baseInset = composerHeight + CONTENT_GAP
            
            keyboardHandler.setBaseInset(baseInset)
            keyboardHandler.attach(to: sv)
            hasAttached = true
            #if DEBUG
            NSLog("[KeyboardWrapper] attached scrollView=%@", String(describing: type(of: sv)))
            #endif
        }
        
        // Find composer view and container
        if let comp = composer {
            composerView = comp
            
            var container: UIView? = comp
            while let parent = container?.superview, parent !== self {
                container = parent
            }
            composerContainer = container
            
            lastComposerHeight = comp.bounds.height
            
            // Setup input accessory for proper interactive dismiss
            setupInputAccessory()
        }
        
        // Retry if views not found
        if scrollView == nil || composer == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.findAndAttachViews()
            }
        }
    }
    
    /// Recursively find UIScrollView in view hierarchy
    private func findScrollView(in view: UIView) -> UIScrollView? {
        // Check if this view is a scroll view
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        
        // Search children
        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }
        
        return nil
    }
    
    /// Recursively find KeyboardComposerView in view hierarchy
    private func findComposerView(in view: UIView) -> UIView? {
        // Check if this view is a KeyboardComposerView
        if type(of: view) == KeyboardComposerView.self {
            return view
        }
        
        // Search children
        for subview in view.subviews {
            if let composer = findComposerView(in: subview) {
                return composer
            }
        }
        
        return nil
    }
    
    // MARK: - React Native Subview Management
    
    override func insertReactSubview(_ subview: UIView!, at atIndex: Int) {
        super.insertReactSubview(subview, at: atIndex)
        // Note: Don't reset hasAttached or composerContainer here
        // React calls this frequently during layout, resetting would lose our references
        setNeedsLayout()
    }
    
    // MARK: - Public API for JS
    
    /// Scroll so new content appears at top (ChatGPT-style)
    func scrollNewContentToTop(estimatedHeight: CGFloat) {
        keyboardHandler.scrollNewContentToTop(estimatedHeight: estimatedHeight)
    }
}


