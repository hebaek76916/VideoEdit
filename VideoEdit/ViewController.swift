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
    
   private var videoCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 3
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .blue
        collectionView.isScrollEnabled = true
        collectionView.showsHorizontalScrollIndicator = true
        collectionView.alwaysBounceHorizontal = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .lightGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var loadingIndicator: UIActivityIndicatorView = {
        var loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        return loadingIndicator
    }()
    
    var videoAssets: [AVAsset] = []
    var mergedVideoAsset: AVAsset?  // 결합된 비디오를 기반으로 생성된 AVAsset
    var mergedVideoURL: URL?
    var totalDuration: CMTime? // 비디오의 총 길이 저장
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureVideoCollectionView()
        setUpUI()
        addVideoButton.addTarget(self, action: #selector(test), for: .touchUpInside)
    }
    
    @objc func test(_ sender: UIButton) {
        var config =  PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.selectionLimit = 0 // 제한 없음
        config.filter = .any(of: [.videos])
        config.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }
    
    private func configureVideoCollectionView() {
        videoCollectionView.delegate = self
        videoCollectionView.dataSource = self
        videoCollectionView.dragDelegate = self
        videoCollectionView.dropDelegate = self
        videoCollectionView.register(VideoCell.self, forCellWithReuseIdentifier: "VideoCell")
    }
    
    // 비디오 결합 및 썸네일 생성 함수
    func mergeVideosAndDisplayThumbnail() {
        guard !videoAssets.isEmpty else { return }

        // 비디오를 결합하기 위한 AVMutableComposition 생성
        let composition = AVMutableComposition()

        // 현재 시간 추적을 위한 변수
        var currentTime = CMTime.zero

        // 비디오 결합
        for asset in videoAssets {
            if let videoTrack = asset.tracks(withMediaType: .video).first {
                let timeRange = CMTimeRange(start: .zero, duration: asset.duration)

                // 비디오 트랙을 추가
                let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
                try? compositionVideoTrack?.insertTimeRange(timeRange, of: videoTrack, at: currentTime)

                // 비디오의 오디오 트랙 추가 (있는 경우)
                if let audioTrack = asset.tracks(withMediaType: .audio).first {
                    let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    try? compositionAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: currentTime)
                }

                // 다음 비디오가 이어질 시간 업데이트
                currentTime = CMTimeAdd(currentTime, asset.duration)
            }
        }

        // 결합된 비디오를 임시 디렉토리에 저장할 URL 설정
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mergedVideo.mp4")
        
        // 기존 파일 삭제 (동일한 경로에 파일이 이미 존재할 경우)
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try? FileManager.default.removeItem(at: exportURL)
        }

        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        exporter?.outputURL = exportURL
        exporter?.outputFileType = .mp4
        exporter?.shouldOptimizeForNetworkUse = true

        exporter?.exportAsynchronously {
            if exporter?.status == .completed {
                DispatchQueue.main.async {
                    // 결합된 비디오 URL 저장
                    self.mergedVideoURL = exportURL
                    
                    if let mergedVideoURL = self.mergedVideoURL {
                        let mergedVideo = AVAsset(url: mergedVideoURL)
                        self.mergedVideoAsset = mergedVideo
                        self.totalDuration = mergedVideo.duration
                    }
                    
//                    // 결합된 비디오의 썸네일 생성
                    self.generateThumbnail(from: exportURL)
                }
            } else {
                DispatchQueue.main.async {
                    if let error = exporter?.error {
                        print("비디오 결합 실패: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // 결합된 비디오의 썸네일 생성
    func generateThumbnail(from url: URL) {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1.0, preferredTimescale: 600) // 첫 번째 프레임에서 썸네일 생성
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            
            // 상단의 UIImageView에 썸네일 표시
            self.thumbnailImageView.image = uiImage
        } catch {
            print("썸네일 생성 실패: \(error.localizedDescription)")
        }
    }
    
    // 스크롤된 시점에 맞춰 해당 썸네일을 표시
    func updateThumbnailAtScrollPosition(scrollOffset: CGFloat) {
        guard let totalDuration = totalDuration else { return }
        
        // 컬렉션 뷰의 스크롤 범위와 비디오 길이를 매핑
        let totalScrollWidth = videoCollectionView.contentSize.width - videoCollectionView.bounds.width
        
        // 현재 스크롤 위치에 따라 전체 시간 비율 계산
        let scrollRatio = scrollOffset / totalScrollWidth
        let currentTimeInSeconds = CMTimeGetSeconds(totalDuration) * scrollRatio
        
        // 현재 시간을 CMTime으로 변환
        let time = CMTime(seconds: currentTimeInSeconds, preferredTimescale: 600)
        
        // 썸네일 생성
        if let mergedVideoURL = mergedVideoURL { // mergedVideoURL은 비디오의 URL
            let asset = AVAsset(url: mergedVideoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            // 썸네일 생성 비동기
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, _, result, error in
                if let error = error {
                    print("썸네일 생성 실패: \(error.localizedDescription)")
                    return
                }
                if let image = image {
                    let uiImage = UIImage(cgImage: image)
                    DispatchQueue.main.async {
                        self.thumbnailImageView.image = uiImage // UI 업데이트는 메인 스레드에서
                    }
                }
            }
        }
    }

}

extension ViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // 피커 닫기
        picker.dismiss(animated: true, completion: nil)
        guard !results.isEmpty else { return }

        loadingIndicator.startAnimating()
        
        let dispatchGroup = DispatchGroup()

        for result in results {
            if let assetIdentifier = result.assetIdentifier {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                if let phAsset = fetchResult.firstObject {
                    
                    let options = PHVideoRequestOptions()
                    options.version = .original
                    
                    dispatchGroup.enter()
                    PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { (avAsset, _, error) in
                        if let avAsset = avAsset {
                            self.videoAssets.append(avAsset)
                        } else if let error = error {
                            print("AVAsset 로드 중 오류 발생: \(error)")
                        }
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // 모든 비디오가 로드된 후 컬렉션 뷰 갱신 및 로딩 인디케이터 중지
            self.mergeVideosAndDisplayThumbnail()
            self.loadingIndicator.stopAnimating()
            self.videoCollectionView.reloadData()
        }
    }
}

extension ViewController: UICollectionViewDelegateFlowLayout {
    
    func getVideoDuration(asset: AVAsset) -> Double {
        let durationInSeconds = CMTimeGetSeconds(asset.duration)
        return durationInSeconds
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let unitSec: Double = 30.0
        let unitWidth: Double = 100.0
        let videoAsset = videoAssets[indexPath.item]
        let duration = getVideoDuration(asset: videoAsset)
        let ratio = duration / unitSec
        return CGSize(width: ratio * unitWidth, height: 100)
    }
    
}

extension ViewController: UICollectionViewDelegate,
                          UICollectionViewDataSource,
                          UICollectionViewDragDelegate,
                          UICollectionViewDropDelegate
{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videoAssets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCell", for: indexPath) as! VideoCell
        let videoAsset = videoAssets[indexPath.item]
        cell.configure(with: videoAsset)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let videoAsset = videoAssets[indexPath.item]
        // AVURLAsset으로 캐스팅하여 URL을 얻음
        if let urlAsset = videoAsset as? AVURLAsset {
            let itemProvider = NSItemProvider(object: urlAsset.url as NSURL)
            let dragItem = UIDragItem(itemProvider: itemProvider)
            return [dragItem]
        }
        
        return []
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }
        
        for item in coordinator.items {
            if let sourceIndexPath = item.sourceIndexPath {
                let asset = videoAssets.remove(at: sourceIndexPath.item)
                videoAssets.insert(asset, at: destinationIndexPath.item)
                collectionView.performBatchUpdates({
                    collectionView.deleteItems(at: [sourceIndexPath])
                    collectionView.insertItems(at: [destinationIndexPath])
                }, completion: nil)
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let scrollOffset = scrollView.contentOffset.x
        updateThumbnailAtScrollPosition(scrollOffset: scrollOffset)
    }
    
}

//MARK: Set Up UI
private extension ViewController {
    func setUpUI() {
        setUpAddVideoButton()
        setUpVideoCollectionView()
        setUpThumbnailImageView()
        setUpLoadingIndicator()
        
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
                thumbnailImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -20)
            ].forEach { $0.isActive = true}
        }
        
        func setUpLoadingIndicator() {
            loadingIndicator.center = view.center
            view.addSubview(loadingIndicator)
        }
    }
}
