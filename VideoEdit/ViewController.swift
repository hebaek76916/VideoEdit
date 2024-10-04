//
//  ViewController.swift
//  VideoEdit
//
//  Created by 현은백 on 9/30/24.
//

import UIKit
import PhotosUI

class ViewController: UIViewController {
    
    private var scale: CGFloat = 1.0 // 초기 스케일
    
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

    var totalDuration: CMTime? // 비디오의 총 길이 저장
    var contentWidth: CGFloat {
        return videoCollectionView.contentSize.width - VideoCollectionView.emptyCellWidth// remainingWidth
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureVideoCollectionView()
        setUpUI()
        addVideoButton.addTarget(self, action: #selector(addVideosTapped), for: .touchUpInside)
        removeAllButton.addTarget(self, action: #selector(removeAllTapped), for: .touchUpInside)
        
        // 핀치 제스처 인식기 추가
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        videoCollectionView.addGestureRecognizer(pinchGesture)
    }
    
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        // 스케일 값 제한 (0.8 ~ 2.0 사이로 제한)
        scale = max(0.8, min(gesture.scale, 2.0))
        
        if gesture.state == .changed || gesture.state == .ended {
            videoCollectionView.collectionViewLayout.invalidateLayout() // 레이아웃 무효화
            // TODO: 스케일 값에 따라 썸네일 다시 생성
//            self.generateThumbnails()
        }
    }
 
//    private func generateThumbnails_1() async throws -> CGImage? {
//        for asset in videoAssets {
//            let generator = AVAssetImageGenerator(asset: asset)
//            let thumbnail = try await generator.image(at: totalDuration!).image
//            return thumbnail
//        }
//        return nil
//    }
//    
    func generateThumbnails() {
        videoDataSource.videoThumbnails.removeAll()
 
        // 백그라운드에서 썸네일 생성
        for (index, asset) in self.videoDataSource.videoAssets.enumerated() {
            let imageGenerator = AVAssetImageGenerator(asset: asset.asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let durationInSeconds = CMTimeGetSeconds(asset.duration)
            let interval = 1.0 / Double(self.scale)
            var second: Double = 0
            
            while second < durationInSeconds {
                let thumbnailTime = CMTime(seconds: second, preferredTimescale: 600)
                do {
                    let cgImage = try imageGenerator.copyCGImage(at: thumbnailTime, actualTime: nil)
                    let uiImage = UIImage(cgImage: cgImage)
                    self.videoDataSource.videoThumbnails.append(uiImage)
                    if second == 0 {
                        videoDataSource.videoAssets[safe: index]?.setThumbnail(cgImage: cgImage)
                    }
                } catch {
                    print("썸네일 생성 실패: \(error.localizedDescription)")
                }
                second += interval
            }
        }
        
    }
    
    // 스크롤된 시점에 맞춰 해당 썸네일을 표시
    func updateThumbnailAtScrollPosition(scrollOffset: CGFloat) {
        guard
            scrollOffset >= 0,
            let totalDuration
        else { return }
        
        // 현재 시간에 해당하는 썸네일 인덱스 계산(역산)
        let index = CGFloat((scrollOffset * VideoCollectionView.videoUnitSec) / (VideoCollectionView.videoUnitWidth))
        let tuned = Int(index / scale)
        
        if let uiImage = videoDataSource.videoThumbnails[safe: tuned]  {
            DispatchQueue.main.async {
                self.thumbnailImageView.setImage(image: uiImage)
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
                    if let avAsset,
                       let duration = try? await avAsset.load(.duration)
                    {
                        let asset = VideoAsset(asset: avAsset, duration: duration)
                        self.videoDataSource.videoAssets.append(asset)
                        self.totalDuration = CMTimeAdd(self.totalDuration ?? .zero, duration)
                        
                    } else if let error {
                        print("AVAsset 로드 중 오류 발생: \(error)")
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // 모든 비디오가 로드된 후 컬렉션 뷰 갱신 및 로딩 인디케이터 중지
            self.generateThumbnails()// Generate 미리 하고 있음 되겠는데?..
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
        videoDataSource.videoThumbnails.removeAll()
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
