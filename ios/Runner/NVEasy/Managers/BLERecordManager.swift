import Foundation
import NVEasySDK
import opus
import AVFoundation

class BLERecordManager: NSObject, AudioManagerProtocol {
    
    // MARK: - Singleton
    static let shared = BLERecordManager()
    
    public var audioData: Data?
    public var isHuiYi: Bool = false // 会议模式
    public var isMono: Bool = false // 单声道标志
    
    private override init() {
        super.init()
    }
    
    func initOpus(mono: Bool) {
    }
    
    func startRecord() {
        NVEasyBLEManager.shared.startRecord(isMeetingMode: isHuiYi)
    }
    
    func pauseRecord() {
        NVEasyBLEManager.shared.pauseRecord(isMeetingMode: isHuiYi)
    }
    
    func resumeRecord() {
        NVEasyBLEManager.shared.resumeRecord(isMeetingMode: isHuiYi)
    }
    
    func stopRecord() -> [String: String]? {
        // 停止设备录音
        NVEasyBLEManager.shared.stopRecord(isMeetingMode: isHuiYi)
        return nil;
    }
    
    /// 计算MP3文件时长
    private func calculateMP3Duration(mp3Path: String) -> Int {
        let asset = AVAsset(url: URL(fileURLWithPath: mp3Path))
        let duration = asset.duration
        let durationInSeconds = CMTimeGetSeconds(duration)
        return Int(durationInSeconds)
    }
    
    // MARK: - Public Methods
    
    func setMeetingMode(_ isHuiYi: Bool) {
        self.isHuiYi = isHuiYi
    }
    
    func clearAudioData() {
        audioData = nil
    }
    
    func getAudioData() -> Data? {
        return audioData
    }
    
    /// 清理临时PCM文件
    /// - Parameter pcmPath: PCM文件路径
    private func cleanupTemporaryPCMFile(pcmPath: String) {
        do {
            if FileManager.default.fileExists(atPath: pcmPath) {
                try FileManager.default.removeItem(atPath: pcmPath)
                print("🗑️ [AudioManager] 已删除临时PCM文件: \(pcmPath)")
            }
        } catch {
            print("❌ [AudioManager] 删除临时PCM文件失败: \(pcmPath), 错误: \(error)")
        }
    }
    
    /// 清理所有临时音频文件
    func cleanupAllTemporaryFiles() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: documentsPath), includingPropertiesForKeys: nil)
            let pcmFiles = fileURLs.filter { $0.pathExtension.lowercased() == "pcm" }
            
            for pcmFile in pcmFiles {
                cleanupTemporaryPCMFile(pcmPath: pcmFile.path)
            }
            
            print("🗑️ [AudioManager] 已清理 \(pcmFiles.count) 个临时PCM文件")
        } catch {
            print("❌ [AudioManager] 清理临时文件失败: \(error)")
        }
    }
    
    /// 清理重复的音频文件
    func cleanupDuplicateAudioFiles() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: documentsPath), includingPropertiesForKeys: nil)
            let mp3Files = fileURLs.filter { $0.pathExtension.lowercased() == "mp3" }
            
            // 按文件大小分组，找出可能重复的文件
            var filesBySize: [Int: [URL]] = [:]
            for fileURL in mp3Files {
                let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int ?? 0
                if filesBySize[fileSize] == nil {
                    filesBySize[fileSize] = []
                }
                filesBySize[fileSize]?.append(fileURL)
            }
            
            // 删除重复文件（保留时间戳命名的文件，删除格式化日期命名的文件）
            for (size, files) in filesBySize {
                if files.count > 1 {
                    print("🔍 [AudioManager] 发现 \(files.count) 个相同大小的MP3文件（大小: \(size) bytes）")
                    
                    for fileURL in files {
                        let fileName = fileURL.lastPathComponent
                        // 删除格式化日期命名的文件（如 "2025-08-25 22:58:25.mp3"）
                        if fileName.contains(" ") && fileName.contains(":") {
                            do {
                                try FileManager.default.removeItem(at: fileURL)
                                print("🗑️ [AudioManager] 已删除重复文件: \(fileName)")
                            } catch {
                                print("❌ [AudioManager] 删除重复文件失败: \(fileName), 错误: \(error)")
                            }
                        }
                    }
                }
            }
            
            print("✅ [AudioManager] 重复文件清理完成")
        } catch {
            print("❌ [AudioManager] 清理重复文件失败: \(error)")
        }
    }
} 
