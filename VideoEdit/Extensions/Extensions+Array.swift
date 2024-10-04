//
//  Extensions+Array.swift
//  VideoEdit
//
//  Created by 현은백 on 10/2/24.
//

import Foundation

extension Array {
    subscript (safe index: Int) -> Element? {
        return indices ~= index ? self[index] : nil
    }
}
