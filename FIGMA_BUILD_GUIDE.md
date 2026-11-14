# BenchSpot first Figma screen (free plan)

## Frame and tokens
- Create a new Design file, press F, choose iPhone 14/15 (390 x 844).
- Frame name: Map / Default.
- Colors: Cocoa #4B3832; Berry #854442; Cream #FFF4E6; Charcoal #3C2F2F; Latte #BE9B7B.
- Use Inter. Heading 20/28 Bold, body 14/20 Regular, label 12/16 Medium.
- Use an 8 px spacing system and 16 px page margins.

## Layers, top to bottom
1. Welcome background: use `assets/autumn-bench.png`, cover the full frame, and add the subtle dark cocoa overlay.
2. Header: show the bench-chair app mark on a cocoa #4B3832 background and the cream “bench spot” wordmark.
3. Intro: center the cream heading and subtitle over the photo with a soft dark text shadow.
4. City card: centered cream panel with a 1 px cream outline, 20 px radius, and subtle shadow. Include the city picker and the berry location button.
5. Map pins: use a 48 x 48 berry circle, 3 px cream border, and the cream chair icon.
6. Bench popup: show only the bench name and rating, followed by Reviews, Photos, Directions, and Write a review buttons.

## Prototype connections
- Duplicate the frame three times: Map / Lake, Map / Grand-Place, Map / Woods.
- Change the selected pin and card copy on each duplicate.
- In Prototype mode connect each pin with On tap → Navigate to its matching frame → Smart animate → 300 ms → Ease out.
- Create a 390 x 420 frame “Bench detail” with the full title, rating, chips, note, and Directions button.
- Connect each card arrow: On tap → Open overlay → Bottom center → Close when clicking outside.
- Connect the overlay close/drag-handle region: On tap → Close overlay.
- Set Map / Lake as the flow starting point and press Present.

## Accessibility checks
- Keep touch targets at least 44 x 44 px.
- Do not rely on pin color alone; use a thicker border/scale for selected state.
- Keep text contrast high and map labels secondary to app controls.
