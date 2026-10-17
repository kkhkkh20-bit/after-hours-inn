# Project work rules

## Mobile first
- Every gameplay action must work with touch alone. Right click and keyboard may only be supplementary.
- Preserve a simple service loop: tap a guest or reception, read the request, tap the recommended action.
- Inn management uses the stable portrait overview; owner follow is an explicit camera choice or used for other floors.

## Required screenshot comparison
Before changing UI, camera, map layout, or visible interactions:
1. Capture the actual running game before editing. Keep the baseline intact.
2. Capture the result with the same viewport, game age, and scenario.
3. Open and inspect both images. Correct overlaps, clipping, hidden entrances, and unusable touch targets before delivery.
4. Commit the before/after images and a short comparison document; show or link the images in the completion message.
5. Use real renderer screenshots. Generated mockups are not evidence of implementation. If rendering is unavailable, state that limitation and do not claim visual verification.

Use tools/capture_mobile.gd for the 720 x 1360 portrait scenario and tools/run_mobile_capture.py in a Linux capture environment. The capture scenario should run separately from user save files and must not overwrite the user's active saves.
