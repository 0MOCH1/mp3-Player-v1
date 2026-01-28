import Foundation
import os.log

/// Simple logging helper for error tracking and debugging
enum LogHelper {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mp3player", category: "app")
    
    /// Log an error with context
    static func logError(_ message: String, error: Error? = nil, context: String? = nil) {
        if let error = error {
            if let context = context {
                logger.error("[\(context)] \(message): \(error.localizedDescription)")
            } else {
                logger.error("\(message): \(error.localizedDescription)")
            }
        } else {
            if let context = context {
                logger.error("[\(context)] \(message)")
            } else {
                logger.error("\(message)")
            }
        }
    }
    
    /// Log a warning
    static func logWarning(_ message: String, context: String? = nil) {
        if let context = context {
            logger.warning("[\(context)] \(message)")
        } else {
            logger.warning("\(message)")
        }
    }
    
    /// Log info for debugging
    static func logInfo(_ message: String, context: String? = nil) {
        if let context = context {
            logger.info("[\(context)] \(message)")
        } else {
            logger.info("\(message)")
        }
    }
    
    /// Log debug information (only in debug builds)
    static func logDebug(_ message: String, context: String? = nil) {
        #if DEBUG
        if let context = context {
            logger.debug("[\(context)] \(message)")
        } else {
            logger.debug("\(message)")
        }
        #endif
    }
}
