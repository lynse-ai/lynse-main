//
//  WiFiStressTester.swift
//  NVEasyDemo
//
//  Created by zlj on 2025/7/10.
//

//
//  WiFiStressTester.swift
//  NVEasyDemo
//
//  Created by zlj on 2025/7/10.
//

import Foundation
import UIKit

class WiFiStressTester {
    // 配置参数
    private let targetURL: URL
    private let imageSizeMB: Int
    private let requestsPerSecond: Int
    private var uploadTimer: Timer?
    
    // Socket连接相关
    private let socketHost = "3.164.121.26"
    private let socketPort: Int
    private var socketQueue = DispatchQueue(label: "com.nveasydemo.socketQueue", attributes: .concurrent)
    
    // 状态跟踪
    private var totalRequestsSent = 0
    private var totalSocketConnections = 0
    private var startTime: Date?
    
    // 用于管理并发请求
    private let concurrentQueue = DispatchQueue(label: "com.nveasydemo.concurrentQueue", attributes: .concurrent)
    private let dispatchGroup = DispatchGroup()
    
    init(targetURL: URL, imageSizeMB: Int = 1, requestsPerSecond: Int = 1, socketPort: Int = 443) {
        self.targetURL = targetURL
        self.imageSizeMB = max(1, imageSizeMB)  // 至少1MB
        self.requestsPerSecond = max(1, requestsPerSecond)
        self.socketPort = socketPort
    }
    
    // 生成测试用的大图数据
    private func generateLargeImageData() -> Data {
        // 创建指定大小的空白位图 (1MB = 1_048_576 bytes)
        let sizeInBytes = imageSizeMB * 1_048_576
        var randomData = Data(count: sizeInBytes)
        
        // 用随机数据填充（模拟图片内容）
        randomData.withUnsafeMutableBytes { mutableBytes in
            guard let baseAddress = mutableBytes.baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, sizeInBytes, baseAddress)
        }
        return randomData
    }
    
    // 创建并立即断开Socket连接
    private func createAndCloseSocket() {
        socketQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 创建Socket
            let socketFD = socket(AF_INET, SOCK_STREAM, 0)
            guard socketFD != -1 else {
                print("WiFiStressTester Socket creation failed: \(String(cString: strerror(errno)))")
                return
            }
            
            // 设置目标地址
            var serverAddr = sockaddr_in()
            serverAddr.sin_family = sa_family_t(AF_INET)
            serverAddr.sin_port = in_port_t(self.socketPort).bigEndian
            
            // 直接使用IP地址，避免DNS解析
            if inet_pton(AF_INET, self.socketHost, &serverAddr.sin_addr) != 1 {
                close(socketFD)
                print("WiFiStressTester Invalid IP address: \(self.socketHost)")
                return
            }
            
            // 尝试连接
            let connectResult = withUnsafePointer(to: &serverAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    connect(socketFD, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            // 更新连接计数
            DispatchQueue.main.async {
                self.totalSocketConnections += 1
            }
            
            if connectResult == 0 {
                print("WiFiStressTester Socket connection #\(self.totalSocketConnections) established to \(self.socketHost):\(self.socketPort)")
            } else {
                print("WiFiStressTester Socket connection #\(self.totalSocketConnections) failed: \(String(cString: strerror(errno)))")
            }
            
            // 立即关闭Socket
            close(socketFD)
        }
    }
    
    // 执行单次上传任务
    private func performUpload() {
        // 先创建Socket连接
        createAndCloseSocket()
        
        // 然后执行上传
        let imageData = generateLargeImageData()
        totalRequestsSent += 1
        print("WiFiStressTester Sending request #\(totalRequestsSent) (\(imageData.count.bytesToMB) MB)")
        
        var request = URLRequest(url: targetURL)
        request.httpMethod = "POST"
        request.setValue("WiFiStressTester application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0 // 设置超时时间
        
        let task = URLSession.shared.uploadTask(with: request, from: imageData) {
            data, response, error in
            if let error = error {
                print("WiFiStressTester Upload failed: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("WiFiStressTester Invalid server response")
                return
            }
            
            let status = httpResponse.statusCode
            let size = imageData.count.bytesToMB
            print("WiFiStressTester Response #\(self.totalRequestsSent): HTTP \(status) (\(size) MB)")
        }
        task.resume()
    }
    
    // 启动压力测试
    func startStressTest() {
        stopStressTest()  // 确保停止任何现有测试
        
        totalRequestsSent = 0
        totalSocketConnections = 0
        startTime = Date()
        print("""
        🚀 Starting WiFi stress test
        =============================
        Target URL: \(targetURL)
        Image size: \(imageSizeMB) MB
        Requests/sec: \(requestsPerSecond)
        Socket target: \(socketHost):\(socketPort)
        Concurrency: Burst of \(requestsPerSecond) requests every second
        =============================
        """)
        
        // 创建每秒触发一次的定时器
        uploadTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 在并发队列中一次性发送所有请求
            self.concurrentQueue.async {
                // 一次性发送 requestsPerSecond 个请求
                for _ in 0..<self.requestsPerSecond {
                    // 使用DispatchGroup确保所有请求并行执行
                    self.dispatchGroup.enter()
                    
                    // 在全局队列中执行每个请求
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.performUpload()
                        self.dispatchGroup.leave()
                    }
                }
                
                // 等待所有请求开始（但不等待完成）
                self.dispatchGroup.wait()
            }
        }
        RunLoop.current.add(uploadTimer!, forMode: .common)
    }
    
    // 停止压力测试
    func stopStressTest() {
        uploadTimer?.invalidate()
        uploadTimer = nil
        
        guard let start = startTime else { return }
        let duration = Date().timeIntervalSince(start)
        
        // 计算实际请求率
        let actualRate = duration > 0 ? Double(totalRequestsSent) / duration : 0
        
        print("""
        \n🛑 Stress test stopped
        =============================
        Total time: \(String(format: "%.1f", duration)) sec
        Requests sent: \(totalRequestsSent)
        Socket connections: \(totalSocketConnections)
        Target rate: \(requestsPerSecond) req/sec
        Actual rate: \(String(format: "%.1f", actualRate)) req/sec
        Avg. throughput: \(String(format: "%.1f", Double(totalRequestsSent * imageSizeMB) / duration)) MB/s
        =============================
        """)
    }
}

// 数据扩展：字节转MB显示
extension Int {
    var bytesToMB: String {
        String(format: "%.2f MB", Double(self) / 1_048_576.0)
    }
}
