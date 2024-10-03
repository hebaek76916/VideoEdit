//
//  Extension+String.swift
//  VideoEdit
//
//  Created by 현은백 on 10/3/24.
//

import Foundation
import AVFoundation

extension String {
    
    static func timeProgressString(currentTime: Double, totalTime: Double) -> String {
        // 현재 초로 변환 (현재 시간이 총 시간보다 클 수 없도록 제한)
        let currentSeconds = Double.minimum(currentTime, totalTime)

        // 포맷된 문자열 반환
        return "\(formatTime(currentSeconds)) / \(formatTime(totalTime))"
    }
    
    // 보조 함수: 초를 받아 "MM:SS" 형식으로 포맷
    private static func formatTime(_ seconds: CGFloat) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secondsPart = totalSeconds % 60
        
        return String(format: "%02d:%02d", minutes, secondsPart)
    }
}
