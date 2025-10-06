import Cocoa
import os.log

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "game")

class PianoGameView: NSView {
    // Game state
    private var keys: [Bool] = [] // true = white, false = black
    private var ballPosition: Int = 0
    private var score: Int = 0
    private var level: Int = 1
    private var gameActive: Bool = false
    private var isFlashing: Bool = false
    
    // UI properties
    private let keyCount: Int = 8
    private let keyWidth: CGFloat = 60
    private let keyHeight: CGFloat = 160  // Double the original 80
    private let ballSize: CGFloat = 30
    
    // Labels
    private var scoreLabel: NSTextField!
    private var levelLabel: NSTextField!
    private var messageLabel: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        startNewRound()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        startNewRound()
    }
    
    func setupUI() {
        // Score label
        scoreLabel = NSTextField(labelWithString: "Score: 0")
        scoreLabel.font = NSFont.boldSystemFont(ofSize: 18)
        scoreLabel.textColor = .labelColor
        scoreLabel.frame = CGRect(x: 20, y: frame.height - 40, width: 150, height: 25)
        addSubview(scoreLabel)
        
        // Level label
        levelLabel = NSTextField(labelWithString: "Level: 1")
        levelLabel.font = NSFont.boldSystemFont(ofSize: 18)
        levelLabel.textColor = .labelColor
        levelLabel.frame = CGRect(x: 200, y: frame.height - 40, width: 150, height: 25)
        addSubview(levelLabel)
        
        // Message label
        messageLabel = NSTextField(labelWithString: "Count spaces to white key and press that number!")
        messageLabel.font = NSFont.systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.alignment = .center
        messageLabel.frame = CGRect(x: 20, y: 20, width: frame.width - 40, height: 40)
        addSubview(messageLabel)
        
        gameActive = true
    }
    
    func startNewRound() {
        // Generate pattern: 7 black keys + 1 white key
        keys = Array(repeating: false, count: keyCount)
        
        // Generate white key position (but never on the ball - distance can't be 0)
        var whiteKeyPosition: Int
        repeat {
            whiteKeyPosition = Int.random(in: 0..<keyCount)
        } while whiteKeyPosition == ballPosition
        
        keys[whiteKeyPosition] = true
        
        // Ball stays where it is (don't randomize position)
        // This keeps the ball at the last position the player chose
        
        needsDisplay = true
        logger.info("New round: ball at \(self.ballPosition), white key at \(whiteKeyPosition), distance: \(abs(whiteKeyPosition - self.ballPosition))")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Background
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        
        // Draw piano keys at top - bundled together as one unit
        let startX = (bounds.width - CGFloat(keyCount) * keyWidth) / 2
        let keyY = bounds.height - keyHeight - 60
        let cornerRadius: CGFloat = 30
        
        // First, draw the overall rounded container background
        let containerRect = CGRect(x: startX, y: keyY, width: CGFloat(keyCount) * keyWidth, height: keyHeight)
        let containerPath = NSBezierPath(roundedRect: containerRect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        // Fill with black as base (we'll draw white key on top)
        NSColor.black.setFill()
        containerPath.fill()
        
        // Now draw individual keys on top
        for i in 0..<keyCount {
            let keyRect = CGRect(x: startX + CGFloat(i) * keyWidth,
                                y: keyY,
                                width: keyWidth,
                                height: keyHeight)
            
            // Only draw white key if it's white (or orange during flash)
            if keys[i] || isFlashing {
                let path = NSBezierPath()
                
                // For first key (leftmost), round top-left and bottom-left corners
                if i == 0 {
                    path.move(to: NSPoint(x: keyRect.minX + cornerRadius, y: keyRect.maxY))
                    
                    path.appendArc(withCenter: NSPoint(x: keyRect.minX + cornerRadius, y: keyRect.maxY - cornerRadius),
                                  radius: cornerRadius,
                                  startAngle: 90,
                                  endAngle: 180,
                                  clockwise: false)
                    
                    path.line(to: NSPoint(x: keyRect.minX, y: keyRect.minY + cornerRadius))
                    
                    path.appendArc(withCenter: NSPoint(x: keyRect.minX + cornerRadius, y: keyRect.minY + cornerRadius),
                                  radius: cornerRadius,
                                  startAngle: 180,
                                  endAngle: 270,
                                  clockwise: false)
                    
                    path.line(to: NSPoint(x: keyRect.maxX, y: keyRect.minY))
                    path.line(to: NSPoint(x: keyRect.maxX, y: keyRect.maxY))
                    path.close()
                }
                // For last key (rightmost), round top-right and bottom-right corners
                else if i == keyCount - 1 {
                    path.move(to: NSPoint(x: keyRect.minX, y: keyRect.maxY))
                    path.line(to: NSPoint(x: keyRect.maxX - cornerRadius, y: keyRect.maxY))
                    
                    path.appendArc(withCenter: NSPoint(x: keyRect.maxX - cornerRadius, y: keyRect.maxY - cornerRadius),
                                  radius: cornerRadius,
                                  startAngle: 90,
                                  endAngle: 0,
                                  clockwise: true)
                    
                    path.line(to: NSPoint(x: keyRect.maxX, y: keyRect.minY + cornerRadius))
                    
                    path.appendArc(withCenter: NSPoint(x: keyRect.maxX - cornerRadius, y: keyRect.minY + cornerRadius),
                                  radius: cornerRadius,
                                  startAngle: 0,
                                  endAngle: 270,
                                  clockwise: true)
                    
                    path.line(to: NSPoint(x: keyRect.minX, y: keyRect.minY))
                    path.close()
                }
                // For middle keys, just draw rectangles
                else {
                    path.appendRect(keyRect)
                }
                
                // Key color
                if isFlashing {
                    NSColor.orange.setFill()
                } else {
                    NSColor.white.setFill()
                }
                
                path.fill()
            }
        }
        
        // Draw divider lines between all keys
        for i in 0..<keyCount - 1 {
            let dividerPath = NSBezierPath()
            let x = startX + CGFloat(i + 1) * keyWidth
            dividerPath.move(to: NSPoint(x: x, y: keyY + keyHeight))
            dividerPath.line(to: NSPoint(x: x, y: keyY))
            
            NSColor(white: 0.4, alpha: 0.5).setStroke()
            dividerPath.lineWidth = 2
            dividerPath.stroke()
        }
        
        // Draw ball (player) - positioned closer to bottom message
        let ballY: CGFloat = 80  // Closer to the message label at y=20
        let ballX = startX + CGFloat(ballPosition) * keyWidth + (keyWidth - ballSize) / 2
        let ballRect = CGRect(x: ballX, y: ballY, width: ballSize, height: ballSize)
        
        let ballPath = NSBezierPath(ovalIn: ballRect)
        NSColor.black.setFill()  // Changed from blue to black
        ballPath.fill()
        
        // Ball border
        NSColor.white.setStroke()
        ballPath.lineWidth = 3
        ballPath.stroke()
    }
    
    func handleKeyPress(_ keyNumber: Int) {
        guard gameActive && keyNumber >= 1 && keyNumber <= keyCount else { return }
        
        // Find the white key
        guard let whiteKeyPosition = keys.firstIndex(of: true) else { return }
        
        // Calculate the CORRECT answer (distance from CURRENT ball position to white key)
        let correctDistance = abs(whiteKeyPosition - ballPosition)
        
        // Check if the player's answer matches the correct distance
        if keyNumber == correctDistance {
            // Correct! Move ball to white key
            ballPosition = whiteKeyPosition
            score += level * 10
            level = min(level + 1, 10)
            
            messageLabel.stringValue = "✅ Correct! +\(level * 10) points"
            messageLabel.textColor = .systemGreen
            
            scoreLabel.stringValue = "Score: \(score)"
            levelLabel.stringValue = "Level: \(level)"
            
            needsDisplay = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startNewRound()
                self?.messageLabel.stringValue = "Count spaces to white key and press that number!"
                self?.messageLabel.textColor = .secondaryLabelColor
            }
        } else {
            // Wrong! Move ball to where they pressed
            ballPosition = keyNumber - 1
            score = 0
            level = 1
            
            messageLabel.stringValue = "❌ Wrong! Answer was \(correctDistance). Score Reset!"
            messageLabel.textColor = .systemRed
            
            scoreLabel.stringValue = "Score: 0"
            levelLabel.stringValue = "Level: 1"
            
            needsDisplay = true
            
            // Flash keys orange once
            flashKeysOrange()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.startNewRound()
                self?.messageLabel.stringValue = "Count spaces to white key and press that number!"
                self?.messageLabel.textColor = .secondaryLabelColor
            }
        }
        
        logger.info("Player pressed \(keyNumber), correct was \(correctDistance), ball at \(self.ballPosition), white at \(whiteKeyPosition), score: \(self.score)")
    }
    
    func flashKeysOrange() {
        // Single orange flash
        isFlashing = true
        needsDisplay = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isFlashing = false
            self?.needsDisplay = true
        }
    }
}

class PianoGameWindow: NSWindow {
    private var gameView: PianoGameView!
    
    init() {
        let windowRect = NSRect(x: 0, y: 0, width: 600, height: 400)
        super.init(contentRect: windowRect,
                  styleMask: [.titled, .closable, .miniaturizable],
                  backing: .buffered,
                  defer: false)
        
        self.title = "Piano Path Game"
        self.center()
        
        gameView = PianoGameView(frame: windowRect)
        self.contentView = gameView
        
        // Handle keyboard input
        self.makeFirstResponder(self)
    }
    
    override func keyDown(with event: NSEvent) {
        if let char = event.characters?.first, let number = Int(String(char)) {
            gameView.handleKeyPress(number)
        } else {
            super.keyDown(with: event)
        }
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

