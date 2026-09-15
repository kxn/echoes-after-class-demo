# 再受光素材生成记录

2026-09-14。内置 image_gen 生成中性底色，H3 生成连续运动。原始确认的 B2 美术方向保持不变。

## assets/relit/students_albedo_key.png

Edit this character atlas into NEUTRAL ALBEDO sprites for physically lit game rendering. Keep EXACT same four Chinese teenage students, their identities, poses, 1972 clothing, spacing, full bodies and flat pure magenta #ff00ff background. REMOVE ALL golden rim lights, sunset highlights, directional cast shadows and amber color cast from the characters. Use flat soft overcast neutral illumination, cloth pigment and hand-painted texture only; muted natural grey-blue jacket, grey beige floral blouse, olive-grey jacket, dusty muted rose blouse. Skin natural warm beige but no bright illuminated edge. No shadows or glow. Preserve painted line work and local fabric folds but not directional dramatic shading. The leftmost boy should remain standing relaxed as in reference. This is an albedo source, the game will supply sunset illumination. Four full figures on one row in same 1536x1024 composition.

## assets/relit/room_albedo.png

Create a neutral-interior ALBEDO version of the attached exact panoramic classroom plate. KEEP exact panorama framing, all six window positions and sizes, wall base position, architecture, Mao portrait, wall writing, floor and door. Remove every patch of golden sunlight, directional light, dark directional cast shadow and glow FROM INTERIOR wall, wood window frames, cupboard, ceiling and brick floor. Interior surfaces are evenly softly lit with neutral overcast light so their material color and painterly texture are visible: grey plaster, faded grey-green lower wall, brown wood, brown-grey brick. HOWEVER keep the warm golden sunset landscape seen THROUGH the six window glass areas unchanged. These outside areas will be emissive inserts. No furniture or people. Do not add items. Preserve painterly soft edges and weathered material details. No interior baked directional shading. Exact 3:1 ultra-wide panorama, geometry unchanged.

## assets/relit/wood_albedo.png

Seamless tileable MATERIAL ALBEDO texture for an old Chinese school wooden desk, hand-painted softly textured brown wood. Straight wood grain runs horizontally across the square. Worn muted medium brown pigment, subtle scratches, small exposed pale worn grain, modest roughness, restrained tiny knots. Uniform neutral diffuse illumination with NO directional light, NO shadows, NO baked highlights, NO golden glow, no vignette, no perspective. A flat close-up material scan painted in nostalgic illustrative style, not photorealistic. Entire square filled edge to edge with continuous wood texture. No table silhouette, no seams dividing planks, no text, no objects.

## 视频与后处理

H3 job `job_6aa80bc2_00000000`。模型 fl2va，384×640，56 帧，24 fps，28 steps，seed 19720916，耗时约 271 秒。请求原文在 `assets/animation/h3-walk-v1/request.json`，源视频在同目录 `video.webm`。

`tools/build_sprite_frames.py --video --start 21 --end 50`：ffmpeg 截帧 → 品红键色/去溢色 → 主体连通域 → 躯干中心与脚底对齐 → 整段恒定缩放 → 21–49 共 29 帧正向循环 → RGBA 图集与辅助法线。站立使用视频第 0 帧，避免身份/身高跳变。所有原始帧和透明帧保留；没有把静态姿势拼接成这次的动画。

法线从轮廓距离场和低幅度衣褶明暗近似构造，不代表恢复了真实的布料厚度或人物三维几何。
