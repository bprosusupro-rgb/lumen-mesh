# Lumen Mesh — Quest prototype

This prototype uses the Godot OpenXR Vendors Meta Scene Sample and its Meta scene-manager integration. It asks the Quest system for saved room data and displays the global room mesh when provided, alongside passthrough. It is not a continuous scanner, and small, moving, or unrecognized objects may be missing. Mesh export is not implemented.

## Use

Enable developer mode and sideload the debug APK onto a Quest 3S with SideQuest or `adb install -r LumenMesh.apk`. Launch it from the headset's unknown sources/developer apps and grant scene access when prompted. Follow the room setup in a well-lit space.

Open the settings panel with right **B**, aim the right controller at a row and press the right trigger to select it. The menu controls light mode, mesh visibility, mesh style and color, a combined **Low Light + Mesh** preset, and room capture. Right **A** also cycles light modes; left **X** toggles the mesh; left **Y** toggles passthrough; left **Trigger** cycles mesh styles; left **Grip** changes color; and left **Menu** requests a room scan. Light mode, mesh style and color are saved locally.

The combined preset turns on passthrough, Soft Lift and the room mesh at the same time. The mesh comes from Meta's saved room scan; it is not a live scan and may be incomplete or out of alignment. Capture the room in good light. The headset may lose tracking in dim light, and neither this preset nor the brightness adjustment can restore tracking or show unseen objects. Markers have been removed from the controls.

Low-light filters need visible light and do not provide infrared or night vision. Do not rely on this app for navigation or hazard detection.

## Status and build

A headset was not available for testing. Open the project in Godot 4.6.3 with Android export templates and a supported Android SDK/JDK installed. Install the Android build template from Project > Install Android Build Template and use the Meta Quest Android export preset. The source includes Godot OpenXR Vendors 5.2.0 and retains its license files. Derived from https://github.com/GodotVR/godot_openxr_vendors (Meta Scene Sample).
