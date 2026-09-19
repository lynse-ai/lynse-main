//
//  NVPCMAccumulator.swift
//  FKAP
//
//  Created by zlj on 2024/9/11.
//

import AVFoundation

class NVPCMAccumulator {
    
    static let shared = NVPCMAccumulator()

    private var accumulatedData = Data()
    private var targetSize: Int = RDX.pcmLength()

    private init() { }

    func appendBuffer(_ pcmData: Data) -> [Data] {
        accumulatedData.append(contentsOf: pcmData)
        
        var outputDatas: [Data] = []
        
        while accumulatedData.count >= targetSize {
            let dataToMove = accumulatedData.prefix(targetSize)
            outputDatas.append(Data(dataToMove))
            accumulatedData.removeFirst(targetSize)
        }
        
        return outputDatas
    }

    func clean() {
        accumulatedData.removeAll()
    }
    
}

class NVOPUSAccumulator {
    
    static let shared40 = NVOPUSAccumulator(targetSize: 40)
    static let shared80 = NVOPUSAccumulator(targetSize: 80)

    private var accumulatedData = Data()
    private var targetSize: Int

    private init(targetSize: Int) {
        self.targetSize = targetSize
    }

    func appendBuffer(_ pcmData: Data) -> [Data] {
        accumulatedData.append(contentsOf: pcmData)
        
        var outputDatas: [Data] = []
        
        while accumulatedData.count >= targetSize {
            let dataToMove = accumulatedData.prefix(targetSize)
            outputDatas.append(Data(dataToMove))
            accumulatedData.removeFirst(targetSize)
        }
        
        return outputDatas
    }

    func clean() {
        accumulatedData.removeAll()
    }
    
}
