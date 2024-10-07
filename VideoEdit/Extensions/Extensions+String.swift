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
        let currentSeconds = Double.minimum(currentTime, totalTime)
        return "\(formatTime(currentSeconds)) / \(formatTime(totalTime))"
    }
    
    // 보조 함수: 초를 받아 "MM:SS.xx" 형식으로 포맷
    private static func formatTime(_ seconds: CGFloat) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secondsPart = seconds.truncatingRemainder(dividingBy: 60) // 소수점 포함 초 계산
        
        return String(format: "%02d:%05.2f", minutes, secondsPart)
    }
}
