# Lumen Mesh — Quest prototype

This prototype uses the Godot OpenXR Vendors Meta Scene Sample and its Meta scene-manager integration. It asks the Quest system for saved room data and displays supported scene anchors and the global room mesh when provided. It also offers passthrough and spatial markers. It is not a continuous scanner, and small, moving, or unrecognized objects may be missing. Mesh export is not implemented.

## Use

Enable developer mode and sideload the debug APK onto a Quest 3S with SideQuest or `adb install -r LumenMesh.apk`. Launch it from the headset's unknown sources/developer apps. Grant scene access if prompted. Use in a well-lit room and follow the headset's room setup. On the left controller, Menu requests a room capture/update, X toggles the mesh and markers, and Y toggles passthrough. On the right controller, trigger adds/removes markers, A adds a floating marker, and B toggles depth occlusion.

IR tracking cameras are not available to this ordinary app as a night-vision video feed. Passthrough and tracking require adequate light; do not rely on this app to navigate in darkness or detect hazards.

## Status and build

A headset was not available for testing. Open the project in Godot 4.6.3 with Android export templates and a supported Android SDK/JDK installed. Install the Android build template from Project > Install Android Build Template and use the Meta Quest Android export preset. The source includes Godot OpenXR Vendors 5.2.0 and retains its license files. Derived from https://github.com/GodotVR/godot_openxr_vendors (Meta Scene Sample).
