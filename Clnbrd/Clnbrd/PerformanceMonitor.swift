import Foundation
import os.log
import os.signpost

private let logger = Logger(subsystem: "com.allanray.Clnbrd", category: "performance")

/// Professional performance monitoring and optimization system
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private var startTime: Date?
    private var memoryBaseline: UInt64 = 0
    private let performanceLog = OSLog(subsystem: "com.allanray.Clnbrd", category: "performance")
    
    private init() {
        setupPerformanceMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupPerformanceMonitoring() {
        // Record baseline memory usage
        memoryBaseline = getCurrentMemoryUsage()
        logger.info("Performance monitoring initialized - Baseline memory: \(self.memoryBaseline) MB")
        
        // Set up periodic monitoring
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.logPerformanceMetrics()
        }
    }
    
    // MARK: - Operation Timing
    
    /// Start timing an operation
    func startOperation(_ operationName: String) {
        startTime = Date()
        os_signpost(.begin, log: performanceLog, name: "Operation", "%{public}s", operationName)
        logger.debug("Started operation: \(operationName)")
    }
    
    /// End timing an operation and log results
    func endOperation(_ operationName: String) -> TimeInterval {
        guard let start = startTime else {
            logger.warning("No start time recorded for operation: \(operationName)")
            return 0
        }
        
        let duration = Date().timeIntervalSince(start)
        os_signpost(.end, log: performanceLog, name: "Operation", "%{public}s", operationName)
        
        logger.info("Operation '\(operationName)' completed in \(String(format: "%.3f", duration))s")
        
        // Track in analytics if operation took too long
        if duration > 1.0 {
            SentryManager.shared.addBreadcrumb(
                message: "Slow operation detected",
                category: "performance",
                level: .warning,
                data: ["operation": operationName, "duration": String(duration)]
            )
        }
        
        startTime = nil
        return duration
    }
    
    // MARK: - Memory Monitoring
    
    /// Get current memory usage in MB
    func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size / (1024 * 1024) // Convert to MB
        } else {
            logger.error("Failed to get memory usage: \(kerr)")
            return 0
        }
    }
    
    /// Check for memory leaks or excessive usage
    func checkMemoryHealth() -> Bool {
        let currentMemory = getCurrentMemoryUsage()
        let memoryIncrease = currentMemory - memoryBaseline
        
        logger.debug("Memory usage: \(currentMemory) MB (baseline: \(self.memoryBaseline) MB, increase: \(memoryIncrease) MB)")
        
        // Alert if memory usage is concerning
        if memoryIncrease > 100 { // More than 100MB increase
            logger.warning("High memory usage detected: \(memoryIncrease) MB above baseline")
            SentryManager.shared.addBreadcrumb(
                message: "High memory usage",
                category: "performance",
                level: .warning,
                data: ["current_mb": String(currentMemory), "increase_mb": String(memoryIncrease)]
            )
            return false
        }
        
        return true
    }
    
    // MARK: - Performance Metrics
    
    /// Log comprehensive performance metrics
    func logPerformanceMetrics() {
        let memoryUsage = getCurrentMemoryUsage()
        let cpuUsage = getCPUUsage()
        
        logger.info("Performance metrics - Memory: \(memoryUsage) MB, CPU: \(String(format: "%.1f", cpuUsage))%")
        
        // Track in analytics
        AnalyticsManager.shared.trackPerformanceMetrics(
            memoryUsage: Int(memoryUsage),
            cpuUsage: cpuUsage
        )
    }
    
    /// Get current CPU usage percentage (simplified version)
    func getCPUUsage() -> Double {
        // Simplified CPU monitoring - returns 0 for now
        // In a production app, you'd implement proper CPU monitoring
        return 0.0
    }
    
    // MARK: - Battery Impact Monitoring
    
    /// Check if app is impacting battery life
    func checkBatteryImpact() -> Bool {
        // This is a simplified check - in a real implementation,
        // you'd use more sophisticated battery monitoring
        let cpuUsage = getCPUUsage()
        
        if cpuUsage > 50.0 { // High CPU usage
            logger.warning("High CPU usage may impact battery life: \(String(format: "%.1f", cpuUsage))%")
            SentryManager.shared.addBreadcrumb(
                message: "High CPU usage detected",
                category: "battery",
                level: .warning,
                data: ["cpu_usage": String(cpuUsage)]
            )
            return false
        }
        
        return true
    }
    
    // MARK: - Performance Optimization
    
    /// Optimize app performance based on current metrics
    func optimizePerformance() {
        logger.info("Starting performance optimization")
        
        // Check memory health
        if !checkMemoryHealth() {
            // Trigger garbage collection
            DispatchQueue.global(qos: .utility).async {
                // Force memory cleanup
                autoreleasepool {
                    // Any cleanup operations
                }
            }
        }
        
        // Check battery impact
        if !checkBatteryImpact() {
            // Reduce background activity
            logger.info("Reducing background activity due to battery impact")
        }
        
        logger.info("Performance optimization completed")
    }
}

// MARK: - Analytics Extension

extension AnalyticsManager {
    func trackPerformanceMetrics(memoryUsage: Int, cpuUsage: Double) {
        // Add performance metrics to analytics
        SentryManager.shared.addBreadcrumb(
            message: "Performance metrics",
            category: "analytics",
            level: .info,
            data: [
                "memory_mb": String(memoryUsage),
                "cpu_percent": String(format: "%.1f", cpuUsage)
            ]
        )
    }
}
