//
//  ViewController.swift
//  VideoEdit
//
//  Created by 현은백 on 9/30/24.
//

import UIKit
import PhotosUI

class ViewController: UIViewController {

    private let addVideoButton: UIButton = {
        let button = UIButton()
        button.setTitle("Add Video", for: .normal)
        button.titleLabel?.textColor = .white
        button.backgroundColor = .red
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        button.heightAnchor.constraint(equalToConstant: 60).isActive = true
        return button
    }()
    
    private let removeAllButton: UIButton = {
        let button = UIButton()
        button.setTitle("Remove All", for: .normal)
        button.titleLabel?.textColor = .white
        button.backgroundColor = .blue
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 60).isActive = true
        button.heightAnchor.constraint(equalToConstant: 60).isActive = true
        return button
    }()
    
    private var videoDataSource: VideoCollectionViewDataSource!
    private var videoDelegate: VideoCollectionViewDelegate!
    private var videoCollectionView: VideoCollectionView = {
       let collectionView = VideoCollectionView()
       collectionView.translatesAutoresizingMaskIntoConstraints = false
       return collectionView
    }()
    
    private var thumbnailImageView: ThumbnailView = {
        let imageView = ThumbnailView()
        imageView.backgroundColor = .lightGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var loadingIndicator: UIActivityIndicatorView = {
        var loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        return loadingIndicator
    }()

    var contentWidth: CGFloat {
        return videoCollectionView.contentSize.width - VideoCollectionView.emptyCellWidth// remainingWidth
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureVideoCollectionView()
        setUpUI()
        addVideoButton.addTarget(self, action: #selector(addVideosTapped), for: .touchUpInside)
        removeAllButton.addTarget(self, action: #selector(removeAllTapped), for: .touchUpInside)
    }

    func generateThumbnails(asset: VideoAsset) async -> [CGImage] {
        var thumbnails: [CGImage] = []
        let imageGenerator = AVAssetImageGenerator(asset: asset.asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        let interval = CMTime(seconds: 1 / VideoCollectionView.scaleMax, preferredTimescale: 600)
        var currentTime = CMTime(seconds: 0, preferredTimescale: 600) // 시작 시간
        
        while currentTime < asset.duration {
            do {
                let cgImage = try await imageGenerator.image(at: currentTime).image
                thumbnails.append(cgImage)
            } catch {
                print("썸네일 생성 실패: \(error.localizedDescription)")
            }
            currentTime = CMTimeAdd(currentTime, interval)
        }
        return thumbnails
    }
    
    // 스크롤된 시점에 맞춰 해당 썸네일을 표시
    func updateThumbnailAtScrollPosition(scrollOffset: CGFloat) {
        guard
            scrollOffset >= 0
        else { return }
        
        let totalDuration = videoDataSource.totalDuration
        
        // 현재 시간에 해당하는 썸네일 인덱스 계산(역산)
        let index = CGFloat((scrollOffset * VideoCollectionView.videoUnitSec) / (VideoCollectionView.videoUnitWidth))
        let tuned = Int(index * VideoCollectionView.scaleMax / videoCollectionView.scale)
        if let cgImage = videoDataSource.videoThumbnails[safe: tuned]  {
            DispatchQueue.main.async {
                self.thumbnailImageView.setImage(image: UIImage(cgImage: cgImage))
            }
        }
        
        let currentTime = CGFloat((CMTimeGetSeconds(totalDuration)) * scrollOffset) / (contentWidth)
        thumbnailImageView.setProgress(progress: currentTime, total: CMTimeGetSeconds(totalDuration))
    }

}

extension ViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        guard !results.isEmpty else { return }
        loadingIndicator.startAnimating()
        
        let dispatchGroup = DispatchGroup()
        for result in results {
            guard let assetIdentifier = result.assetIdentifier else { continue }
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            
            guard let phAsset = fetchResult.firstObject else { continue }
                
            let options = PHVideoRequestOptions()
            options.version = .original
            
            dispatchGroup.enter()
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { (avAsset, _, error) in
                Task {
                    defer {
                        dispatchGroup.leave()
                    }
                    
                    if let avAsset,
                       let duration = try? await avAsset.load(.duration)
                    {
                        let asset = VideoAsset(asset: avAsset, duration: duration)
                        let thumbnails = await self.generateThumbnails(asset: asset)
                        asset.thumbnails = thumbnails
                        self.videoDataSource.videoAssets.append(asset)
                    } else if let error {
                        print("AVAsset 로드 중 오류 발생: \(error)")
                    }
                    
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // 모든 비디오가 로드된 후 컬렉션 뷰 갱신 및 로딩 인디케이터 중지
            self.loadingIndicator.stopAnimating()
            self.videoCollectionView.reloadData()
        }
    }
}

//MARK: Set Up
private extension ViewController {
    
    func configureVideoCollectionView() {
        videoDataSource = VideoCollectionViewDataSource()
        videoDelegate = VideoCollectionViewDelegate(parentViewController: self, dataSource: videoDataSource)
        
        videoCollectionView.delegate = videoDelegate
        videoCollectionView.dataSource = videoDataSource
        videoCollectionView.dragDelegate = videoDelegate
        videoCollectionView.dropDelegate = videoDelegate
    }

    @objc private func removeAllTapped(_ sender: UIButton) {
        videoDataSource.videoAssets.removeAll()
        videoCollectionView.reloadData()
        thumbnailImageView.setImage(image: nil)
    }
    
    @objc private func addVideosTapped(_ sender: UIButton) {
        var config =  PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.selectionLimit = 0 // 제한 없음
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
