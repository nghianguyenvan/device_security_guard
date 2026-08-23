import 'models.dart';

const androidRequiredSignals = {
  SecuritySignal.debugger,
  SecuritySignal.emulator,
  SecuritySignal.adbEnabled,
  SecuritySignal.hooking,
  SecuritySignal.repackaging,
  SecuritySignal.root,
  SecuritySignal.bootloaderUnlocked,
};

const iosRequiredSignals = {
  SecuritySignal.debugger,
  SecuritySignal.emulator,
  SecuritySignal.hooking,
  SecuritySignal.repackaging,
  SecuritySignal.jailbreak,
};

Set<SecuritySignal> requiredSignalsFor(SecurityPlatform platform) =>
    switch (platform) {
      SecurityPlatform.android => androidRequiredSignals,
      SecurityPlatform.iOS => iosRequiredSignals,
    };
