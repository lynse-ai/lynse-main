//
//  NVEasyUDP.swift
//  NVEasyDemo
//
//  Created by zlj on 2025/2/8.
//

import Foundation
import Network

class NVEasyUDP {
    private let targetIP: String
    private let targetPort: UInt16
    private let localIP: String?
    private let localPort: UInt16?
    private var connection: NWConnection?
    private var receiveDataHandler: ((Data) -> Void)?
    private var errorHandler: ((Error) -> Void)?
    private var stateUpdateHandler: ((NWConnection.State) -> Void)?
    private var isReceiving: Bool = false
    private var receivedDataBuffer: Data = Data() // 新增：用于存储接收到的数据

    init(targetIP: String, targetPort: UInt16, localIP: String? = nil, localPort: UInt16? = nil) {
        self.targetIP = targetIP
        self.targetPort = targetPort
        self.localIP = localIP
        self.localPort = localPort
    }

    func setStateUpdateHandler(_ handler: @escaping (NWConnection.State) -> Void) {
        self.stateUpdateHandler = handler
    }

    func startConnection(receiveData: @escaping (Data) -> Void, onError: @escaping (Error) -> Void) {
        self.receiveDataHandler = receiveData
        self.errorHandler = onError

        // 创建目标端点
        guard let targetIPAddress = IPv4Address(targetIP) else {
            let error = NSError(domain: "Invalid Target IP Address", code: -1, userInfo: nil)
            self.errorHandler?(error)
            return
        }
        let targetEndpoint = NWEndpoint.hostPort(host: .ipv4(targetIPAddress), port: .init(integerLiteral: targetPort))

        // 创建 UDP 参数
        let parameters = NWParameters.udp

        // 如果指定了本地 IP 和端口，则配置本地端点
        if let localIP = localIP, let localPort = localPort {
            guard let localIPAddress = IPv4Address(localIP) else {
                let error = NSError(domain: "Invalid Local IP Address", code: -1, userInfo: nil)
                self.errorHandler?(error)
                return
            }
            let localEndpoint = NWEndpoint.hostPort(host: .ipv4(localIPAddress), port: .init(integerLiteral: localPort))
            parameters.requiredLocalEndpoint = localEndpoint
        }

        // 创建 UDP 连接
        connection = NWConnection(to: targetEndpoint, using: parameters)

        // 开始连接
        connection?.start(queue: .global())

        // 处理连接状态变化
        connection?.stateUpdateHandler = { [weak self] newState in
            self?.stateUpdateHandler?(newState)

            switch newState {
            case .ready:
                print("UDP 连接已建立")
                self?.isReceiving = true
                self?.startReceiving()
            case .failed(let error):
                print("连接失败: \(error)")
                self?.isReceiving = false
                self?.errorHandler?(error)
            case .cancelled:
                print("连接已取消")
                self?.isReceiving = false
            case .waiting(let error):
                print("连接等待中: \(error)")
                self?.errorHandler?(error)
            case .preparing:
                print("连接准备中")
            case .setup:
                print("连接设置中")
            @unknown default:
                print("未知连接状态")
            }
        }
    }

    func sendData(_ data: Data) {
        guard connection != nil else {
            print("UDP 已关闭， 新建链接再发送数据")
            return
        }
        receivedDataBuffer.removeAll()
        delayedResendData(data)
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("发送数据时出错: \(error)")
                self?.errorHandler?(error)
            } else {
                print("WiFi Speed 数据发送成功")
            }
        })
    }
    
    private func delayedResendData(_ data: Data) {
        UDPRetryQueue.shared.addOperation(id: "delayedResendData", delayInSeconds: 0.5) {
            guard self.isReceiving else {
                return
            }
            print("WiFi Speed 数据重新发送")
            self.sendData(data)
        }
    }
    
    func cleanDelayedResendData() {
        UDPRetryQueue.shared.addOperation(id: "delayedResendData") {}
    }
    
    private func startReceiving() {
        guard isReceiving else {
            print("接收已停止")
            UDPRetryQueue.shared.addOperation(id: "delayedResendData") {}
            return
        }

        let bufferSize = 65507
        connection?.receive(minimumIncompleteLength: 1, maximumLength: bufferSize) { [weak self] (data, context, isComplete, error) in
//            print("UDP receive: \(data?.count) \(context?.identifier) \(context) \(context?.isFinal) \(isComplete)")
//            print("WiFi Speed UDP receive: \(data?.count) \(Date().timeIntervalSince1970)")
            guard let self else { return }
            UDPRetryQueue.shared.addOperation(id: "delayedResendData") {}
            if let data = data, !data.isEmpty {
                receivedDataBuffer.append(data) // 将接收到的数据拼接到缓冲区
                receiveDataHandler?(receivedDataBuffer)
            }
            if let error = error {
                print("接收数据时出错: \(error)")
                errorHandler?(error)
                isReceiving = false
            }
            // 继续接收下一条消息
//            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
           startReceiving()
//            }
        }
    }

    func stopConnection() {
        UDPRetryQueue.shared.addOperation(id: "delayedResendData") {}
        isReceiving = false
        connection?.cancel()
        connection = nil
        print("连接已关闭")
    }
}


class UDPRetryQueue {
    static let shared = UDPRetryQueue()
    private let queue = DispatchQueue(label: "com.nveasy.UDPRetryQueue")
    private var operations = [String: DispatchWorkItem]()
    
    private init() {}
    
    func addOperation(id: String, delayInSeconds: Double = 0.01, execQueue: DispatchQueue = DispatchQueue.main, block: @escaping () -> Void) {
        queue.async {
            if let operation = self.operations[id] {
                operation.cancel()
            }
            
            let workItem = DispatchWorkItem(block: block)
            self.operations[id] = workItem
            
            self.queue.asyncAfter(deadline: .now() + delayInSeconds) {
                execQueue.sync {
                    if !workItem.isCancelled {
                        workItem.perform()
                        self.operations[id] = nil
                    }
                }
            }
        }
    }
}
