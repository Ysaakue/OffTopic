import 'dart:ffi';
import 'dart:io';

/// Opens a dynamic library by file name.
typedef LibraryOpener = DynamicLibrary Function(String fileName);

/// Returns the library of the running process.
typedef ProcessLibraryProvider = DynamicLibrary Function();

/// Loads the native voice core for the current platform.
///
/// - Android: `libvoice_core.so`, packaged by the Gradle CMake build.
/// - iOS: linked statically into the app, so the process library.
final class VoiceCoreLibraryLoader {
  /// Creates a loader. The parameters exist for tests; production code uses
  /// the defaults.
  const new({this._operatingSystem, this._openLibrary, this._processLibrary});

  /// File name of the core on Android.
  static const androidLibraryName = 'libvoice_core.so';

  final String? _operatingSystem;
  final LibraryOpener? _openLibrary;
  final ProcessLibraryProvider? _processLibrary;

  /// Loads the library, or throws an [UnsupportedError] on other platforms.
  DynamicLibrary load() {
    final operatingSystem = _operatingSystem ?? Platform.operatingSystem;
    return switch (operatingSystem) {
      'android' => (_openLibrary ?? DynamicLibrary.open)(androidLibraryName),
      'ios' => (_processLibrary ?? DynamicLibrary.process)(),
      _ => throw UnsupportedError(
        'The voice core is not available on $operatingSystem.',
      ),
    };
  }
}
