//
//  VideoCollectionDataSource.swift
//  VideoEdit
//
//  Created by 현은백 on 10/4/24.
//

import UIKit.UICollectionView
import CoreMedia.CMTime

class VideoCollectionViewDataSource: NSObject, UICollectionViewDataSource {

    var scale: CGFloat = 1.0
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
            cell.backgroundColor = .black.withAlphaComponent(0.6)
        }
        return cell
    }
}
