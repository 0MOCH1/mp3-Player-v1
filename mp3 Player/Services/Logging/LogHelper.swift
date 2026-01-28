import Foundation
import os.log

/// Simple logging helper for error tracking and debugging
enum LogHelper {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mp3player", category: "app")
    
    /// Format message with optional context
    private static func formatMessage(_ message: String, context: String?) -> String {
        guard let context = context else { return message }
        return "[\(context)] \(message)"
    }
    
    /// Log an error with context
    static func logError(_ message: String, error: Error? = nil, context: String? = nil) {
        let formattedMessage = formatMessage(message, context: context)
        if let error = error {
            logger.error("\(formattedMessage): \(error.localizedDescription)")
        } else {
            logger.error("\(formattedMessage)")
        }
    }
    
    /// Log a warning
    static func logWarning(_ message: String, context: String? = nil) {
        logger.warning("\(formatMessage(message, context: context))")
    }
    
    /// Log info for debugging
    static func logInfo(_ message: String, context: String? = nil) {
        logger.info("\(formatMessage(message, context: context))")
    }
    
    /// Log debug information (only in debug builds)
    static func logDebug(_ message: String, context: String? = nil) {
        #if DEBUG
        logger.debug("\(formatMessage(message, context: context))")
        #endif
    }
}
