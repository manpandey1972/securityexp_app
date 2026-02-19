# Xcode Cloud CI/CD Scripts

This directory contains scripts that run during Xcode Cloud builds.

## Files

### `ci_post_clone.sh`
Runs automatically after Xcode Cloud clones the repository. This script:

1. **Installs Flutter** - Downloads Flutter SDK (stable channel)
2. **Configures Flutter** - Disables analytics for CI environment
3. **Gets dependencies** - Runs `flutter pub get` to fetch packages
4. **Installs CocoaPods** - Runs `pod install` to generate iOS dependencies
5. **Generates required files**:
   - `Flutter/Generated.xcconfig` - Flutter build configuration
   - `Pods/Target Support Files/` - CocoaPods build files

## Why This Is Needed

Flutter generates several files during the build process that are not committed to Git:
- `Flutter/Generated.xcconfig` (gitignored)
- CocoaPods generated files (gitignored)

Without this script, Xcode Cloud fails with:
```
could not find included file 'Generated.xcconfig' in search paths
Unable to load contents of file list: 'Pods-Runner-frameworks-Release-output-files.xcfilelist'
```

## Xcode Cloud Configuration

Xcode Cloud automatically detects and runs scripts in the `ios/ci_scripts/` directory:
- `ci_post_clone.sh` - Runs after repository clone
- `ci_pre_xcodebuild.sh` - Runs before Xcode build (optional)
- `ci_post_xcodebuild.sh` - Runs after Xcode build (optional)

See [Flutter's Xcode Cloud documentation](https://docs.flutter.dev/deployment/cd#xcode-cloud) for more details.

## Testing Locally

To test the script locally:
```bash
cd ios/ci_scripts
./ci_post_clone.sh
```

Make sure the script is executable:
```bash
chmod +x ci_post_clone.sh
```
