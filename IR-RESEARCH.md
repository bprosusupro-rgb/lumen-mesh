# Infrared and low-light investigation

## Supported interfaces

Meta's Passthrough Camera API exposes Quest 3 and 3S forward-facing RGB cameras through Android Camera2. It does not document access to the headset's IR tracking-camera images. RGB camera access requires the appropriate camera permission and is not implemented in this prototype. RGB enhancement requires captured visible light and cannot reliably recover a scene in complete darkness.

- Meta Camera2 documentation: https://developers.meta.com/vr/documentation/native/android/pca-native-documentation/
- Meta RGB camera announcement: https://developers.meta.com/vr/blog/new-era-mixed-reality-passthrough-camera-api-machine-learning-computer-vision/
- Quest 3S low-light tracking and illuminators: https://www.uploadvr.com/quest3s-hand-tracking-better-than-quest-3/

The Quest 3S uses IR illuminators for tracking. Tracking may work in low light, depending on conditions and software version, but that does not mean the app can display the tracking-camera images. Scene capture and passthrough should be used in adequate lighting. Do not use the displayed reconstruction as a navigation or obstacle-detection system.

## Experimental alternatives

- An external IR-sensitive or thermal camera could supply image data independently of the Quest's built-in tracking cameras. https://github.com/A31A18B25C9D012/Quest3-IRFusion describes a proposed external-camera approach using a privileged service and custom Android build, not a ready-to-use ordinary Quest app. Hardware compatibility, latency, alignment, and software availability require independent verification; this project does not implement it.
- Rooted-headset research such as https://github.com/CreoleVR/QuestLHSync reports accessing tracking-camera buffers on rooted hardware to extract bright spots; it sends spot positions rather than images. This is evidence of a research route, not a supported, portable raw IR video API for this app. Root access is version-dependent and may impair device security, updates, or usability. No rooting or private API code is included.

No built-in IR feed or night-vision mode is implemented or verified in Lumen Mesh. Research recorded November 2026.
