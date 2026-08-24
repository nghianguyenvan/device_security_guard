import 'models.dart';

/// Các tín hiệu bắt buộc trong assessment Android.
const androidRequiredSignals = {
  SecuritySignal.debugger,
  SecuritySignal.emulator,
  SecuritySignal.adbEnabled,
  SecuritySignal.hooking,
  SecuritySignal.repackaging,
  SecuritySignal.root,
  SecuritySignal.bootloaderUnlocked,
};

/// Các tín hiệu bắt buộc trong assessment iOS.
const iosRequiredSignals = {
  SecuritySignal.debugger,
  SecuritySignal.emulator,
  SecuritySignal.hooking,
  SecuritySignal.repackaging,
  SecuritySignal.jailbreak,
};

/// Trả về tập tín hiệu bắt buộc của [platform].
Set<SecuritySignal> requiredSignalsFor(SecurityPlatform platform) =>
    switch (platform) {
      SecurityPlatform.android => androidRequiredSignals,
      SecurityPlatform.iOS => iosRequiredSignals,
    };
