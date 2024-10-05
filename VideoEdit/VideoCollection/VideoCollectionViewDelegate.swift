//
//  VideoCollectionViewDelegate.swift
//  VideoEdit
//
//  Created by 현은백 on 10/4/24.
//

import UIKit.UICollectionViewFlowLayout
import AVFoundation

protocol VideoCollectionDelegate: NSObject {
    func updateThumbnailAtScrollPosition(scrollOffset: CGFloat)
}

class VideoCollectionViewDelegate: NSObject, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    
    var scale: CGFloat = 1.0
    weak var parentViewController: VideoCollectionDelegate?
    weak var dataSource: VideoCollectionViewDataSource? // Reference to the data source

    init(parentViewController: VideoCollectionDelegate, dataSource: VideoCollectionViewDataSource) {
        self.parentViewController = parentViewController
        self.dataSource = dataSource
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let videoAsset = dataSource?.videoAssets[safe: indexPath.item] {
            let duration = CMTimeGetSeconds(videoAsset.duration)
            let ratio = duration / VideoCollectionView.videoUnitSec
            return CGSize(width: ratio * VideoCollectionView.videoUnitWidth * scale, height: 100)
        } else {
            return CGSize(width: VideoCollectionView.emptyCellWidth * scale, height: 100)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let videoAssets = dataSource?.videoAssets, !videoAssets.isEmpty else { return }
        let scrollOffset = scrollView.contentOffset.x
        parentViewController?.updateThumbnailAtScrollPosition(scrollOffset: scrollOffset + VideoCollectionView.videoCollectionViewInsetvideoCollectionViewInset)
    }

    // MARK: - Drag and Drop
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard 
            let videoAsset = dataSource?.videoAssets[safe: indexPath.item],
            let urlAsset = videoAsset.asset as? AVURLAsset
        else { return [] }
        let itemProvider = NSItemProvider(object: urlAsset.url as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = videoAsset
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .forbidden)
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
    
    fileprivate func reorderItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView) {
        if let item = coordinator.items.first,
           let sourceIndexPath = item.sourceIndexPath,
           let videoAssets = dataSource?.videoAssets,
           videoAssets[safe: destinationIndexPath.item] != nil
        {
            collectionView.performBatchUpdates {
                guard let object = item.dragItem.localObject as? VideoAsset else { return }
                dataSource?.videoAssets.remove(at: sourceIndexPath.item)
                dataSource?.videoAssets.insert(object, at: destinationIndexPath.item)
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [destinationIndexPath])
            } completion: { _ in
//                self.parentViewController?.generateThumbnails()
            }
            coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
        }
    }
}
