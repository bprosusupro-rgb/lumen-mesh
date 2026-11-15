# Lumen Mesh — Quest prototype

This prototype uses the Godot OpenXR Vendors Meta Scene Sample and its Meta scene-manager integration. It asks the Quest system for saved room data and displays supported scene anchors and the global room mesh when provided. It also offers passthrough and spatial markers. It is not a continuous scanner, and small, moving, or unrecognized objects may be missing. Mesh export is not implemented.

## Use

Enable developer mode and sideload the debug APK onto a Quest 3S with SideQuest or `adb install -r LumenMesh.apk`. Launch it from the headset's unknown sources/developer apps and grant scene access when prompted. Follow the room setup in a well-lit space.

The in-headset panel shows the current view, mesh style, color, and light mode. Right **A** cycles Natural, Soft Lift, Bright, and Mono passthrough modes; right **B** hides or shows the panel. Left **X** toggles the room mesh; left **Y** toggles passthrough. Left **Trigger** cycles Fine, Bold, and Surface mesh styles, and left **Grip** cycles mesh colors. Left **Menu** requests a room scan/update. Right **Trigger** adds or removes markers. The app remembers the light mode, mesh style and color on the device.

The mesh defaults to a subtler thin wireframe, and overlapping room-object labels and colored shapes are hidden. Your device's available room mesh may still be dense or incomplete.

The app requests a 72 Hz display rate when available, disables unused environment depth, and uses a stable anti-aliased mesh edge calculation. The low-light modes adjust passthrough brightness and contrast. They need visible light and may amplify noise, flatten detail, or fail on unsupported runtimes. They are not infrared or night vision and cannot reveal objects in total darkness. Do not rely on the app for navigation or hazard detection. The Quest 3S's infrared tracking images are not available to this ordinary app.

## Status and build

A headset was not available for testing. Open the project in Godot 4.6.3 with Android export templates and a supported Android SDK/JDK installed. Install the Android build template from Project > Install Android Build Template and use the Meta Quest Android export preset. The source includes Godot OpenXR Vendors 5.2.0 and retains its license files. Derived from https://github.com/GodotVR/godot_openxr_vendors (Meta Scene Sample).
