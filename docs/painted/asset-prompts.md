# 当前整景素材记录

内置 image_gen 生成，非 CLI。参考：`assets/art/classroom_panorama.png`（布局）与 `references/concepts/nostalgia-b2-late-sunset.png`（用户确认的美术与光感）。

输出：`assets/painted/classroom_composite.png`，2172 × 724。

完整提示词：

Use case: compositing / historical-scene. Image 1 is the exact EMPTY classroom panorama layout to preserve. Image 2 is the approved nostalgic painting STYLE and LIGHTING reference. Produce a finished continuous 3:1 ultra-wide hand-painted 1972 Chinese classroom GAME BACKGROUND, with the wooden school desks and chairs painted INTO this same scene, no people anywhere. Keep image 1's six window positions, door, left blackboard, portrait and wall posters. Preserve strong low golden SUNLIGHT FROM OUTSIDE ONLY: golden window edges and tabletop highlights, soft dusty light, deep subdued blue-grey/brown shadows under desks, painterly reflected light on worn surfaces, nostalgic sorrowful sunset mood matching image 2. Do NOT flatten or remove painted lighting. All electric lamps OFF. Furniture: two parallel horizontal rows of 7 old wooden pupil desks with matching old wooden chairs, all seen near-frontally, subtle perspective with very little convergence. Desks should have charming asymmetry and worn rounded edges as in image 2, varied books and one or two school satchels, hand-painted broad strokes rather than crisp woodgrain. Back row occupies y=60% to 85% of the image, with tabletops near y=64%, centers x=19%,30%,41%,52%,63%,74%,85%. Foreground row tabletops near y=83%, feet continuing beyond the bottom edge, centers x=18%,29%,40%,51%,62%,73%,84%. Leave clear horizontal walking aisles behind the back desks and between the two rows; leave open connecting spaces at both far ends. Tabletop highlights must correspond to the adjacent windows and vary: desks near wall piers are more shaded, desks under windows have warm partial light. This is ONE coherent painting, not a sprite sheet, not a collage. No additional people, no UI, no artificial interior fill light, no 3D render style, no duplicated disconnected furniture. Retain all painted shadows, sun patches and local material color. Same 3:1 panorama framing.

`tools/extract_painted_layers.py` 按人工轮廓从这张画复制 14 组桌椅遮挡层，保留源图 RGB 和原位置。桌面部分由同一纹理覆盖的接影面片补回；无需重新生成桌椅或给桌椅换色。轮廓和桌面坐标存放在 `assets/painted/layers.json`。

人物继续使用 H3 视频派生的 29 帧循环。人物/视频生成提示词和原始服务任务在 `docs/relighting/asset-prompts.md` 及 `assets/animation/h3-walk-v1/request.json`。新增受光响应图和柔化轮廓用于局部增亮与桌面投影，不修改这张整景的光。
