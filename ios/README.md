# ReelVault iOS Application & Share Extension

## Prerequisites
- macOS Sonoma (14.0+) or macOS Sequoia (15.0+)
- Xcode 16.0+ (iOS 17.0+ SDK)
- Apple Developer Account (free or paid)

## Architecture Overview
The iOS suite consists of:
1. **`ReelVault` (Main Application)**:
   - **Views**: SwiftUI navigation with `LibraryView`, `ReelDetailView`, `SearchView`, `SettingsView`.
   - **ViewModels**: Modern `@Observable` view models using Swift 6 observation.
   - **Local Storage**: SwiftData (`ReelItem`) offline-first cache with automatic DTO syncing.
   - **Realtime**: Listens to Supabase Postgres replication updates on `public.reels` for live status transitions.
2. **`ReelVaultShareExtension` (iOS Share Sheet Extension)**:
   - **ShareExtractor**: Asynchronous multi-stage URL extraction handling raw `URL` and `plain-text` containing Instagram Reel URLs.
   - **BackendClient**: High-speed, non-blocking URL submission to `/api/v1/reels` with offline fallback queue.
   - **ShareExtensionView**: Compact modal card with auto-dismiss (< 1s interaction time).
3. **`Shared/`**:
   - `SharedStorage.swift`: App Group `group.com.reelvault.app` synchronization.
   - `URLValidator.swift`: Instagram URL regex extraction and tracking parameter sanitizer.

## Xcode Setup Instructions

### 1. Create or Open the Xcode Project
1. Open Xcode -> **File > New > Project...** -> **iOS > App**.
2. **Product Name**: `ReelVault`
3. **Organization Identifier**: `com.yourcompany` (e.g. `com.reelvault`)
4. **Interface**: SwiftUI
5. **Storage**: SwiftData
6. **Include Tests**: Yes
7. Set project directory to the `ios/` folder in this repository.

### 2. Add Dependencies via Swift Package Manager (SPM)
1. In Xcode: **File > Add Package Dependencies...**
2. Enter repository URL: `https://github.com/supabase/supabase-swift.git`
3. Dependency Rule: **Up to Next Major Version** from `2.50.0`
4. Add to Target: `ReelVault`

### 3. Add the Share Extension Target
1. **File > New > Target...** -> **iOS > Share Extension**.
2. **Product Name**: `ReelVaultShareExtension`
3. Delete the automatically created `MainInterface.storyboard`.
4. In `ReelVaultShareExtension/Info.plist`, replace with the provided `ios/ReelVaultShareExtension/Info.plist` (which sets `NSExtensionPrincipalClass` to `$(PRODUCT_MODULE_NAME).ShareViewController` and enables Instagram plain-text matching).

### 4. Configure App Groups (Required for shared settings & offline queue)
1. Select Target **ReelVault** -> **Signing & Capabilities** -> **+ Capability** -> **App Groups**.
2. Add `group.com.reelvault.app`.
3. Select Target **ReelVaultShareExtension** -> **Signing & Capabilities** -> **+ Capability** -> **App Groups**.
4. Check the identical `group.com.reelvault.app`.

### 5. Add Source Files
Drag the folders into Xcode:
- `ReelVault/` -> Target `ReelVault`
- `ReelVaultShareExtension/` -> Target `ReelVaultShareExtension`
- `Shared/` -> Targets **both** `ReelVault` AND `ReelVaultShareExtension`

## Testing the Share Extension
1. Select the `ReelVaultShareExtension` scheme in Xcode and press Run (`⌘R`).
2. Choose **Instagram** or **Safari** as the host application.
3. In Safari or Instagram, navigate to any Reel, tap **Share**, and tap **ReelVault**.
4. Verify the checkmark confirms in under 1 second.
5. Open the `ReelVault` main app and watch the Reel progress from *Queued* to *Ready*!
