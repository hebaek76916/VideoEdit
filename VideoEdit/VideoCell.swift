//
//  VideoCell.swift
//  VideoEdit
//
//  Created by 현은백 on 10/1/24.
//

import UIKit
import AVFoundation

class VideoCell: UICollectionViewCell {
    let thumbnailImageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        thumbnailImageView.frame = contentView.bounds
        thumbnailImageView.contentMode = .scaleAspectFit
        contentView.addSubview(thumbnailImageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 썸네일 설정 함수
    func configure(with asset: AVAsset) {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1, preferredTimescale: 600) // 비디오의 첫 1초에서 썸네일 생성
        
        DispatchQueue.global().async {
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                
                DispatchQueue.main.async {
                    self.thumbnailImageView.image = uiImage
                }
            } catch {
                print("썸네일 생성 실패: \(error)")
            }
        }
    }
}
