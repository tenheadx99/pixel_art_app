/// Compares dotted version strings ("1.0.11", build suffixes after '+'
/// ignored): true when [current] is strictly older than [required].
bool isVersionOlder(String current, String required) {
  final currentClean = current.split('+')[0];
  final requiredClean = required.split('+')[0];

  final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final requiredParts = requiredClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  while (currentParts.length < 3) {
    currentParts.add(0);
  }
  while (requiredParts.length < 3) {
    requiredParts.add(0);
  }

  for (int i = 0; i < 3; i++) {
    if (currentParts[i] < requiredParts[i]) {
      return true;
    } else if (currentParts[i] > requiredParts[i]) {
      return false;
    }
  }
  return false;
}
