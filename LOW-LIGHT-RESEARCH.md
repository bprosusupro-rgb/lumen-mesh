# Low-light research

Reviewed 15 November 2026. No AI enhancement or object detection is implemented in this release.

Meta's [Passthrough Camera API](https://developers.meta.com/vr/documentation/unity/unity-pca-overview/) exposes forward-facing RGB frames to apps with appropriate permission. The existing Godot app uses the composited passthrough layer and does not receive those image frames. A separate Android Camera2 bridge, explicit permission flow, appropriate image format conversion, synchronization, and an on-device inference pipeline would be needed.

[Zero-DCE++](https://arxiv.org/abs/2103.00860) is a candidate for low-light enhancement: the authors describe a roughly 10,000-parameter curve-estimation network. Their reported benchmarks are not Quest 3S measurements and do not prove it can run with acceptable headset latency. Evaluate model licensing, conversion, image-processing cost, per-eye alignment and timing, color distortion, noise amplification, flicker and dropped frames before offering it. It is enhancement, not reliable object detection, and cannot recover details missing from a dark sensor image.

[Meta's brightness estimation example](https://developers.meta.com/vr/documentation/unity/unity-sample-camera-brightness/) illustrates frame-based brightness assessment and smoothing. A first experiment could estimate brightness on-device and show a cautious informational indicator, keeping capture local and allowing explicit opt-in; it requires a new camera-permission flow and device validation. No camera analysis is currently included.

A second experiment could compare a lightweight detector on raw and enhanced low-light images with real Quest data. Detection can miss objects or invent unreliable details, so never imply obstacle detection or safe navigation. Neither AI nor brightness changes repair headset tracking in darkness.

The HUD remains attached to the view as requested and displays manually calibrated heading, app FPS, passthrough mode and mesh state. It can be hidden in Settings. Meta's [MR design guidance](https://developers.meta.com/vr/design/mr-design-guideline/) recommends minimizing head-locked content for comfort. Heading is relative to a direction set by the user and is not an automatic compass. HUD elements do not establish real-world safety.
