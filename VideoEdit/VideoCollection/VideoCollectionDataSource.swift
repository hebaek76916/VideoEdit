//
//  VideoCollectionDataSource.swift
//  VideoEdit
//
//  Created by 현은백 on 10/4/24.
//

import UIKit
import AVFoundation

class VideoAsset {
    let asset: AVAsset
    var duration: CMTime
    var thumbnails: [CGImage] = []
    var firstThumbnail: CGImage? {
        thumbnails.first
    }
    
    init(asset: AVAsset, duration: CMTime) {
        self.asset = asset
        self.duration = duration
    }

    func setThumbnails(cgImages: [CGImage]) {
        self.thumbnails = cgImages
    }
}

class VideoCollectionViewDataSource: NSObject, UICollectionViewDataSource {

    var videoAssets: [VideoAsset] = []
    var videoThumbnails: [CGImage] {
        self.videoAssets.compactMap { $0.thumbnails }.flatMap { $0 }
    }
    
    var totalDuration: CMTime {
        return videoAssets.map { $0.duration }.reduce(.zero) { partialResult, duration in
            CMTimeAdd(partialResult, duration)
        }
    }
    
    private let additionalCells = 1 // 추가 여유 공간을 위한 빈 셀
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videoAssets.count + additionalCells
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoCell.identifier, for: indexPath) as! VideoCell
        if let videoAsset = videoAssets[safe: indexPath.item] {
            cell.configure(with: videoAsset)
        } else {
            cell.contentView.layer.borderWidth = 2.0
            cell.contentView.layer.borderColor = UIColor.gray.cgColor
            cell.backgroundColor = .systemPink
        }
        return cell
    }
}
