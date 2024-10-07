//
//  ViewController.swift
//  VideoEdit
//
//  Created by 현은백 on 9/30/24.
//

import UIKit
import PhotosUI

class VideoThumbnailViewController: UIViewController {
    
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
    
    private let saveOpenButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "square.and.arrow.down")?.withTintColor(.white), for: .normal)
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
        saveOpenButton.addTarget(self, action: #selector(saveOpenTapped), for: .touchUpInside)
        NotificationCenter.default.addObserver(self, selector: #selector(clearData), name: UIApplication.willTerminateNotification, object: nil)
        Task {
            await self.checkSavedVideos()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkPhotoLibraryAuthorization()
    }
    
    @objc func clearData() {
        videoDataSource.videoAssets.forEach { asset in
            // Core Data에 저장되지 않은 비디오만 삭제합니다.
            if !asset.isSaved {
                // 파일 삭제 메서드 호출
                VideoAssetManager.deleteFile(at: asset.assetURL)
                print("Deleted video file at: \(asset.assetURL)")
            } else {
                print("Video file is saved, not deleting: \(asset.assetURL)")
            }
        }
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

extension VideoThumbnailViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard !results.isEmpty else { return }
        
        loadingIndicator.startAnimating()
        availiblityButtonsWhileProcessing(isEnable: false)
        
        Task {
            let size = self.thumbnailImageView.frame.size
            VideoAssetManager.shared.thumbnailSize = .init(width: size.width, height: size.height)
            let videoAssets = await VideoAssetManager.shared.fetchAndExportVideos(results: results)
            videoDataSource.videoAssets.append(contentsOf: videoAssets)
            DispatchQueue.main.async {
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

extension VideoThumbnailViewController: VideoCollectionDelegate {
    
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

extension VideoThumbnailViewController {
    
    private func checkSavedVideos() async {
        let isExist = await isSavedVideosExist()
        setSaveOpenButtonImage(isExist: isExist)
    }
    
    private func isSavedVideosExist() async -> Bool {
        let videoAssets = await VideoAssetManager.shared.fetchVideoAssets()
        return !videoAssets.isEmpty
    }
    
    private func removeAll() {
        videoDataSource.videoAssets.removeAll()
        videoCollectionView.reloadData()
        thumbnailImageView.setImage(image: nil)
    }
}

//MARK: Set Up
private extension VideoThumbnailViewController {
    
    func configureVideoCollectionView() {
        videoCollectionView.delegate = videoDelegate
        videoCollectionView.dataSource = videoDataSource
        videoCollectionView.dragDelegate = videoDelegate
        videoCollectionView.dropDelegate = videoDelegate
    }

    @objc private func removeAllTapped(_ sender: UIButton) {
        removeAll()
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
    
    @objc private func saveOpenTapped(_ sender: UIButton) {
        Task {
            let results = await VideoAssetManager.shared.fetchVideoAssets()
            if !results.isEmpty {
                removeAll()
                videoDataSource.videoAssets = results
                VideoAssetManager.shared.deleteAllVideoAssets()
                setSaveOpenButtonImage(isExist: false)
            } else if !videoDataSource.videoAssets.isEmpty {
                VideoAssetManager.shared.saveVideoAssets(videoAssets: videoDataSource.videoAssets)
                setSaveOpenButtonImage(isExist: true)
            }
        }
    }
    
    func setUpUI() {
        view.backgroundColor = .black
        setUpAddVideoButton()
        setUpVideoCollectionView()
        
        setUpThumbnailImageView()
        setUpLoadingIndicator()
        setUpRemoveAllButton()
        setUpSaveOpenButton()
        
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
        
        func setUpSaveOpenButton() {
            view.addSubview(saveOpenButton)
            [
                saveOpenButton.centerYAnchor.constraint(equalTo: addVideoButton.centerYAnchor),
                saveOpenButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
            ].forEach { $0.isActive = true }
        }
        
        func setUpLoadingIndicator() {
            loadingIndicator.center = view.center
            view.addSubview(loadingIndicator)
        }
    }
    
    func setSaveOpenButtonImage(isExist: Bool) {
        let buttonImage = isExist ? "square.and.arrow.up" : "square.and.arrow.down"
        saveOpenButton.setImage(UIImage(systemName: buttonImage), for: .normal)
    }
    
}
