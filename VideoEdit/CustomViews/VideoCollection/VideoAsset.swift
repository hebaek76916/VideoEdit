//
//  VideoAsset.swift
//  VideoEdit
//
//  Created by 현은백 on 10/6/24.
//

import AVFoundation

class VideoAsset {
    let assetURL: URL
    var duration: CMTime
    var thumbnails: [CGImage] = []
    var firstThumbnail: CGImage? {
        thumbnails.first
    }
    
    init(assetURL: URL, duration: CMTime) {
        self.assetURL = assetURL
        self.duration = duration
    }

    func setThumbnails(cgImages: [CGImage]) {
        self.thumbnails = cgImages
    }
}
