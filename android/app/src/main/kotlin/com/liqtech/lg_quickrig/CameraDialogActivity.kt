package com.liqtech.lg_quickrig

/**
 * Dialog-only entry point for widget buttons (Fly To / Orbit / Overlay / Pin).
 *
 * Runs in its own task with a translucent window, so the dialog floats over
 * the launcher without bringing the full app forward. All behaviour
 * (pending-action handoff, transparency) is inherited from MainActivity;
 * the manifest adds noHistory + excludeFromRecents so closing the dialog
 * leaves no trace.
 */
class CameraDialogActivity : MainActivity()
