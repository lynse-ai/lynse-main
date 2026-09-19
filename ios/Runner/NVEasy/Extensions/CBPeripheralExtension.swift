//
//  CBPeripheralExtension.swift
//  Runner
//
//  Created by Wan Qijian on 2025/8/26.
//

import Foundation
import CoreBluetooth

extension CBPeripheral {
    
    /// 返回 MAC 地址的反序字符串
    /// 
    /// 例如：如果 mac 是 "A1:B2:C3:D4:E5:F6"，则返回 "F6:E5:D4:C3:B2:A1"
    /// 
    /// - Returns: MAC 地址的反序字符串
    var reversedMac: String {
        // 按冒号分割 MAC 地址
        let components = self.mac.components(separatedBy: ":")
        // 反序字节数组
        let reversedComponents = components.reversed()
        // 重新组合
        return reversedComponents.joined(separator: ":")
    }
    
    /// 返回 MAC 地址的反序字符串（按字节反序）
    /// 
    /// 例如：如果 mac 是 "A1B2C3D4E5F6"，则返回 "F6E5D4C3B2A1"
    /// 这个方法会按每两个字符（一个字节）进行反序，忽略冒号分隔符
    /// 
    /// - Returns: MAC 地址按字节反序的字符串
    var reversedMacByBytes: String {
        // 先移除冒号分隔符
        let cleanMac = self.mac.replacingOccurrences(of: ":", with: "")
        // 按每两个字符分割
        let bytes = stride(from: 0, to: cleanMac.count, by: 2).map {
            String(cleanMac[cleanMac.index(cleanMac.startIndex, offsetBy: $0)..<cleanMac.index(cleanMac.startIndex, offsetBy: min($0 + 2, cleanMac.count))])
        }
        return bytes.reversed().joined()
    }
    
    /// 返回 MAC 地址的反序字符串（移除冒号分隔符后反序）
    /// 
    /// 例如：如果 mac 是 "A1:B2:C3:D4:E5:F6"，则返回 "F6E5D4C3B2A1"
    /// 这个方法先移除所有冒号分隔符，然后对整个字符串进行字符级别的反序
    /// 
    /// - Returns: 移除分隔符后的 MAC 地址反序字符串
    var reversedMacWithoutSeparators: String {
        let cleanMac = self.mac.replacingOccurrences(of: ":", with: "")
        return String(cleanMac.reversed())
    }
}

