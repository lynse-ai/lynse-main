import Foundation
import Flutter

/// 传输相关方法处理器
class TransferMethodHandler: BaseMethodHandler {
    
    override func handle(method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool {
        switch method {
        case "resumeTransfer":
            if let arguments = arguments,
               let fileSN = arguments["sn"] as? Int {
                let success = ResumeTransferManager.shared.resumeTransfer(fileSN: fileSN)
                result(success)
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "File SN is required", 
                                  details: nil))
                return true
            }
            
        case "getResumableTransfers":
            let resumableTransfers = ResumeTransferManager.shared.getResumableTransfers()
            let transferData: [[String: Any]] = resumableTransfers.compactMap { transfer in
                guard let transferState = transfer as? ResumeTransferManager.TransferState else {
                    return nil
                }
                return [
                    "fileSN": transferState.fileSN,
                    "fileName": transferState.fileName,
                    "fileSize": transferState.fileSize,
                    "receivedBytes": transferState.receivedBytes,
                    "progress": transferState.progress,
                    "progressString": transferState.progressString,
                    "speedString": transferState.speedString,
                    "remainingTimeString": transferState.remainingTimeString,
                    "errorMessage": transferState.errorMessage ?? ""
                ]
            }
            result(transferData)
            return true
            
        case "clearTransferState":
            if let arguments = arguments,
               let fileSN = arguments["sn"] as? Int {
                ResumeTransferManager.shared.clearTransferState(fileSN: fileSN)
                result("clearTransferState!")
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "File SN is required", 
                                  details: nil))
                return true
            }
            
        case "clearAllTransferStates":
            ResumeTransferManager.shared.clearAllTransferStates()
            result("clearAllTransferStates!")
            return true
            
        case "clearCompletedTransfers":
            ResumeTransferManager.shared.clearCompletedTransfers()
            result("clearCompletedTransfers!")
            return true
            
        default:
            return false
        }
    }
}
