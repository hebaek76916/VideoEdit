//
//  VideoAsset.swift
//  VideoEdit
//
//  Created by 현은백 on 10/6/24.
//

import CoreMedia.CMTime

class VideoAsset {
    let assetURL: URL
    var duration: CMTime
    var thumbnails: [CGImage] = []
    var isSaved: Bool = false
    var firstThumbnail: CGImage? {
        thumbnails.first
    }
    
    init(assetURL: URL, duration: CMTime, thumbnails: [CGImage] = []) {
        self.assetURL = assetURL
        self.duration = duration
        self.thumbnails = thumbnails
    }

    func setThumbnails(cgImages: [CGImage]) {
        self.thumbnails = cgImages
    }
}
