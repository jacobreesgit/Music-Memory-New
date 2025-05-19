# Music Memory App Documentation

## Overview

Music Memory is an iOS application that helps users explore their music listening habits by analyzing music libraries and providing insights on most played songs. The app integrates with both the local music library and Apple Music to provide a comprehensive view of the user's music consumption.

## Project Structure

```
Music Memory/
├── App/                     # App-level components
│   ├── ContentView.swift    # Main entry point view
│   ├── Music_Memory_NewApp.swift # App lifecycle and configuration
│   ├── Info.plist           # App configuration
│   └── MusicMemory.entitlements # App capabilities
├── Models/                  # Core data models and services
│   ├── MusicLibraryModel.swift  # Core facade coordinating music services
│   ├── LocalMusicLibrary.swift  # Local device music access
│   └── AppleMusicService.swift  # Apple Music API integration
├── Views/                   # UI components
│   ├── Components/          # Reusable view components
│   │   ├── ImageCache.swift     # Image loading and caching
│   │   ├── SongArtworkView.swift # Artwork display components
│   │   └── SongInfoHeader.swift  # Song information header
│   ├── Songs/               # Song list views
│   │   ├── SongsView.swift      # Main song list view
│   │   └── SongRowView.swift    # Individual song row
│   └── SongDetail/          # Song detail views
│       ├── SongDetailBase.swift  # Base detail view structure
│       ├── SongDetailView.swift  # Local song details
│       ├── AppleMusicSongDetailView.swift # Apple Music song details
│       └── DetailRow.swift       # Detail information row
└── Utilities/               # Helper utilities
    ├── Extensions/
    │   └── AppHelpers.swift     # Common helper functions
    └── Theme/
        └── Theme.swift          # Design system definitions
```

## Core Components

### App Layer

#### `ContentView`
- Entry point view for the application
- Manages permission states and navigation flow
- Shows different views based on library access status

#### `MusicMemoryApp`
- Application lifecycle management
- Environment setup and configuration
- Global UI appearance configuration

### Models Layer

#### `MusicLibraryModel`
- Core facade coordinating multiple music services
- Manages state for both local and Apple Music content
- Handles permissions, search, and caching
- Provides Observable properties for UI binding

#### `LocalMusicLibrary`
- Handles access to the device's local music library
- Manages permissions for MPMediaLibrary
- Loads and sorts songs from the device
- Provides song lookup and filtering capabilities

#### `AppleMusicService`
- Handles Apple Music API integration
- Manages Apple Music permissions
- Performs catalog searches
- Processes search results

### Views Layer

#### Songs Views

##### `SongsView`
- Main view for displaying songs
- Implements search functionality
- Handles tab switching between local library and Apple Music
- Manages search debouncing and result display

##### `SongRowView`
- Displays individual song information in lists
- Supports both local and Apple Music songs
- Shows song details, play count, and library status
- Generic implementation supporting different data sources

#### Song Detail Views

##### `SongDetailBase`
- Base template for song detail views
- Provides consistent layout and navigation
- Supports both local and Apple Music songs

##### `SongDetailView`
- Detailed view for local library songs
- Shows comprehensive song metadata
- Displays playback statistics and library info

##### `AppleMusicSongDetailView`
- Detailed view for Apple Music catalog songs
- Shows catalog metadata and availability
- Displays library status if song is in local library

#### Component Views

##### `SongArtworkView`
- Displays song artwork with fallback handling
- Supports both local media items and remote URLs
- Provides different size options

##### `SongInfoHeader`
- Displays song title, artist, and additional info
- Consistent header for song detail views
- Shows rank and play count information

##### `ImageCache`
- Handles asynchronous image loading
- Caches images for faster display
- Provides fallback for missing artwork

### Utilities

#### `Theme`
- Central design system for the application
- Defines colors, typography, metrics, and shadows
- Provides view modifiers for consistent styling

#### `AppHelpers`
- Common utility functions for formatting
- Date and time formatting
- Duration formatting

## Data Flow

1. App starts and requests music library permissions
2. `MusicLibraryModel` coordinates permission requests through respective services
3. Once permissions are granted, local library songs are loaded
4. User can browse local songs or search Apple Music catalog
5. Selecting a song navigates to the appropriate detail view
6. Search queries are debounced and sent to Apple Music API
7. Results are processed, deduplicated, and displayed

## Key Design Patterns

### MVVM (In Progress)
- Models: Core data structures and entities
- Views: UI components and layouts
- ViewModels: Business logic and data transformation
  
### Dependency Injection (In Progress)
- Service protocols for testability
- Centralized dependency container
- Dependency injected through constructors

### Repository Pattern (In Progress)
- Data access abstracted behind repository interfaces
- Centralized data access logic
- Caching implemented at repository level

## Coding Standards

### Swift and SwiftUI

1. **Modern Swift Features**
   - Use async/await for asynchronous operations
   - Implement actors for thread-safe components
   - Use structured concurrency for task management
   - Leverage Swift's latest property wrappers

2. **SwiftUI Best Practices**
   - Use NavigationStack instead of NavigationView
   - Implement proper data flow with @State, @Binding, @EnvironmentObject
   - Extract reusable components into separate views
   - Use ViewBuilder for dynamic content

3. **Error Handling**
   - Create domain-specific error types
   - Use `Result` type and `try`/`catch` appropriately
   - Propagate errors up the call stack
   - Provide user-friendly error messages

4. **Testing**
   - Write unit tests for all business logic
   - Mock dependencies for isolated testing
   - Implement UI tests for critical user flows
   - Aim for high test coverage

### Code Organization

1. **File Structure**
   - Organize by feature first, then by layer
   - Group related components together
   - Use consistent naming conventions
   - Separate interfaces from implementations

2. **Naming Conventions**
   - Types: UpperCamelCase (e.g., `SongDetailView`)
   - Functions, properties: lowerCamelCase (e.g., `loadLibrary()`)
   - Protocols: UpperCamelCase with clear purpose (e.g., `MusicServiceProtocol`)
   - Extensions: Clear purpose prefix (e.g., `View+Theme.swift`)

3. **Access Control**
   - Use most restrictive access control possible
   - Make helper functions private when possible
   - Use internal for components used within the module
   - Make APIs public only when necessary

4. **Documentation**
   - Use DocC comments for all public APIs
   - Document parameters, return values, and throws clauses
   - Add usage examples for complex components
   - Document architectural decisions

## UI/UX Guidelines

1. **Design System**
   - Follow the `Theme` definitions for consistent styling
   - Use predefined colors, typography, and spacing
   - Apply consistent corner radii and shadows
   - Use standard iOS patterns where appropriate

2. **Navigation**
   - Use type-safe navigation with NavigationStack
   - Implement consistent navigation patterns
   - Provide clear back navigation
   - Support deep linking where appropriate

3. **Accessibility**
   - Add proper accessibility labels and hints
   - Support dynamic type sizing
   - Ensure proper contrast ratios
   - Test with VoiceOver

4. **Error Presentation**
   - Show user-friendly error messages
   - Provide recovery actions where possible
   - Use appropriate UI for different error types
   - Implement graceful degradation

## Permissions and Privacy

The app requires the following permissions:
- `MPMediaLibrary` access for local music library
- `MusicKit` access for Apple Music integration

Proper permission requests with clear explanations are implemented in the `Info.plist` file and through respective permission request flows.

## Dependencies

The application uses the following Apple frameworks:
- SwiftUI for UI
- MediaPlayer for local music access
- MusicKit for Apple Music integration

No third-party dependencies are currently used.

## Future Enhancements

The following enhancements are planned:
- Full MVVM architecture implementation
- Comprehensive testing suite
- SwiftUI previews for all components
- Enhanced error handling and recovery
- Improved navigation with NavigationStack
- Modern concurrency with actors and async/await

---

This README provides a comprehensive overview of the Music Memory app's architecture, components, and coding standards. It serves as a reference for understanding the codebase and guiding future development according to the established patterns and practices.
