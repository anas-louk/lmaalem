# Background Notifications Fix

## Problem
Background notifications weren't working - notifications only appeared when the app was opened again.

## Root Cause
Android suspends Timer-based execution when the app is backgrounded. The Timer stops running after Android kills the app process.

## Solution Implemented

### 1. **WorkManager Integration** ✅
- Added `workmanager: ^0.5.2` package
- WorkManager runs background tasks even when app is killed
- Minimum interval: 15 minutes (Android limitation)
- Runs in separate isolate, so we use SharedPreferences for user data

### 2. **SharedPreferences Storage** ✅
- User ID and type saved to SharedPreferences on login
- Cleared on logout
- WorkManager callback reads from SharedPreferences (can't use GetX in isolate)

### 3. **Dual Polling Strategy** ✅
- **Timer-based polling**: Every 30 seconds when app is backgrounded (works until Android kills process)
- **WorkManager polling**: Every 15 minutes (works even after app is killed)

### 4. **Firebase Initialization in Isolate** ✅
- WorkManager callback initializes Firebase in its isolate
- Uses `firebase_options.dart` for proper initialization

## How It Works Now

### Foreground:
- Firestore streams detect changes instantly
- Real-time notifications

### Background (App Minimized):
1. **Immediate (0-5 minutes)**: Timer polls every 30 seconds
2. **After Android kills process**: WorkManager polls every 15 minutes

### Key Files:
- `lib/core/services/background_notification_service.dart` - Main service
- `lib/main.dart` - App lifecycle monitoring
- `lib/controllers/auth_controller.dart` - Saves user info to SharedPreferences

## Testing

1. **Login** as employee or client
2. **Minimize the app** (don't close it)
3. **Create a request** (as client) or **Have employee accept** (as client)
4. **Wait up to 30 seconds** - Should receive notification via Timer
5. **Kill the app** (swipe away from recent apps)
6. **Wait 15 minutes** - WorkManager should trigger and check for notifications

## Important Notes

- **WorkManager minimum interval**: 15 minutes (Android limitation)
- **Timer polling**: 30 seconds (only works while app process is alive)
- **Battery optimization**: Users may need to disable battery optimization for the app
- **Testing**: Use `adb logcat` to see WorkManager execution logs

## Debugging

Check logs for:
- `[BackgroundNotification]` - Timer-based polling
- `[WorkManager]` - WorkManager callback execution
- `[MyApp]` - App lifecycle changes

## Next Steps if Still Not Working

1. Check if WorkManager is actually running:
   ```bash
   adb logcat | grep WorkManager
   ```

2. Disable battery optimization for the app:
   - Settings → Apps → lmaalem → Battery → Unrestricted

3. Check if SharedPreferences is saving user data:
   - Look for `[AuthController] Saved user info to SharedPreferences` in logs

4. Verify WorkManager task is registered:
   - Look for `[BackgroundNotification] WorkManager periodic task registered` in logs

