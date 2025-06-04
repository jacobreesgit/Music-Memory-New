import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var tracker: NowPlayingTracker
    @State private var isPerformingMaintenance = false
    @State private var isDeletingAllData = false
    @State private var showDeleteConfirmation = false
    @State private var showMaintenanceConfirmation = false
    
    var body: some View {
        List {
            appInfoSection
            databaseManagementSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Database Maintenance", isPresented: $showMaintenanceConfirmation) {
            Button("Run Maintenance") {
                performMaintenance()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to run database maintenance?")
        }
        .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
            Button("Delete Everything", role: .destructive) {
                deleteAllData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you absolutely sure you want to delete all data?")
        }
    }
    
    private var appInfoSection: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "music.note.house")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 32))
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Music Memory")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Personal Music Charts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Version 1.0")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    private var databaseManagementSection: some View {
        Section("Database Management") {
            Button(action: {
                showMaintenanceConfirmation = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                        .frame(width: 28, height: 28)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Database Maintenance")
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                        Text("Clean up play events over a year, remove unused album artwork, and delete songs with no plays")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isPerformingMaintenance {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isPerformingMaintenance)
            
            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 20))
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete All Data")
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                        Text("Permanently erase all Music Memory data and return to setup screen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isDeletingAllData {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isDeletingAllData)
        }
    }
    
    private func performMaintenance() {
        Task {
            isPerformingMaintenance = true
            await tracker.performMaintenance()
            isPerformingMaintenance = false
        }
    }
    
    private func deleteAllData() {
        Task {
            isDeletingAllData = true
            
            do {
                // Delete all tracked songs (cascade will delete play events)
                let songs = try modelContext.fetch(FetchDescriptor<TrackedSong>())
                for song in songs {
                    // Clean up artwork file
                    if let fileName = song.artworkFileName {
                        ArtworkManager.shared.deleteArtwork(for: fileName)
                    }
                    modelContext.delete(song)
                }
                
                // Save changes
                try modelContext.save()
                
                // Clear UserDefaults
                UserDefaults.standard.removeObject(forKey: "hasSeededLibrary")
                UserDefaults.standard.removeObject(forKey: "lastFullSyncDate")
                
                print("✅ All data deleted successfully")
                
                // Reset to setup mode
                NotificationCenter.default.post(name: .resetToSetup, object: nil)
                
            } catch {
                print("❌ Error deleting all data: \(error)")
            }
            
            isDeletingAllData = false
        }
    }
}
