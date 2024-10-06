//
//  ThumbnailView.swift
//  VideoEdit
//
//  Created by 현은백 on 10/3/24.
//

import UIKit

class ThumbnailView: UIView {

    private var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .lightGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var progressTimeLabel: UILabel = {
        let label = UILabel()
        label.layer.cornerRadius = 12
        label.backgroundColor = .black.withAlphaComponent(0.5)
        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func configure(isHidden: Bool) {
        progressTimeLabel.isHidden = isHidden
    }
    
    public func setProgress(progress: Double, total: Double) {
        progressTimeLabel.text = {
            return .timeProgressString(currentTime: progress, totalTime: total)
        }()
    }
    
    public func setImage(image: CGImage?) {
        if let cgImage = image {
            thumbnailImageView.image = UIImage(cgImage: cgImage)
        } else {
            thumbnailImageView.image = nil
            progressTimeLabel.text = nil
        }
    }
}

//MARK: Set Up
private extension ThumbnailView {
    
    func setUpUI() {
        setUpThumbnailView()
        setUpProgressTimeLabel()
        
        func setUpThumbnailView() {
            addSubview(thumbnailImageView)
            [
                thumbnailImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                thumbnailImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                thumbnailImageView.topAnchor.constraint(equalTo: topAnchor),
                thumbnailImageView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ].forEach { $0.isActive = true }
        }
        
        func setUpProgressTimeLabel() {
            addSubview(progressTimeLabel)
            [
                progressTimeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                progressTimeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
                progressTimeLabel.heightAnchor.constraint(equalToConstant: 30)
            ].forEach { $0.isActive = true }
        }
    }
}


