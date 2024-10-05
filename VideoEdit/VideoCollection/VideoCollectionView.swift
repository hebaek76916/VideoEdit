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
    
    static let scaleMax: CGFloat = 2.0
    static let scaleMin: CGFloat = 0.8
    
    private(set) var scale: CGFloat = 1.0 // 초기 스케일
    
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
        
        // 핀치 제스처 인식기 추가
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        addGestureRecognizer(pinchGesture)
    }
    
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        // 스케일 값 제한 (0.8 ~ 2.0 사이로 제한)
//        scale = max(VideoCollectionView.scaleMin, min(gesture.scale, VideoCollectionView.scaleMax))
//        
//        if gesture.state == .changed || gesture.state == .ended {
//            collectionViewLayout.invalidateLayout() // 레이아웃 무효화
//            // TODO: 스케일 값에 따라 썸네일 다시 생성
////            self.generateThumbnails()
//        }
    }
    
    func setUpVideoCollectionThresholdLineView() {
        let lineView = UIView()
        lineView.translatesAutoresizingMaskIntoConstraints = false
        lineView.backgroundColor = .white
        if let collectionSuperView = self.superview {
            collectionSuperView.addSubview(lineView)
            [
                lineView.leadingAnchor.constraint(equalTo: collectionSuperView.leadingAnchor, constant: VideoCollectionView.videoCollectionViewInsetvideoCollectionViewInset - 3),
                lineView.topAnchor.constraint(equalTo: topAnchor),
                lineView.bottomAnchor.constraint(equalTo: bottomAnchor),
                lineView.widthAnchor.constraint(equalToConstant: 3)
            ].forEach { $0.isActive = true }
        }
    }
    
}

