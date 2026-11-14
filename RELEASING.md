# Releasing

Use a unique version tag for each release. Export and sign an APK, test it on a Quest 3S, then create a GitHub release for the matching tag and attach the APK. Mark builds without headset validation as prereleases and explain the limitations. Keep the signing key secure and use a consistent key for upgrades.

For the initial debug prototype, the prepared tag is `v0.1.0`; it was not tested on a headset. GitHub will not automatically create future releases: each version needs a tag, release notes, and an APK.
