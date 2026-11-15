# Lumen Mesh — Quest prototype

This prototype uses the Godot OpenXR Vendors Meta Scene Sample and its Meta scene-manager integration. It asks the Quest system for saved room data and displays the global room mesh when provided, alongside passthrough. It is not a continuous scanner, and small, moving, or unrecognized objects may be missing. Mesh export is not implemented.

## Use

Enable developer mode and sideload the debug APK onto a Quest 3S with SideQuest or `adb install -r LumenMesh.apk`. Launch it from the headset's unknown sources/developer apps and grant scene access when prompted. Follow the room setup in a well-lit space.

Press right **B** to place the settings panel in front of you; it stays in the room when you move your head. Aim at a button and press the right trigger. Press B again to close; reopening places it in front of you again. The menu controls light mode, mesh visibility, mesh style, ten mesh colors, a combined **Low Light + Mesh** preset, the heads-up display, north calibration, and room capture. Select **Day** for unfiltered daylight passthrough. Right **A** also cycles light modes; left **X** toggles the mesh; left **Y** toggles passthrough; left **Trigger** cycles mesh styles; left **Grip** changes color; and left **Menu** requests a room scan. Light mode, mesh style, color and HUD visibility are saved locally. The HUD shows the engine-reported frames per second and a heading relative to a north direction that you set yourself.

The HUD is on by default and displays FPS and direction; use the HUD button to turn it on if hidden. To calibrate heading, use an independent compass to find north, face north with your headset level, then select **Set North** in the menu. This is a relative heading, not a magnetometer or GPS compass; recalibrate after recentering or if alignment drifts. The app clears calibration on recenter and each session.

Use **Rescan room** to open Quest Space Setup and follow its prompts. To delete a saved room, use the headset's Settings > Environment setup > Space setup (names may vary by OS), then scan again. The app cannot directly delete the system room.

The combined preset turns on passthrough, Soft Lift and the room mesh at the same time. The mesh comes from Meta's saved room scan; it is not a live scan and may be incomplete or out of alignment. Capture the room in good light. The headset may lose tracking in dim light, and neither this preset nor the brightness adjustment can restore tracking or show unseen objects. Markers have been removed from the controls.

Low-light filters need visible light and do not provide infrared or night vision. No AI object detection is included: the current passthrough layer does not supply image frames to the app, and an AI model cannot recover reliably invisible objects or restore headset tracking. Do not rely on this app for navigation or hazard detection.

## Status and build

A headset was not available for testing. Open the project in Godot 4.6.3 with Android export templates and a supported Android SDK/JDK installed. Install the Android build template from Project > Install Android Build Template and use the Meta Quest Android export preset. The source includes Godot OpenXR Vendors 5.2.0 and retains its license files. Derived from https://github.com/GodotVR/godot_openxr_vendors (Meta Scene Sample).
