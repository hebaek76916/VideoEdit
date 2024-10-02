//
//  ViewController.swift
//  VideoEdit
//
//  Created by 현은백 on 9/30/24.
//

import UIKit
import PhotosUI

class ViewController: UIViewController {
    
    static let videoUnitSec: Double = 30.0
    static let videoUnitWidth: Double = 100.0
    
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
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 10)
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
    var videoThumbnails: [UIImage] = [] // 썸네일 이미지 배열
    var mergedVideoAsset: AVAsset?  // 결합된 비디오를 기반으로 생성된 AVAsset
    var mergedVideoURL: URL?
    var totalDuration: CMTime? // 비디오의 총 길이 저장
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureVideoCollectionView()
        setUpUI()
        addVideoButton.addTarget(self, action: #selector(addVideosTapped), for: .touchUpInside)
    }
    
    @objc func addVideosTapped(_ sender: UIButton) {
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

    private func generateThumbnails() {
        for asset in videoAssets {
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let durationInSeconds = CMTimeGetSeconds(asset.duration)
            // 비디오의 길이에 따라 1초마다 썸네일 생성
            for second in 0..<Int(durationInSeconds) {
                let thumbnailTime = CMTime(seconds: Double(second), preferredTimescale: 600)
                do {
                    let cgImage = try imageGenerator.copyCGImage(at: thumbnailTime, actualTime: nil)
                    let uiImage = UIImage(cgImage: cgImage)
                    videoThumbnails.append(uiImage)
                } catch {
                    print("썸네일 생성 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    // 스크롤된 시점에 맞춰 해당 썸네일을 표시
    func updateThumbnailAtScrollPosition(scrollOffset: CGFloat) {
        guard let totalDuration = totalDuration else { return }
        
        // 현재 시간에 해당하는 썸네일 인덱스 계산(역산)
        let index = Int(scrollOffset / ViewController.videoUnitWidth * ViewController.videoUnitSec)

        if let uiImage = videoThumbnails[safe: index]  {
            DispatchQueue.main.async {
                self.thumbnailImageView.image = uiImage
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
            self.generateThumbnails()
            self.totalDuration = self.calculateTotalDuration(videoAssets: self.videoAssets)
            self.loadingIndicator.stopAnimating()
            self.videoCollectionView.reloadData()
        }
    }
    
    func calculateTotalDuration(videoAssets: [AVAsset]) -> CMTime? {
        var totalDuration = CMTime.zero
        for asset in videoAssets {
            totalDuration = CMTimeAdd(totalDuration, asset.duration)
        }
        return totalDuration
    }
}

extension ViewController: UICollectionViewDelegateFlowLayout {
    
    func getVideoDuration(asset: AVAsset) -> Double {
        let durationInSeconds = CMTimeGetSeconds(asset.duration)
        return durationInSeconds
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let videoAsset = videoAssets[indexPath.item]
        let duration = getVideoDuration(asset: videoAsset)
        let ratio = duration / ViewController.videoUnitSec
        return CGSize(width: ratio * ViewController.videoUnitWidth, height: 100)
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
