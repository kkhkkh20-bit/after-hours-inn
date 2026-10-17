# Kenney Starter Kit City Builder

Source: https://github.com/KenneyNL/Starter-Kit-City-Builder
Commit: 4535092b740b378b700efd9df9e27a631815b84a
License: MIT, see LICENSE.md (preserved copyright 2025 from source).

Copied builder.gd, view.gd and the three resource classes. The only edit to builder.gd is an injected Audio member in place of its project-global autoload. All other behavior is inherited by scripts/inn_kenney_backend.gd. The view script is unchanged and inherited by scripts/inn_kenney_camera.gd.

Our adapters provide touch input, existing facility models, validation, inn economy/save integration, orientation and occupied-prison restrictions. No claim of importing the complete upstream city simulation: upstream is a construction starter kit.
