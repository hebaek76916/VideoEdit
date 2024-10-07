//
//  VideoAssetManager.swift
//  VideoEdit
//
//  Created by 현은백 on 10/6/24.
//

import AVFoundation
import PhotosUI

class VideoAssetManager {

    static let shared = VideoAssetManager() // 싱글톤으로 관리
    
    var thumbnailSize: CGSize = CGSize(width: 300, height: 200)

    private let dispatchGroup = DispatchGroup()
    private let semaphore = DispatchSemaphore(value: 1)

    // 비디오를 가져오는 메서드
    func fetchAndExportVideos(results: [PHPickerResult]) async -> [VideoAsset] {
        guard !results.isEmpty else { return [] }
        
        var videoAssets: [VideoAsset] = []
        
        // 백그라운드에서 작업
        await withTaskGroup(of: VideoAsset?.self) { group in
            for result in results {
                group.addTask {
                    return await self.processPickerResult(result)
                }
            }
            
            // 각 비디오 처리가 완료되면 결과를 모음
            for await videoAsset in group {
                if let asset = videoAsset {
                    videoAssets.append(asset)
                }
            }
        }
        return videoAssets
    }

    // 개별 비디오 처리
    private func processPickerResult(_ result: PHPickerResult) async -> VideoAsset? {
        guard let assetIdentifier = result.assetIdentifier else { return nil }
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let phAsset = fetchResult.firstObject else { return nil }
        
        let options = PHVideoRequestOptions()
        options.version = .original
        
        let (avAsset, duration): (AVAsset?, CMTime?) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                self.dispatchGroup.enter()
                self.semaphore.wait() // 동시 작업 수 제한
                
                PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { (avAsset, _, error) in
                    Task {
                        defer {
                            self.dispatchGroup.leave()
                            self.semaphore.signal()
                        }
                        
                        if let avAsset {
                            if let duration = try? await avAsset.load(.duration) {
                                continuation.resume(returning: (avAsset, duration))
                            } else {
                                continuation.resume(returning: (nil, nil))
                            }
                        } else if let error {
                            print("AVAsset 로드 중 오류 발생: \(error)")
                            continuation.resume(returning: (nil, nil))
                        }
                    }
                }
            }
        }

        guard 
            let avAsset,
            let duration
        else {
            return nil
        }

        // AVAsset을 파일로 저장하는 함수 호출 및 URL 반환
        let savedURL = await withCheckedContinuation { continuation in
            self.exportAVAssetToFile(avAsset: avAsset, duration: duration) { savedURL in
                continuation.resume(returning: savedURL)
            }
        }
        
        guard let savedURL = savedURL else {
            print("비디오 파일 저장 실패")
            return nil
        }

        // URL로 VideoAsset 객체 생성
        let asset = VideoAsset(assetURL: savedURL, duration: duration)
        
        // 썸네일 생성
        let thumbnails = await self.generateThumbnails(asset: asset)
        asset.thumbnails = thumbnails
        
        return asset
    }

    // AVAsset을 파일로 저장하는 메서드
    private func exportAVAssetToFile(avAsset: AVAsset, duration: CMTime, completion: @escaping (URL?) -> Void) {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality) else {
            completion(nil)
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                print("비디오가 성공적으로 저장되었습니다: \(outputURL)")
                completion(outputURL)
            case .failed, .cancelled:
                print("비디오 저장 실패: \(exportSession.error?.localizedDescription ?? "알 수 없는 오류")")
                completion(nil)
            default:
                break
            }
        }
    }

    func generateThumbnails(asset: VideoAsset) async -> [CGImage] {
        var thumbnails: [CGImage] = []
        
        // URL로부터 AVAsset을 생성
        let avAsset = AVAsset(url: asset.assetURL)
        
        let imageGenerator = AVAssetImageGenerator(asset: avAsset)
        imageGenerator.maximumSize = thumbnailSize
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        imageGenerator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        let interval = CMTime(seconds: 1, preferredTimescale: 600)
        var currentTime = CMTime(seconds: 0, preferredTimescale: 600)
        
        while currentTime <= asset.duration {
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
    
    // 비디오 파일 삭제 메서드
    static func deleteFile(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("비디오 파일이 삭제되었습니다: \(url)")
            } else {
                print("No video found to delete at: \(url)")
            }
        } catch {
            print("비디오 파일 삭제 실패: \(error.localizedDescription)")
        }
    }
    
}
