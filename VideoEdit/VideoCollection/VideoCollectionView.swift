//
//  VideoCollectionView.swift
//  VideoEdit
//
//  Created by 현은백 on 10/4/24.
//

import UIKit

class VideoCollectionView: UICollectionView {
    
    static let videoUnitSec: Double = 30.0
    static let videoUnitWidth: Double = 100.0
    static let emptyCellWidth: Double = 1000.0
    static let videoCollectionViewInsetvideoCollectionViewInset: Double = 100.0
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        layout.scrollDirection = .horizontal
        super.init(frame: .zero, collectionViewLayout: layout)
        
        register(VideoCell.self, forCellWithReuseIdentifier: VideoCell.identifier)
        backgroundColor = .blue
        isScrollEnabled = true
        showsHorizontalScrollIndicator = false
        alwaysBounceHorizontal = true
        dragInteractionEnabled = true
        contentInset = .init(top: 0, left: VideoCollectionView.videoCollectionViewInsetvideoCollectionViewInset, bottom: 0, right: 0)
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        setUpVideoCollectionThresholdLineView()
    }
    
    func setUpVideoCollectionThresholdLineView() {
        let lineView = UIView()
        lineView.translatesAutoresizingMaskIntoConstraints = false
        lineView.backgroundColor = .white
        if let collectionSuperView = self.superview {
            collectionSuperView.addSubview(lineView)
            [
                lineView.leadingAnchor.constraint(equalTo: collectionSuperView.leadingAnchor, constant: VideoCollectionView.videoCollectionViewInsetvideoCollectionViewInset),
                lineView.topAnchor.constraint(equalTo: topAnchor),
                lineView.bottomAnchor.constraint(equalTo: bottomAnchor),
                lineView.widthAnchor.constraint(equalToConstant: 3)
            ].forEach { $0.isActive = true }
        }
    }
    
}

