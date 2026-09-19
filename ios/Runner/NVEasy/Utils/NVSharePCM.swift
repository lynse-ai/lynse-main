//
//  NVSharePCM.swift
//  NVEasyDemo
//
//  Created by zlj on 2024/12/11.
//

import UIKit
import AVFoundation

class AudioSharer: NSObject {
    // 私有属性用于保存当前的临时文件URL
    private var tempFileURL: URL?

    // 分享PCM音频数据
    func sharepcmData(_ pcmData: Data, from viewController: UIViewController) {
        guard !pcmData.isEmpty else {
            print("无法分享空的音频数据")
            return
        }

        // 创建临时文件路径
        tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sharedAudio.pcm")

        do {
            // 将PCM音频数据写入临时文件
            try pcmData.write(to: tempFileURL!)

            // 创建 UIActivityViewController 并传递文件 URL
            let activityViewController = UIActivityViewController(activityItems: [tempFileURL!], applicationActivities: nil)

            // 设置popover的来源 (仅适用于iPad)
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = viewController.view
                popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }

            // 添加完成回调来清理临时文件
            activityViewController.completionWithItemsHandler = { [weak self] (_, _, _, _) in
                self?.cleanup()
            }

            // 展示活动视图控制器
            viewController.present(activityViewController, animated: true, completion: nil)

        } catch {
            print("无法将PCM音频数据写入临时文件: \(error)")
            cleanup()
        }
    }

    // 清理临时文件
    private func cleanup() {
        guard let url = tempFileURL else { return }
        do {
            try FileManager.default.removeItem(at: url)
            print("临时文件已删除")
        } catch {
            print("无法删除临时文件: \(error)")
        }
        tempFileURL = nil
    }
}

// 扩展UIViewController以简化使用
extension UIViewController {
    func share(pcmData: Data) {
        let audioSharer = AudioSharer()
        audioSharer.sharepcmData(pcmData, from: self)
    }
}
