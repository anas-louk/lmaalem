# Unused Code Report

This document lists unused files and code that can be safely removed from the project.

## Unused Files

### 1. `lib/core/services/firestore_init_example.dart`
- **Status**: Not imported anywhere
- **Purpose**: Example/utility file for initializing Firestore with sample data
- **Recommendation**: Can be removed if not needed for development/testing, or moved to a `examples/` or `docs/` folder

### 2. `lib/controllers/client_controller.dart`
- **Status**: Not imported anywhere
- **Purpose**: Controller for managing clients
- **Note**: The app uses `UserModel` with type 'Client' instead of a separate `ClientModel` controller
- **Recommendation**: Can be removed if client management is handled through `AuthController` and `UserModel`

### 3. `lib/data/repositories/client_repository.dart`
- **Status**: Only used in `client_controller.dart` (which is also unused)
- **Purpose**: Repository for client CRUD operations
- **Note**: Similar to above - clients are managed as users with type 'Client'
- **Recommendation**: Can be removed if not needed

### 4. `lib/core/constants/app_assets.dart`
- **Status**: Not imported anywhere
- **Purpose**: Constants for asset paths (images, icons, animations)
- **Recommendation**: Can be removed if assets are referenced directly, or keep if planning to use these assets

### 5. `lib/utils/extensions/string_extensions.dart`
- **Status**: Not imported anywhere
- **Purpose**: String utility extensions (capitalize, isValidEmail, isValidPhone)
- **Recommendation**: Can be removed if not needed, or keep if planning to use these utilities

### 6. `lib/core/services/storage_service.dart`
- **Status**: Not imported anywhere
- **Purpose**: Firebase Storage service for file uploads/downloads
- **Recommendation**: Keep if planning to add image upload functionality, otherwise remove

### 7. `lib/utils/enums/app_enums.dart`
- **Status**: Not imported anywhere
- **Purpose**: Global enums (LoadingState, NotificationType, ScreenSize)
- **Recommendation**: Can be removed if not used, or keep if planning to use these enums

## Unused Imports

### `lib/controllers/mission_controller.dart`
- Line 2: `import 'package:flutter/scheduler.dart';` - **USED** (SchedulerBinding is used on lines 37, 60, 83)

## Files That Are Used

- `lib/core/services/push_notifications.dart` - Used in `firebase_init.dart`
- `lib/data/models/client_model.dart` - Used in `firestore_init_example.dart` (but that file is unused)

## Recommendations

1. **Safe to Remove**:
   - `firestore_init_example.dart` (unless needed for testing)
   - `client_controller.dart`
   - `client_repository.dart`
   - `app_assets.dart` (if assets aren't being used)
   - `string_extensions.dart` (if not planning to use)
   - `app_enums.dart` (if not planning to use)

2. **Consider Keeping**:
   - `storage_service.dart` - Useful for future image upload features
   - `app_assets.dart` - Useful if you plan to add assets
   - `string_extensions.dart` - Useful utility functions

3. **Note**: `ClientModel` and `ClientRepository` might be needed if you plan to have a separate `clients` collection in Firestore. Currently, the app uses `users` collection with type 'Client'.

## Action Items

- [ ] Review and remove unused files
- [ ] Update documentation if removing files
- [ ] Consider if `ClientModel`/`ClientRepository` are needed for future features
- [ ] Decide whether to keep utility files (`app_assets.dart`, `string_extensions.dart`, `app_enums.dart`) for future use

