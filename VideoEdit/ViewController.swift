//
//  ViewController.swift
//  VideoEdit
//
//  Created by 현은백 on 9/30/24.
//

import UIKit
import PhotosUI

class ViewController: UIViewController {
    
    internal var thumbnailImageView: ThumbnailView = {
        let imageView = ThumbnailView()
        imageView.backgroundColor = .lightGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let addVideoButton: UIButton = {
        let button = UIButton()
        button.setTitle("Add Video", for: .normal)
        button.titleLabel?.textColor = .white
        button.backgroundColor = .black
        button.layer.borderWidth = 2.0
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        button.heightAnchor.constraint(equalToConstant: 60).isActive = true
        return button
    }()
    
    private let removeAllButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "trash")?.withTintColor(.white), for: .normal)
        button.titleLabel?.textColor = .white
        button.backgroundColor = .white
        button.layer.borderWidth = 2.0
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 60).isActive = true
        button.heightAnchor.constraint(equalToConstant: 60).isActive = true
        return button
    }()
    
    private var videoDataSource = VideoCollectionViewDataSource()
    lazy var videoDelegate = VideoCollectionViewDelegate(parentViewController: self, dataSource: self.videoDataSource)
    private var videoCollectionView: VideoCollectionView = {
       let collectionView = VideoCollectionView()
       collectionView.translatesAutoresizingMaskIntoConstraints = false
       return collectionView
    }()
    
    private var loadingIndicator: UIActivityIndicatorView = {
        var loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        return loadingIndicator
    }()

    var contentWidth: CGFloat {
        videoCollectionView.contentSize.width - VideoCollectionView.emptyCellWidth * videoDataSource.scale// remainingWidth
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureVideoCollectionView()
        setUpUI()
        addVideoButton.addTarget(self, action: #selector(addVideosTapped), for: .touchUpInside)
        removeAllButton.addTarget(self, action: #selector(removeAllTapped), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkPhotoLibraryAuthorization()
    }
    
    private func checkPhotoLibraryAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized {
                    // 사진 접근 허가됨, 사진 접근 코드 실행
                } else {
                    // 접근 권한 거부됨, 적절한 사용자 안내
                }
            }
        } else if status == .denied || status == .restricted {
            // 접근 권한 거부됨, 설정에서 권한을 요청하라는 메시지
        }
    }
}

extension ViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard !results.isEmpty else { return }
        
        loadingIndicator.startAnimating()
        availiblityButtonsWhileProcessing(isEnable: false)
        
        Task {
            let size = self.thumbnailImageView.frame.size
            VideoAssetManager.shared.thumbnailSize = .init(width: size.width * 0.8, height: size.height * 0.8)
            let videoAssets = await VideoAssetManager.shared.fetchAndExportVideos(results: results)
            videoDataSource.videoAssets.append(contentsOf: videoAssets)
            DispatchQueue.main.async {
                // 모든 비디오 처리 후 UI 갱신
                self.loadingIndicator.stopAnimating()
                self.availiblityButtonsWhileProcessing(isEnable: true)
                self.videoCollectionView.reloadData()
            }
        }
    }
    
    private func availiblityButtonsWhileProcessing(isEnable: Bool) {
        removeAllButton.isEnabled = isEnable
        addVideoButton.isEnabled = isEnable
    }
}

extension ViewController: VideoCollectionDelegate {
    
    // 스크롤된 시점에 맞춰 해당 썸네일을 표시
    func updateThumbnailAtScrollPosition(scrollOffset: CGFloat) {
        guard scrollOffset >= 0 else { return }
        let totalDuration = videoDataSource.totalDuration
        let scale = videoDataSource.scale
        let scaledUnitWidth = VideoCollectionView.videoUnitWidth * scale
        
        // 현재 시간에 해당하는 썸네일 인덱스 계산(역산)
        let index = (scrollOffset * VideoCollectionView.videoUnitSec) / (scaledUnitWidth)
        let tuned = Int(index) // 스케일에 따라 조정된 인덱스
        
        let cgImage = videoDataSource.videoThumbnails[safe: tuned]
        let currentTime = CGFloat((CMTimeGetSeconds(totalDuration)) * scrollOffset) / (contentWidth)
        DispatchQueue.main.async {
            self.thumbnailImageView.setImage(image: cgImage)
            self.thumbnailImageView.setProgress(progress: currentTime, total: CMTimeGetSeconds(totalDuration))
        }
    }

}

//MARK: Set Up
private extension ViewController {
    
    func configureVideoCollectionView() {
        videoCollectionView.delegate = videoDelegate
        videoCollectionView.dataSource = videoDataSource
        videoCollectionView.dragDelegate = videoDelegate
        videoCollectionView.dropDelegate = videoDelegate
    }

    @objc private func removeAllTapped(_ sender: UIButton) {
        videoDataSource.videoAssets.forEach {
            VideoAssetManager.deleteFile(at: $0.assetURL)
        }
        videoDataSource.videoAssets.removeAll()
        videoCollectionView.reloadData()
        thumbnailImageView.setImage(image: nil)
    }

    @objc private func addVideosTapped(_ sender: UIButton) {
        var config =  PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.selectionLimit = 0
        config.filter = .any(of: [.videos])
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }
    
    func setUpUI() {
        view.backgroundColor = .black
        setUpAddVideoButton()
        setUpVideoCollectionView()
        
        setUpThumbnailImageView()
        setUpLoadingIndicator()
        setUpRemoveAllButton()
        
        func setUpAddVideoButton() {
            view.addSubview(addVideoButton)
            [
                addVideoButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                addVideoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                
            ].forEach { $0.isActive = true }
        }
        
        func setUpVideoCollectionView() {
            view.addSubview(videoCollectionView)
            [
                videoCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                videoCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                videoCollectionView.bottomAnchor.constraint(equalTo: addVideoButton.topAnchor, constant: -20),
                videoCollectionView.heightAnchor.constraint(equalToConstant: 120)
            ].forEach { $0.isActive = true }
        }
        
        func setUpThumbnailImageView() {
            view.addSubview(thumbnailImageView)
            [
                thumbnailImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                thumbnailImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                thumbnailImageView.bottomAnchor.constraint(equalTo: videoCollectionView.topAnchor, constant: -20),
                thumbnailImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
            ].forEach { $0.isActive = true}
        }
        
        func setUpRemoveAllButton() {
            view.addSubview(removeAllButton)
            [
                removeAllButton.centerYAnchor.constraint(equalTo: addVideoButton.centerYAnchor),
                removeAllButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
            ].forEach { $0.isActive = true }
        }
        
        func setUpLoadingIndicator() {
            loadingIndicator.center = view.center
            view.addSubview(loadingIndicator)
        }
    }
    
}
