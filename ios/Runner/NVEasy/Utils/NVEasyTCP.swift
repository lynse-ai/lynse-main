//
//  NVEasyTCP.swift
//  NVEasyDemo
//
//  Created by zlj on 2025/2/8.
//

import Foundation
import Network

class NVEasyTCP {
    private let targetIP: String
    private let targetPort: UInt16
    private let localIP: String?
    private let localPort: UInt16?
    private(set) var connection: NWConnection?
    private var receiveDataHandler: ((Data) -> Void)?
    private var errorHandler: ((Error) -> Void)?
    private var stateUpdateHandler: ((NWConnection.State) -> Void)?
    private(set) var isReceiving: Bool = false
    
    init(targetIP: String, targetPort: UInt16, localIP: String? = nil, localPort: UInt16? = nil) {
        self.targetIP = targetIP
        self.targetPort = targetPort
        self.localIP = localIP
        self.localPort = localPort
        print("targetIP: \(targetIP), targetPort: \(targetPort), localIP: \(localIP), localPort: \(localPort)")
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
        
        // 创建 TCP 参数
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
//        parameters.includePeerToPeer = true
//        parameters.acceptLocalOnly = true
        
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
        
        // 创建 TCP 连接
        connection = NWConnection(to: targetEndpoint, using: parameters)
        
        // 开始连接
        connection?.start(queue: .global())
        
        // 处理连接状态变化
        connection?.stateUpdateHandler = { [weak self] newState in
            self?.stateUpdateHandler?(newState)
            
            switch newState {
            case .ready:
                print("TCP 连接已建立")
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
            print("TCP 已关闭， 新建链接再发送数据")
            return
        }
        
        connection?.send(content: data, isComplete: true, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("发送数据时出错: \(error)")
                self?.errorHandler?(error)
            } else {
                print("WiFi Speed TCP 数据发送成功")
            }
        })
    }
    
    private func startReceiving() {
        guard isReceiving else {
            print("接收已停止")
            return
        }
        
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }
            print("接收到数据: \(data?.count)")

//            print("data: \(data?.count ?? 0), context: \(context?.identifier), isComplete: \(isComplete), error: \(error)")
            if let data = data, !data.isEmpty {
                receiveDataHandler?(data)
            }
            
            if let error = error {
                print("接收数据时出错: \(error)")
                errorHandler?(error)
                isReceiving = false
                return
            }
            
            // 继续接收下一条消息
            startReceiving()
        }
    }
    
    func stopConnection() {
        isReceiving = false
//        connection?.cancel()
        connection?.forceCancel()
        connection = nil
        print("TCP 连接已关闭")
    }
}
