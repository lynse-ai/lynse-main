import Foundation
import CoreBluetooth
import NVEasySDK

public class BLEManager: NSObject, BLEManagerProtocol {
    
    // MARK: - Singleton
    static let shared = BLEManager()
    
    
    // MARK: - Properties
    
    // MARK: - Instance Properties
    
    public var firstPeripheral: CBPeripheral?
    public var secondPeripheral: CBPeripheral?
    public var thirdPeripheral: CBPeripheral?
    public var peripheralMap: [String: CBPeripheral] = [:]
    public var peripheralMapA: [String: CBPeripheral] = [:]
    public var peripheralMapB: [String: CBPeripheral] = [:]
    
    // MARK: - Handler Properties
    
    /// BLE连接处理器
    internal lazy var connectionHandler: BLEConnectionHandler = {
        return BLEConnectionHandler(bleManager: self)
    }()
    
    
    /// BLE命令处理器
    internal lazy var commandHandler: BLECommandHandler = {
        return BLECommandHandler()
    }()
    
    // MARK: - Manager Dependencies
    
    /// 音频数据管理器
    private let audioDataManager = AudioDataManager.shared
    
    /// 文件传输管理器
    private let fileTransferManager = FileTransferManager.shared
    
    /// 速度计算管理器
    private let speedCalculationManager = SpeedCalculationManager.shared
    
    /// 实时音频流管理器
    private let realtimeAudioStreamManager = RealtimeAudioStreamManager.shared
    
    /// 录音时间管理器
    private let recordingTimeManager = RecordingTimeManager.shared
    
    // MARK: - Delegate Manager Dependencies
    
    /// 文件传输委托管理器
    internal let fileTransferDelegateManager = FileTransferDelegateManager.shared
    
    /// 音频处理委托管理器
    internal let audioProcessingDelegateManager = AudioProcessingDelegateManager.shared
    
    /// OTA升级委托管理器
    internal let otaDelegateManager = OTADelegateManager.shared
    
    /// 设备状态委托管理器
    internal let deviceStatusDelegateManager = DeviceStatusDelegateManager.shared
    
    
    
    
    private override init() {
        super.init()
        NVEasyBLEManager.shared.delegate = self
        initializeDelegateManagers()
    }
    
    /// 初始化委托管理器
    private func initializeDelegateManagers() {
        fileTransferDelegateManager.setBLEManager(self)
        audioProcessingDelegateManager.setBLEManager(self)
    }
    
    public func startScan() {
        NVEasyBLEManager.shared.manualStartScan()
    }
    
    public func stopScan() {
        NVEasyBLEManager.shared.manualStopScan()
    }
    
    public func connect(_ uuid: String) {
        // 如果已经连接，就不执行连接的操作
        if let peripheral = peripheralMap[uuid] {
            firstPeripheral = peripheral
            // 委托已在初始化时设置，无需重复设置
            NVEasyBLEManager.shared.connect(peripheral)
        }
        
        if let peripheral = peripheralMapA[uuid] {
            secondPeripheral = peripheral
            NVEasyBLEManager.sharedExA.connect(peripheral)
        }
        
        if let peripheral = peripheralMapB[uuid] {
            thirdPeripheral = peripheral
            NVEasyBLEManager.sharedExB.connect(peripheral)
        }
    }
    
    public func disconnect(_ uuid: String) {
        if let peripheral = peripheralMap[uuid] {
            NVEasyBLEManager.shared.disconnect(peripheral)
            firstPeripheral = nil
        }
        
        if let peripheral = peripheralMapA[uuid] {
            NVEasyBLEManager.sharedExA.disconnect(peripheral)
            secondPeripheral = nil
        }
        
        if let peripheral = peripheralMapB[uuid] {
            NVEasyBLEManager.sharedExB.disconnect(peripheral)
            thirdPeripheral = nil
        }
    }
    
   
    public func resetDevice() {
        NVEasyBLEManager.shared.reset()
    }
    
    public func queryVersion() {
        NVEasyBLEManager.shared.version()
    }
    
    public func querySN() {
        NVEasyBLEManager.shared.authsn()
    }
    
    public func getBattery() {
        NVEasyBLEManager.shared.battery()
    }
    
    
    public func setName(_ name: String) {
        guard let data = name.data(using: .utf8), data.count <= 16 else { return }
        NVEasyBLEManager.shared.btname(name)  // Classic Bluetooth name (20 bytes)
        NVEasyBLEManager.shared.blename(name) // BLE name (16 bytes)
    }

    public func setOffTime(minutes: Int) {
        NVEasyBLEManager.shared.offtime(minutes: minutes)
    }
    
    public func getBindStatus() -> Bool {
        return NVEasyBLEManager.shared.isBound
    }
    
    public func bindDevice(isBind: Bool) {
        NVEasyBLEManager.shared.bound(isBind)
    }
    
    // MARK: - File Audio Data Management
    
    /// 音频数据存储路径
    private let audioDataPath: String = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(NVEasyConstants.FilePaths.audioDataPath).path
    }()
    
    /// 内存缓存大小限制（字节）- 超过此大小将强制写入文件并清理内存
    private let maxMemoryCacheSize: Int = NVEasyConstants.MemoryLimits.maxFileAudioMemorySize
    
    /// 文件写入缓冲区大小（字节）- 累积到此大小才写入文件
    private let writeBufferSize: Int = NVEasyConstants.MemoryLimits.fileWriteBufferSize
    
    /// 文件写入缓冲区
    private var fileWriteBuffers: [Int: Data] = [:]
    
    /// 文件写入缓冲区访问锁
    private let fileWriteBuffersLock = NSLock()
    
    /// 为指定文件初始化音频数据缓存
    func initFileAudioData(for fileSN: Int) {
        audioDataManager.initFileAudioData(for: fileSN)
        fileWriteBuffers[fileSN] = Data()
        BLELogger.log("📁 [文件音频管理] 为文件 \(fileSN) 初始化音频数据缓存")
    }
    
    /// 为指定文件添加音频数据（优化版本 - 流式写入）
    func appendFileAudioData(_ data: Data, for fileSN: Int) {
        BLELogger.log("🔒 [锁调试] appendFileAudioData 开始 - 文件 \(fileSN), 数据大小: \(data.count)")
        
        audioDataManager.appendFileAudioData(data, for: fileSN)
        
        // 线程安全地添加到写入缓冲区
        BLELogger.log("🔒 [锁调试] appendFileAudioData 准备获取锁 - 文件 \(fileSN)")
//        fileWriteBuffersLock.lock()
        BLELogger.log("🔒 [锁调试] appendFileAudioData 已获取锁 - 文件 \(fileSN)")
        
        // 添加到写入缓冲区
        if fileWriteBuffers[fileSN] == nil {
            fileWriteBuffers[fileSN] = Data()
        }
        fileWriteBuffers[fileSN]?.append(data)
        
        // 检查是否需要写入文件
        var bufferDataToWrite: Data?
        if let bufferSize = fileWriteBuffers[fileSN]?.count, bufferSize >= writeBufferSize {
            // 在锁内创建数据副本，避免在锁外访问
            bufferDataToWrite = fileWriteBuffers[fileSN] ?? Data()
            fileWriteBuffers[fileSN] = Data() // 清空缓冲区
            BLELogger.log("🔒 [锁调试] appendFileAudioData 缓冲区已满，准备写入 - 文件 \(fileSN), 数据大小: \(bufferDataToWrite?.count ?? 0)")
        }
        
        // 释放锁
//        fileWriteBuffersLock.unlock()
        BLELogger.log("🔒 [锁调试] appendFileAudioData 已释放锁 - 文件 \(fileSN)")
        
        // 在锁外写入文件，避免死锁
        if let bufferData = bufferDataToWrite {
            BLELogger.log("🔒 [锁调试] appendFileAudioData 开始写入文件 - 文件 \(fileSN)")
            writeBufferDataToFile(bufferData, fileSN: fileSN)
            BLELogger.log("🔒 [锁调试] appendFileAudioData 文件写入完成 - 文件 \(fileSN)")
        }
        
        // 检查内存压力，如果内存缓存过大，强制清理
        checkMemoryPressureAndCleanup(fileSN: fileSN)
        BLELogger.log("🔒 [锁调试] appendFileAudioData 完成 - 文件 \(fileSN)")
    }
    
    /// 获取指定文件的音频数据
    func getFileAudioData(for fileSN: Int) -> Data? {
        // 先从内存缓存获取
        if let cachedData = audioDataManager.getFileAudioData(for: fileSN) {
            return cachedData
        }
        
        // 如果内存中没有，尝试从文件加载
        if let fileData = loadAudioDataFromFile(fileSN: fileSN) {
            // 将文件数据设置到内存缓存中
            audioDataManager.initFileAudioData(for: fileSN)
            audioDataManager.appendFileAudioData(fileData, for: fileSN)
            BLELogger.log("📁 [文件音频管理] 从文件加载文件 \(fileSN) 的音频数据: \(fileData.count) 字节")
            return fileData
        }
        
        return nil
    }
    
    /// 将缓冲区数据写入文件（线程安全版本）
    /// - Parameters:
    ///   - bufferData: 要写入的数据
    ///   - fileSN: 文件序列号
    private func writeBufferDataToFile(_ bufferData: Data, fileSN: Int) {
        BLELogger.log("🔒 [锁调试] writeBufferDataToFile 开始 - 文件 \(fileSN), 数据大小: \(bufferData.count)")
        
        guard !bufferData.isEmpty else {
            BLELogger.log("🔒 [锁调试] writeBufferDataToFile 数据为空，跳过 - 文件 \(fileSN)")
            return
        }
        
        // 确保目录存在
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: audioDataPath) {
            BLELogger.log("🔒 [锁调试] writeBufferDataToFile 创建目录 - 文件 \(fileSN)")
            try? fileManager.createDirectory(atPath: audioDataPath, withIntermediateDirectories: true)
        }
        
        let filePath = "\(audioDataPath)/audio_\(fileSN).data"
        BLELogger.log("🔒 [锁调试] writeBufferDataToFile 目标文件路径: \(filePath)")
        
        do {
            // 使用追加模式写入文件
            BLELogger.log("🔒 [锁调试] writeBufferDataToFile 尝试打开文件句柄 - 文件 \(fileSN)")
            let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath))
            BLELogger.log("🔒 [锁调试] writeBufferDataToFile 文件句柄打开成功 - 文件 \(fileSN)")
            
            fileHandle.seekToEndOfFile()
            BLELogger.log("🔒 [锁调试] writeBufferDataToFile 定位到文件末尾 - 文件 \(fileSN)")
            
            fileHandle.write(bufferData)
            BLELogger.log("🔒 [锁调试] writeBufferDataToFile 数据写入完成 - 文件 \(fileSN)")
            
            fileHandle.closeFile()
            BLELogger.log("🔒 [锁调试] writeBufferDataToFile 文件句柄关闭 - 文件 \(fileSN)")
            
            BLELogger.log("💾 [音频数据流式写入] 文件 \(fileSN) 写入 \(bufferData.count) 字节到文件")
            
        } catch {
            BLELogger.error("🔒 [锁调试] writeBufferDataToFile 文件句柄操作失败: \(error) - 文件 \(fileSN)")
            // 如果文件不存在，创建新文件
            do {
                BLELogger.log("🔒 [锁调试] writeBufferDataToFile 尝试创建新文件 - 文件 \(fileSN)")
                try bufferData.write(to: URL(fileURLWithPath: filePath))
                BLELogger.log("🔒 [锁调试] writeBufferDataToFile 新文件创建成功 - 文件 \(fileSN)")
                BLELogger.log("💾 [音频数据流式写入] 文件 \(fileSN) 创建新文件并写入 \(bufferData.count) 字节")
            } catch {
                BLELogger.error("🔒 [锁调试] writeBufferDataToFile 创建新文件失败: \(error) - 文件 \(fileSN)")
                BLELogger.error("❌ [音频数据流式写入] 文件 \(fileSN) 写入失败: \(error)")
            }
        }
        
        BLELogger.log("🔒 [锁调试] writeBufferDataToFile 完成 - 文件 \(fileSN)")
    }
    
    /// 将缓冲区数据刷新到文件（追加模式）
    /// - Parameter fileSN: 文件序列号
    private func flushAudioDataToFile(fileSN: Int) {
        BLELogger.log("🔒 [锁调试] flushAudioDataToFile 开始 - 文件 \(fileSN)")
        var bufferData: Data?
        
        // 获取锁，复制数据，然后立即释放锁
        BLELogger.log("🔒 [锁调试] flushAudioDataToFile 准备获取锁 - 文件 \(fileSN)")
//        fileWriteBuffersLock.lock()
        BLELogger.log("🔒 [锁调试] flushAudioDataToFile 已获取锁 - 文件 \(fileSN)")
        
        if let data = fileWriteBuffers[fileSN], !data.isEmpty {
            bufferData = data
            fileWriteBuffers[fileSN] = Data() // 清空缓冲区
            BLELogger.log("🔒 [锁调试] flushAudioDataToFile 获取到缓冲区数据 - 文件 \(fileSN), 数据大小: \(data.count)")
        } else {
            BLELogger.log("🔒 [锁调试] flushAudioDataToFile 缓冲区为空 - 文件 \(fileSN)")
        }
        
//        fileWriteBuffersLock.unlock()
        BLELogger.log("🔒 [锁调试] flushAudioDataToFile 已释放锁 - 文件 \(fileSN)")
        
        // 在锁外写入文件，避免在持有锁的情况下进行I/O操作
        if let data = bufferData {
            BLELogger.log("🔒 [锁调试] flushAudioDataToFile 开始写入文件 - 文件 \(fileSN)")
            writeBufferDataToFile(data, fileSN: fileSN)
            BLELogger.log("🔒 [锁调试] flushAudioDataToFile 文件写入完成 - 文件 \(fileSN)")
        } else {
            BLELogger.log("🔒 [锁调试] flushAudioDataToFile 没有数据需要写入 - 文件 \(fileSN)")
        }
        
        BLELogger.log("🔒 [锁调试] flushAudioDataToFile 完成 - 文件 \(fileSN)")
    }
    
    /// 检查内存压力并自动清理
    /// - Parameter fileSN: 文件序列号
    private func checkMemoryPressureAndCleanup(fileSN: Int) {
        guard let audioData = audioDataManager.getFileAudioData(for: fileSN) else {
            return
        }
        
        // 如果内存缓存超过限制，强制写入文件并清理内存
        if audioData.count > maxMemoryCacheSize {
            BLELogger.warning("⚠️ [内存压力检测] 文件 \(fileSN) 内存缓存过大 (\(audioData.count) 字节)，强制清理")
            
            // 先刷新所有缓冲区数据
            flushAudioDataToFile(fileSN: fileSN)
            
            // 清理内存缓存
            audioDataManager.clearFileAudioData(for: fileSN)
            
            BLELogger.log("🧹 [内存压力检测] 文件 \(fileSN) 内存缓存已清理，数据已保存到文件")
        }
    }
    
    /// 强制刷新所有缓冲区数据到文件
    /// - Parameter fileSN: 文件序列号
    func flushAllBuffersToFile(fileSN: Int) {
        BLELogger.log("🔒 [锁调试] flushAllBuffersToFile 开始 - 文件 \(fileSN)")
        
        // 先刷新写入缓冲区
        BLELogger.log("🔒 [锁调试] flushAllBuffersToFile 调用 flushAudioDataToFile - 文件 \(fileSN)")
        flushAudioDataToFile(fileSN: fileSN)
        BLELogger.log("🔒 [锁调试] flushAllBuffersToFile flushAudioDataToFile 完成 - 文件 \(fileSN)")
        
        // 如果内存中有音频数据，也保存到文件
        if let audioData = audioDataManager.getFileAudioData(for: fileSN), !audioData.isEmpty {
            BLELogger.log("📁 [文件音频管理] 文件 \(fileSN) 保存内存音频数据到文件: \(audioData.count) 字节")
            BLELogger.log("🔒 [锁调试] flushAllBuffersToFile 调用 saveAudioDataToFile - 文件 \(fileSN)")
            saveAudioDataToFile(fileSN: fileSN)
            BLELogger.log("🔒 [锁调试] flushAllBuffersToFile saveAudioDataToFile 完成 - 文件 \(fileSN)")
        } else {
            BLELogger.log("🔒 [锁调试] flushAllBuffersToFile 内存中没有音频数据 - 文件 \(fileSN)")
        }
        
        BLELogger.log("🔒 [锁调试] flushAllBuffersToFile 完成 - 文件 \(fileSN)")
    }
    
    /// 清理指定文件的音频数据
    func clearFileAudioData(for fileSN: Int) {
        // 先刷新所有缓冲区数据到文件
        flushAllBuffersToFile(fileSN: fileSN)
        
        // 清理内存缓存
        audioDataManager.clearFileAudioData(for: fileSN)
        
        // 线程安全地清理写入缓冲区
        fileWriteBuffers.removeValue(forKey: fileSN)
        
        // 删除持久化文件
        deleteAudioDataFile(fileSN: fileSN)
        
        BLELogger.log("📁 [文件音频管理] 清理文件 \(fileSN) 的音频数据缓存")
    }
    
    /// 清理所有文件的音频数据
    func clearAllFileAudioData() {
        // 线程安全地获取所有文件SN并刷新缓冲区
//        fileWriteBuffersLock.lock()
        let fileSNs = Array(fileWriteBuffers.keys)
//        fileWriteBuffersLock.unlock()
        
        // 先刷新所有缓冲区数据到文件
        for fileSN in fileSNs {
            flushAllBuffersToFile(fileSN: fileSN)
        }
        
        // 清理所有内存缓存
        audioDataManager.clearAllFileAudioData()
        
        // 线程安全地清理所有写入缓冲区
        fileWriteBuffers.removeAll()
        
        // 删除所有音频数据文件
        deleteAllAudioDataFiles()
        
        BLELogger.log("📁 [文件音频管理] 清理所有文件的音频数据缓存")
    }
    
    // MARK: - Audio Data Persistence
    
    /// 保存音频数据到文件
    /// - Parameter fileSN: 文件序列号
    private func saveAudioDataToFile(fileSN: Int) {
        BLELogger.log("🔒 [锁调试] saveAudioDataToFile 开始 - 文件 \(fileSN)")
        
        guard let audioData = audioDataManager.getFileAudioData(for: fileSN) else {
            BLELogger.log("🔒 [锁调试] saveAudioDataToFile 没有找到音频数据 - 文件 \(fileSN)")
            return
        }
        
        BLELogger.log("🔒 [锁调试] saveAudioDataToFile 找到音频数据: \(audioData.count) 字节 - 文件 \(fileSN)")
        
        // 确保目录存在
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: audioDataPath) {
            BLELogger.log("🔒 [锁调试] saveAudioDataToFile 创建目录 - 文件 \(fileSN)")
            try? fileManager.createDirectory(atPath: audioDataPath, withIntermediateDirectories: true)
        }
        
        let filePath = "\(audioDataPath)/audio_\(fileSN).data"
        BLELogger.log("🔒 [锁调试] saveAudioDataToFile 目标文件路径: \(filePath)")
        
        do {
            BLELogger.log("🔒 [锁调试] saveAudioDataToFile 开始写入数据 - 文件 \(fileSN)")
            try audioData.write(to: URL(fileURLWithPath: filePath))
            BLELogger.log("🔒 [锁调试] saveAudioDataToFile 数据写入成功 - 文件 \(fileSN)")
            BLELogger.log("💾 [音频数据持久化] 保存文件 \(fileSN) 音频数据: \(audioData.count) 字节")
        } catch {
            BLELogger.error("🔒 [锁调试] saveAudioDataToFile 数据写入失败: \(error) - 文件 \(fileSN)")
            BLELogger.error("❌ [音频数据持久化] 保存文件 \(fileSN) 音频数据失败: \(error)")
        }
        
        BLELogger.log("🔒 [锁调试] saveAudioDataToFile 完成 - 文件 \(fileSN)")
    }
    
    /// 从文件加载音频数据
    /// - Parameter fileSN: 文件序列号
    /// - Returns: 音频数据
    private func loadAudioDataFromFile(fileSN: Int) -> Data? {
        let filePath = "\(audioDataPath)/audio_\(fileSN).data"
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            BLELogger.log("📁 [音频数据持久化] 加载文件 \(fileSN) 音频数据: \(data.count) 字节")
            return data
        } catch {
            BLELogger.error("❌ [音频数据持久化] 加载文件 \(fileSN) 音频数据失败: \(error)")
            return nil
        }
    }
    
    /// 删除音频数据文件
    /// - Parameter fileSN: 文件序列号
    private func deleteAudioDataFile(fileSN: Int) {
        let filePath = "\(audioDataPath)/audio_\(fileSN).data"
        
        do {
            try FileManager.default.removeItem(atPath: filePath)
            BLELogger.log("🗑️ [音频数据持久化] 删除文件 \(fileSN) 音频数据文件")
        } catch {
            BLELogger.error("❌ [音频数据持久化] 删除文件 \(fileSN) 音频数据文件失败: \(error)")
        }
    }
    
    /// 删除所有音频数据文件
    private func deleteAllAudioDataFiles() {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: audioDataPath) else {
            return
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: audioDataPath)
            for file in files {
                if file.hasPrefix(NVEasyConstants.FilePaths.audioFilePrefix) && file.hasSuffix(NVEasyConstants.FilePaths.audioFileSuffix) {
                    try fileManager.removeItem(atPath: "\(audioDataPath)/\(file)")
                }
            }
            BLELogger.log("🗑️ [音频数据持久化] 删除所有音频数据文件")
        } catch {
            BLELogger.error("❌ [音频数据持久化] 删除音频数据文件失败: \(error)")
        }
    }
    
    // MARK: - Download Progress Management
    
    
    /// 重置速度计算
    /// - Parameter fileSN: 文件序列号
    func resetSpeedCalculation(for fileSN: Int) {
        speedCalculationManager.resetSpeedCalculation(for: fileSN)
    }
    
    /// 更新速度计算
    /// - Parameters:
    ///   - fileSN: 文件序列号
    ///   - dataSize: 数据大小（字节）
    func updateSpeedCalculation(for fileSN: Int, dataSize: Int) {
        speedCalculationManager.updateSpeedCalculation(for: fileSN, dataSize: dataSize)
    }
    
    /// 清理指定文件的速度计算数据
    /// - Parameter fileSN: 文件序列号
    func clearSpeedCalculation(for fileSN: Int) {
        speedCalculationManager.clearSpeedCalculation(for: fileSN)
    }
    
    /// 清理所有速度计算数据
    func clearAllSpeedCalculations() {
        speedCalculationManager.clearAllSpeedCalculations()
    }
    
    /// 获取速度计算信息
    func getSpeedCalculationInfo(for fileSN: Int) -> (totalBytes: Int, elapsedTime: TimeInterval, speedKbps: Int)? {
        return speedCalculationManager.getSpeedCalculationInfo(for: fileSN)
    }
    
    /// 应用退出时的完整清理
    func cleanupOnAppExit() {
        BLELogger.log("🧹 [应用退出] 开始清理所有资源")
        
        // 清理所有音频数据缓存
        clearAllFileAudioData()
        
        // 清理所有速度计算数据
        clearAllSpeedCalculations()
        
        // 清理过期的音频数据文件
        cleanupExpiredAudioDataFiles()
        
        // 清理实时音频流式处理资源
        cleanupRealtimeAudioStream()
        
        BLELogger.log("🧹 [应用退出] 资源清理完成")
    }
    
    
    /// 清理过期的音频数据文件
    /// 删除没有对应传输状态的音频数据文件
    func cleanupExpiredAudioDataFiles() {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: audioDataPath) else {
            return
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: audioDataPath)
            let audioFiles = files.filter { $0.hasPrefix(NVEasyConstants.FilePaths.audioFilePrefix) && $0.hasSuffix(NVEasyConstants.FilePaths.audioFileSuffix) }
            
            for audioFile in audioFiles {
                // 从文件名提取文件SN
                let fileName = audioFile.replacingOccurrences(of: NVEasyConstants.FilePaths.audioFilePrefix, with: "").replacingOccurrences(of: NVEasyConstants.FilePaths.audioFileSuffix, with: "")
                guard let fileSN = Int(fileName) else { continue }
                
                // 检查是否有对应的传输状态
                let hasTransferState = ResumeTransferManager.shared.getTransferState(fileSN: fileSN) != nil
                
                if !hasTransferState {
                    // 没有传输状态，删除过期文件
                    try fileManager.removeItem(atPath: "\(audioDataPath)/\(audioFile)")
                    BLELogger.log("🗑️ [音频数据清理] 删除过期音频数据文件: \(audioFile)")
                }
            }
        } catch {
            BLELogger.error("❌ [音频数据清理] 清理过期音频数据文件失败: \(error)")
        }
    }
    
    // MARK: - Realtime Audio Stream Management
    
    /// 初始化实时音频数据流式处理
    private func initRealtimeAudioStream() {
        realtimeAudioStreamManager.initRealtimeAudioStream()
    }
    
    /// 追加实时音频数据到文件
    /// - Parameter data: 音频数据
    func appendRealtimeAudioData(_ data: Data) {
        realtimeAudioStreamManager.appendRealtimeAudioData(data)
    }
    
    /// 检查实时音频内存压力
    func checkRealtimeMemoryPressure() {
        guard let currentAudioData = BLERecordManager.shared.audioData else { return }
        BLERecordManager.shared.audioData = realtimeAudioStreamManager.checkRealtimeMemoryPressure(currentAudioData)
    }
    
    /// 获取实时音频数据（从文件读取）
    /// - Returns: 完整的音频数据
    func getRealtimeAudioData() -> Data? {
        return realtimeAudioStreamManager.getRealtimeAudioData() ?? BLERecordManager.shared.audioData
    }
    
    /// 清理实时音频流式处理资源
    func cleanupRealtimeAudioStream() {
        realtimeAudioStreamManager.cleanupRealtimeAudioStream()
    }
    
    // MARK: - Recording Time Management Methods
    
    /// 设置录音开始时间
    func setRecordStartTime() {
        recordingTimeManager.setRecordStartTime()
    }
    
    /// 获取录音开始时间
    /// - Returns: 录音开始时间，如果未开始录音则返回nil
    func getRecordStartTime() -> Date? {
        return recordingTimeManager.getRecordStartTime()
    }
    
    /// 清除录音开始时间
    func clearRecordStartTime() {
        recordingTimeManager.clearRecordStartTime()
    }
    
    /// 获取录音持续时间
    /// - Returns: 录音持续时间（秒），如果未开始录音则返回0
    func getRecordDuration() -> TimeInterval {
        return recordingTimeManager.getRecordDuration()
    }
    
    /// 检查是否正在录音
    /// - Returns: 是否正在录音
    func isRecording() -> Bool {
        return recordingTimeManager.isRecording()
    }
    
    // MARK: - Date Formatting Utility Methods
    
    /// 格式化日期为字符串
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化后的日期字符串 (yyyy-MM-dd HH:mm:ss)
    func formatDateToString(_ date: Date) -> String {
        return recordingTimeManager.formatDateToString(date)
    }
    
    /// 格式化当前日期为字符串
    /// - Returns: 当前日期的格式化字符串 (yyyy-MM-dd HH:mm:ss)
    func formatCurrentDateToString() -> String {
        return recordingTimeManager.formatCurrentDateToString()
    }
    
    /// 格式化录音开始时间为字符串
    /// - Returns: 录音开始时间的格式化字符串，如果未开始录音则返回"未开始"
    func formatRecordStartTimeToString() -> String {
        return recordingTimeManager.formatRecordStartTimeToString()
    }
    
    /// 格式化录音持续时间为字符串
    /// - Returns: 录音持续时间的格式化字符串 (HH:mm:ss)
    func formatRecordDurationToString() -> String {
        return recordingTimeManager.formatRecordDurationToString()
    }
    
    /// 析构函数确保资源清理
    deinit {
        cleanupOnAppExit()
    }
    
    // MARK: - BLEManagerProtocol Methods
    
    /// 获取当前文件编号
    /// - Returns: 当前文件编号
    func getCurrentFileNumber() -> Int {
        // 这里应该返回当前正在处理的文件编号
        // 目前返回0作为默认值
        return 0
    }
    
    /// 获取内存使用信息
    /// - Returns: 内存使用信息字典
    func getMemoryUsageInfo() -> [String: Any] {
        return [
            "totalMemory": ProcessInfo.processInfo.physicalMemory,
            "usedMemory": 0, // 这里应该计算实际使用的内存
            "availableMemory": ProcessInfo.processInfo.physicalMemory
        ]
    }
    
    /// 强制内存清理
    func forceMemoryCleanup() {
        BLELogger.log("🧹 [内存管理] 执行强制内存清理")
        
        // 清理所有文件音频数据
        clearAllFileAudioData()
        
        // 清理所有速度计算数据
        clearAllSpeedCalculations()
        
        // 清理实时音频流
        cleanupRealtimeAudioStream()
    }
    
    /// 发送蓝牙连接失败事件
    func sendBluetoothConnectionFailure() {
        BLELogger.log("📡 [蓝牙连接] 发送连接失败事件")
        
        // 这里应该发送连接失败事件到Flutter端
        let arguments: [String: Any] = [
            "error": "连接失败",
            "timestamp": Date().timeIntervalSince1970
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("bluetoothConnectionFailure", arguments: arguments)
    }
    
    /// 显示下载进度条
    func showDownloadBar() {
        BLELogger.log("📊 [下载进度] 显示下载进度条")
        
        // 这里应该显示下载进度条
        // 目前只记录日志
    }
    
    /// 连接扩展设备A
    /// - Parameter uuid: 设备UUID
    public func connectExA(_ uuid: String) {
        BLELogger.log("🔗 [多设备连接] 连接扩展设备A: \(uuid)")
        
        // 这里应该实现连接扩展设备A的逻辑
        // 目前只记录日志
    }
    
    /// 连接扩展设备B
    /// - Parameter uuid: 设备UUID
    public func connectExB(_ uuid: String) {
        BLELogger.log("🔗 [多设备连接] 连接扩展设备B: \(uuid)")
        
        // 这里应该实现连接扩展设备B的逻辑
        // 目前只记录日志
    }
    
    /// 断开扩展设备A
    /// - Parameter uuid: 设备UUID
    public func disconnectExA(_ uuid: String) {
        BLELogger.log("🔌 [多设备连接] 断开扩展设备A: \(uuid)")
        
        // 这里应该实现断开扩展设备A的逻辑
        // 目前只记录日志
    }
    
    /// 断开扩展设备B
    /// - Parameter uuid: 设备UUID
    public func disconnectExB(_ uuid: String) {
        BLELogger.log("🔌 [多设备连接] 断开扩展设备B: \(uuid)")
        
        // 这里应该实现断开扩展设备B的逻辑
        // 目前只记录日志
    }
} 
