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
    static let videoCollectionViewInsetvideoCollectionViewInset: Double = 100.0
    static let emptyCellWidth: Double = 1000.0
    
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
    
   private var videoCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .blue
        collectionView.isScrollEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dragInteractionEnabled = true
        collectionView.contentInset = .init(top: 0, left: ViewController.videoCollectionViewInsetvideoCollectionViewInset, bottom: 0, right: 0)
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
    
    var videoAssets: [AVAsset] = []
    var videoThumbnails: [UIImage] = [] // 썸네일 이미지 배열
    var totalDuration: CMTime? // 비디오의 총 길이 저장
    private let additionalCells = 1 // 추가 여유 공간을 위한 빈 셀
    var contentWidth: CGFloat {
        return getRemainingWidthExcludingCell(at: IndexPath(item: videoAssets.count, section: 0))
    }
    
    func getRemainingWidthExcludingCell(at indexPath: IndexPath) -> CGFloat {
        // 1. 전체 콘텐츠 사이즈 구하기
        let totalContentWidth = videoCollectionView.contentSize.width

        // 2. 특정 셀의 크기 구하기 (UICollectionViewDelegateFlowLayout의 메서드로부터 사이즈를 가져옴)
        let cellWidth = collectionView(videoCollectionView, layout: videoCollectionView.collectionViewLayout, sizeForItemAt: indexPath).width

        // 3. 특정 셀의 width를 제외한 나머지 너비 계산
        let remainingWidth = totalContentWidth - cellWidth

        return remainingWidth
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
            // 스케일 값에 따라 썸네일 다시 생성
//            self.generateThumbnails()
            videoCollectionView.collectionViewLayout.invalidateLayout() // 레이아웃 무효화
        }
    }
//    
//    private func generateThumbnails_1() async throws -> CGImage? {
//        for asset in videoAssets {
//            let generator = AVAssetImageGenerator(asset: asset)
//            let thumbnail = try await generator.image(at: totalDuration!).image
//            return thumbnail
//        }
//        return nil
//    }
//    
    private func generateThumbnails() {
        videoThumbnails.removeAll()

        // 백그라운드에서 썸네일 생성
        DispatchQueue.global(qos: .userInitiated).async {
            for asset in self.videoAssets {
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                
                let durationInSeconds = CMTimeGetSeconds(asset.duration)
                let interval = 1.0 / Double(self.scale)
                var second: Double = 0
                
                while second < durationInSeconds {
                    let thumbnailTime = CMTime(seconds: second, preferredTimescale: 600)
                    do {
                        let cgImage = try imageGenerator.copyCGImage(at: thumbnailTime, actualTime: nil)
                        let uiImage = UIImage(cgImage: cgImage)
                        
                        // 메인 스레드에서 UI 업데이트
                        DispatchQueue.main.async {
                            self.videoThumbnails.append(uiImage)
                            // 썸네일 업데이트, 필요 시 컬렉션 뷰 갱신
//                            self.videoCollectionView.reloadData()
                        }
                    } catch {
                        print("썸네일 생성 실패: \(error.localizedDescription)")
                    }
                    second += interval
                }
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
        let index = CGFloat((scrollOffset * ViewController.videoUnitSec) / (ViewController.videoUnitWidth))
        let tuned = Int(index / scale)
        
        if let uiImage = videoThumbnails[safe: tuned]  {
            DispatchQueue.main.async {
                self.thumbnailImageView.setImage(image: uiImage)
            }
        }
        
        let a = CGFloat((CMTimeGetSeconds(totalDuration)) * scrollOffset) / (contentWidth)
        thumbnailImageView.setProgress(progress: a, total: CMTimeGetSeconds(totalDuration))
    }

}

extension ViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
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
        if let videoAsset = videoAssets[safe: indexPath.item] {
            let duration = getVideoDuration(asset: videoAsset)
            let ratio = duration / ViewController.videoUnitSec
            return CGSize(width: ratio * ViewController.videoUnitWidth * scale, height: 100)
        } else {
            return CGSize(width: ViewController.emptyCellWidth * scale, height: 100)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !videoAssets.isEmpty else { return }
        let scrollOffset = scrollView.contentOffset.x
        print("scroll offset : ", scrollOffset)
        updateThumbnailAtScrollPosition(scrollOffset: scrollOffset + ViewController.videoCollectionViewInsetvideoCollectionViewInset)
    }

    
    fileprivate func reorderItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView) {
        if let item = coordinator.items.first,
           let sourceIndexPath = item.sourceIndexPath,
           let _ = videoAssets[safe: destinationIndexPath.item]
        {
            collectionView.performBatchUpdates {
                self.videoAssets.remove(at: sourceIndexPath.item)
                self.videoAssets.insert((item.dragItem.localObject as? AVAsset)!, at: destinationIndexPath.item)
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [destinationIndexPath])
            } completion: { _ in
                self.generateThumbnails()
            }
            coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
        }
    }
    
}

extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videoAssets.count + additionalCells
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCell", for: indexPath) as! VideoCell
        if let videoAsset = videoAssets[safe: indexPath.item] {
            cell.configure(with: videoAsset)
        } else {
            cell.contentView.layer.borderWidth = 2.0
            cell.contentView.layer.borderColor = UIColor.gray.cgColor
            cell.backgroundColor = .systemPink
        }
        return cell
    }
}

extension ViewController: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard
            let videoAsset = videoAssets[safe: indexPath.item],
            let urlAsset = videoAsset as? AVURLAsset
        else { return [] }
        
        let itemProvider = NSItemProvider(object: urlAsset.url as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = videoAsset// 로컬 오브젝트로 비디오 자산 설정
        return [dragItem]
    }
    
}

extension ViewController: UICollectionViewDropDelegate {
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }
    
    private func collectionView(_ collectionView: UICollectionView, canHandle session: UIDragSession) -> Bool {
        // 드롭된 항목이 NSURL 타입인지 확인
        return session.items.contains { item in
            item.itemProvider.hasItemConformingToTypeIdentifier("public.url")
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        
        var destinationIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath {
            destinationIndexPath = indexPath
        } else {
            let row = collectionView.numberOfItems(inSection: 0)
            destinationIndexPath = IndexPath(item: row - 1, section: 0)
        }
        if coordinator.proposal.operation == .move {
            reorderItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
        }
    }
}

//MARK: Set Up
private extension ViewController {
    
    func configureVideoCollectionView() {
        videoCollectionView.delegate = self
        videoCollectionView.dataSource = self
        videoCollectionView.dragDelegate = self
        videoCollectionView.dropDelegate = self
        videoCollectionView.register(VideoCell.self, forCellWithReuseIdentifier: "VideoCell")
    }

    @objc private func removeAllTapped(_ sender: UIButton) {
        videoThumbnails.removeAll()
        videoAssets.removeAll()
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
        setUpVideoCollectionThresholdLineView()
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
        
        func setUpVideoCollectionThresholdLineView() {
            let lineView = UIView()
            lineView.translatesAutoresizingMaskIntoConstraints = false
            lineView.backgroundColor = .white
            if let collectionSuperView = videoCollectionView.superview {
                collectionSuperView.addSubview(lineView)
                [
                    lineView.leadingAnchor.constraint(equalTo: collectionSuperView.leadingAnchor, constant: ViewController.videoCollectionViewInsetvideoCollectionViewInset),
                    lineView.topAnchor.constraint(equalTo: videoCollectionView.topAnchor),
                    lineView.bottomAnchor.constraint(equalTo: videoCollectionView.bottomAnchor),
                    lineView.widthAnchor.constraint(equalToConstant: 3)
                ].forEach { $0.isActive = true }
            }
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
