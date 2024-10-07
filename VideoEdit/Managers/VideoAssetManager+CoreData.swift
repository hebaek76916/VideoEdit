//
//  VideoAssetManager+CoreData.swift
//  VideoEdit
//
//  Created by 현은백 on 10/7/24.
//

import UIKit
import CoreMedia
import CoreData

//MARK: Core Data
extension VideoAssetManager {
    
    func deleteAllVideoAssets() {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()

        do {
            // 기존 비디오 자산을 가져옵니다.
            let videoAssetEntities = try context.fetch(fetchRequest)
            for entity in videoAssetEntities {
                context.delete(entity)
            }
            try context.save()
            print("All VideoAssets have been deleted successfully.")
        } catch {
            print("Failed to delete VideoAssets: \(error)")
        }
    }
    
    func saveVideoAssets(videoAssets: [VideoAsset]) {
        let context = CoreDataStack.shared.context

        // 기존에 저장된 데이터 제거
        deleteAllVideoAssets()
        
        for asset in videoAssets {
            asset.isSaved = true
            let videoAssetEntity = Entity(context: context)
            videoAssetEntity.assetURL = asset.assetURL.path
            videoAssetEntity.duration = asset.duration.seconds
        }
        
        do {
            try context.save()
            print("VideoAssets saved successfully!")
        } catch {
            print("Failed to save VideoAssets: \(error)")
        }
    }

    // VideoAsset 불러오기 메서드
    func fetchVideoAssets() async -> [VideoAsset] {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()

        do {
            let videoAssetEntities = try context.fetch(fetchRequest)
            // 비동기적으로 변환하여 모든 VideoAssetEntity를 VideoAsset으로 변환
            let videoAssets = await withTaskGroup(of: VideoAsset?.self) { group in
                for entity in videoAssetEntities {
                    group.addTask {
                        return await self.convertEntityToVideoAsset(entity)
                    }
                }

                return await group.reduce(into: [VideoAsset]()) { result, videoAsset in
                    if let asset = videoAsset {
                        result.append(asset)
                    }
                }
            }
            return videoAssets
            
        } catch {
            print("Failed to fetch VideoAssets: \(error)")
            return []
        }
    }
    
    
    // VideoAssetEntity를 VideoAsset으로 변환하는 메서드
    private func convertEntityToVideoAsset(_ entity: Entity) async -> VideoAsset? {
        guard let assetURLString = entity.assetURL else { return nil }
        let duration = CMTimeMakeWithSeconds(entity.duration, preferredTimescale: 600)
        let asset = VideoAsset(assetURL: URL(filePath: assetURLString), duration: duration)
        let thumbnails = await generateThumbnails(asset: asset)
        asset.thumbnails = thumbnails
        return asset
    }
    
}
