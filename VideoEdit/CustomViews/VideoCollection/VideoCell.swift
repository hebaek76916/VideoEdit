//
//  VideoCell.swift
//  VideoEdit
//
//  Created by 현은백 on 10/1/24.
//

import UIKit.UICollectionViewCell
import AVFoundation

class VideoCell: UICollectionViewCell {
    
    static let identifier = "VideoCell"
    
    private let thumbnailImageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
    }
    
    // 썸네일 설정 함수
    func configure(with asset: VideoAsset) {
        guard let thumbnail = asset.firstThumbnail else { return }
        self.thumbnailImageView.image = UIImage(cgImage: thumbnail)
    }
}

private extension VideoCell {
    func setUpUI() {
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbnailImageView)
        [
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ].forEach { $0.isActive = true }
    }
}
