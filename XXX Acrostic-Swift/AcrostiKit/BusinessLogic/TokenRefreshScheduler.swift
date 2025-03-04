// NactionsKit/BusinessLogic/TokenRefreshScheduler.swift
import Foundation
import BackgroundTasks

public final class TokenRefreshScheduler {
    public static let shared = TokenRefreshScheduler()
    public let taskIdentifier = "com.nactions.tokenRefresh"
    
    private init() {}
    
    /// Register/initialize the background refresh mechanism
    public func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleiOSBackgroundTask(task: task as! BGAppRefreshTask)
        }
        print("✅ Registered background task with identifier: \(taskIdentifier)")
    }

    /// Schedule the background task
    public func scheduleTokenRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 15) // Run every 15 min
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Token refresh scheduled (iOS).")
        } catch {
            print("⚠️ Failed to schedule token refresh: \(error.localizedDescription)")
            // Make debugging easier by checking if the task identifier is registered
            if let bgError = error as NSError? {
                if bgError.domain == "BGTaskSchedulerErrorDomain" && bgError.code == 3 {
                    print("Error code 3 indicates the identifier wasn't registered. Make sure to call registerBackgroundTask() first and check Info.plist for BGTaskSchedulerPermittedIdentifiers.")
                }
            }
        }
    }
    
    /// Execute token refresh in the background for iOS
    private func handleiOSBackgroundTask(task: BGAppRefreshTask) {
        let taskID = UUID() // For keeping track of the task
        print("⚙️ Beginning background task: \(taskID)")
        
        // Create an expiration handler
        task.expirationHandler = {
            print("⏱ Task \(taskID) expired before completion")
        }
        
        Task {
            await refreshTokensWithRetry()
            scheduleTokenRefresh() // Re-schedule next refresh
            task.setTaskCompleted(success: true)
            print("✅ Background task \(taskID) completed successfully")
        }
    }
    
    /// Shared token refresh logic with retry capability
        private func refreshTokensWithRetry() async {
            let invalidTokens = await TokenDataController.shared.validateAllTokens()
            
            // Log any invalid tokens
            if !invalidTokens.isEmpty {
                print("Found \(invalidTokens.count) invalid tokens during refresh")
            }
            
            // In a real implementation, you would add retry logic here
            // This is a simplified version
        }
}
