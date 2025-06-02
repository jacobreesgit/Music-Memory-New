import Foundation
import UIKit

class ArtworkManager {
    static let shared = ArtworkManager()
    
    private let artworkDirectory: URL
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        artworkDirectory = documentsPath.appendingPathComponent("Artwork")
        
        // Create artwork directory if it doesn't exist
        try? FileManager.default.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
    }
    
    func save(artwork: UIImage, for persistentID: UInt64) -> String? {
        guard let data = artwork.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileName = "\(persistentID).jpg"
        let fileURL = artworkDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("Failed to save artwork: \(error)")
            return nil
        }
    }
    
    func artworkURL(for fileName: String) -> URL {
        return artworkDirectory.appendingPathComponent(fileName)
    }
    
    func loadArtwork(for fileName: String) -> UIImage? {
        let url = artworkURL(for: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    func deleteArtwork(for fileName: String) {
        let url = artworkURL(for: fileName)
        try? FileManager.default.removeItem(at: url)
    }
    
    // Clean up orphaned artwork files
    func cleanupOrphanedArtwork(validFileNames: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: artworkDirectory.path) else { return }
        
        for file in files {
            if !validFileNames.contains(file) {
                deleteArtwork(for: file)
            }
        }
    }
}
