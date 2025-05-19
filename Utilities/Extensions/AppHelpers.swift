//
//  AppHelpers.swift
//  Music Memory New
//
//  Created by Jacob Rees on 19/05/2025.
//

import Foundation

struct AppHelpers {
    static func formatDuration(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    static func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    static func formatYear(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    // MARK: - Fuzzy Search Functionality
    
    /// Performs a fuzzy match between a source string and a query
    /// - Parameters:
    ///   - source: The source string to search within
    ///   - query: The search query to look for
    /// - Returns: True if there's a match according to fuzzy search rules
    static func fuzzyMatch(_ source: String?, _ query: String) -> Bool {
        guard let source = source?.lowercased() else { return false }
        let query = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if query.isEmpty { return true }
        if source.contains(query) { return true }
        
        // Split search into words for multi-word matching
        let queryWords = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if queryWords.count > 1 {
            // All words must be found somewhere in the source
            return queryWords.allSatisfy { word in
                source.contains(word)
            }
        }
        
        // For single words, use Levenshtein distance for typo tolerance
        // Adjust distance threshold based on query length
        let maxDistance = min(2, max(1, query.count / 4))
        return levenshteinDistance(source, query) <= maxDistance
    }
    
    /// Calculates the Levenshtein distance between two strings
    /// - Parameters:
    ///   - s1: First string
    ///   - s2: Second string
    /// - Returns: The edit distance between the strings
    static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        var distances = Array(repeating: Array(repeating: 0, count: s2.count + 1), count: s1.count + 1)
        
        // Initialize the first row and column
        for i in 0...s1.count {
            distances[i][0] = i
        }
        
        for j in 0...s2.count {
            distances[0][j] = j
        }
        
        // Fill the distance matrix
        for i in 1...s1.count {
            for j in 1...s2.count {
                distances[i][j] = s1[i-1] == s2[j-1] ?
                    distances[i-1][j-1] :
                    min(distances[i-1][j], distances[i][j-1], distances[i-1][j-1]) + 1
            }
        }
        
        return distances[s1.count][s2.count]
    }
}
