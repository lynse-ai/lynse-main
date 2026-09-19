import Foundation

/// 速度计算管理器
/// 负责管理文件下载速度的计算和监控
class SpeedCalculationManager: SpeedCalculationManagerProtocol {
    
    // MARK: - Singleton
    static let shared = SpeedCalculationManager()
    
    // MARK: - Properties
    
    /// 速度计算映射表
    private var speedCalculationMap: [Int: (startTime: Date, totalBytes: Int)] = [:]
    
    /// 访问锁
    private let speedCalculationLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 重置速度计算
    /// - Parameter fileSN: 文件序列号
    func resetSpeedCalculation(for fileSN: Int) {
        speedCalculationMap[fileSN] = (startTime: Date(), totalBytes: 0)
        NVEasyLogger.info("🚀 [速度计算] 重置文件 \(fileSN) 的速度计算")
    }
    
    /// 更新速度计算
    /// - Parameters:
    ///   - fileSN: 文件序列号
    ///   - dataSize: 数据大小（字节）
    func updateSpeedCalculation(for fileSN: Int, dataSize: Int) {
        guard var calculation = speedCalculationMap[fileSN] else {
            // 如果没有初始化，先初始化
            resetSpeedCalculation(for: fileSN)
            speedCalculationMap[fileSN]?.totalBytes += dataSize
            return
        }
        
        calculation.totalBytes += dataSize
        speedCalculationMap[fileSN] = calculation
        
        // 计算速度（KB/s）
        let elapsedTime = Date().timeIntervalSince(calculation.startTime)
        if elapsedTime > 0 {
            let speedKbps = Int(Double(calculation.totalBytes) / elapsedTime / 1024.0)
            DownloadProgressHelper.sendFileDownloadSpeed(speedKbps: speedKbps)
        }
    }
    
    /// 清理指定文件的速度计算数据
    /// - Parameter fileSN: 文件序列号
    func clearSpeedCalculation(for fileSN: Int) {
        speedCalculationMap.removeValue(forKey: fileSN)
        NVEasyLogger.info("🚀 [速度计算] 清理文件 \(fileSN) 的速度计算数据")
    }
    
    /// 清理所有速度计算数据
    func clearAllSpeedCalculations() {
        speedCalculationMap.removeAll()
        NVEasyLogger.info("🚀 [速度计算] 清理所有速度计算数据")
    }
    
    /// 获取速度计算信息
    /// - Parameter fileSN: 文件序列号
    /// - Returns: 速度计算信息
    func getSpeedCalculationInfo(for fileSN: Int) -> (totalBytes: Int, elapsedTime: TimeInterval, speedKbps: Int)? {
        guard let calculation = speedCalculationMap[fileSN] else {
            return nil
        }
        
        let elapsedTime = Date().timeIntervalSince(calculation.startTime)
        let speedKbps = elapsedTime > 0 ? Int(Double(calculation.totalBytes) / elapsedTime / 1024.0) : 0
        
        return (totalBytes: calculation.totalBytes, elapsedTime: elapsedTime, speedKbps: speedKbps)
    }
    
    /// 获取所有正在计算速度的文件
    /// - Returns: 文件序列号数组
    func getAllCalculatingFiles() -> [Int] {
        return Array(speedCalculationMap.keys)
    }
}
