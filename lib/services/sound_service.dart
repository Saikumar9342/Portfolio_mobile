import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  // Basic Click Sound (System)
  static Future<void> playClick() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.selectionClick();
  }

  // Success Sound
  static Future<void> playSuccess() async {
    try {
      await HapticFeedback.mediumImpact();
      // Placeholder for actual sound file - can be added to assets later
      // await _player.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      debugPrint("Error playing success sound: $e");
    }
  }

  // Error Sound
  static Future<void> playError() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint("Error playing error haptic: $e");
    }
  }
}
