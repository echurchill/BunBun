# BunBun Bunny Art and Animation Options

**Research date:** September 25, 2026  
**Status:** Future-production research; no art pipeline selected or implemented yet

## Recommendation

The strongest fit for BunBun is **3D-made, but 2D-delivered**.

Create or license one original animated 3D bunny, animate it in Blender, and render transparent animation frames into SpriteKit texture atlases. This can retain the soft, lively 3D appearance of the remembered game while avoiding the complexity and runtime cost of rendering many skeletal 3D characters simultaneously on an iPhone.

This approach fits the current architecture well: the pure Swift rules remain unchanged, while `BunnyNode` can later replace its placeholder shapes with texture animations. SpriteKit directly supports frame animation and optimized texture atlases.

References:

- [Apple: Animating a Sprite by Changing its Texture](https://developer.apple.com/documentation/spritekit/animating-a-sprite-by-changing-its-texture)
- [Apple: SKTextureAtlas](https://developer.apple.com/documentation/spritekit/sktextureatlas)

## Option comparison

| Approach | Likely tool/asset cost | Benefits | Drawbacks | Fit for BunBun |
| --- | ---: | --- | --- | --- |
| Pre-rendered 3D sprite animation | $0–$40 initially | Convincing 3D appearance, strong performance, compatible with SpriteKit, one model can produce every color | Fixed viewing angle; new actions require rendering new frames | **Recommended** |
| Live 3D characters | Asset cost plus substantially more development time | Dynamic camera, lighting, materials, and animation | More engineering, asset conversion, performance tuning, and presentation changes | Preserve as a future option |
| Rive or Spine 2D skeletal animation | Approximately $9/month or $69+ | Lightweight, highly expressive, interactive animation states | Flatter appearance; layered artwork and rigging still require work | Good alternative if 3D production proves troublesome |
| AI-generated frame-by-frame sprites | Potentially very low | Fast concept experiments and no 3D pipeline | Character, lighting, proportions, and markings can drift between frames | Useful for concepts, risky for final animation |
| Conventional hand-drawn sprites | Highly variable | Complete artistic control | Many drawings are needed for the desired amount of motion | Impractical without an animator |

Prices are snapshots from the research date and may change.

## Low-cost downloadable models

### Free test models

These could be used to prove the import, animation, rendering, and SpriteKit-atlas workflow before spending anything:

1. [Low-poly animated rabbit on Sketchfab](https://sketchfab.com/3d-models/low-poly-animated-rabbit-dcf4d25f535347b1bfb859c659314bde)
   - 856 triangles and 430 vertices.
   - Rigged, textured, and supplied with five animations.
   - Creative Commons Attribution license.
   - Technically attractive for a pipeline test, although probably not expressive enough for the finished character.

2. [Cute stylized bunny on Sketchfab](https://sketchfab.com/3d-models/cute-bunny-a44cfe6e2b0142a7b6425878b6b811bf)
   - Approximately 7,600 triangles.
   - Rigged, textured, and available as GLB/FBX.
   - Includes loopable walking, idle, and custom animation.
   - Creative Commons Attribution license.

Free does not mean unrestricted. A CC BY asset must be credited, and its attribution information should be recorded when it is downloaded.

### Inexpensive candidates

1. [$20 Rabbit Bunny Hare Animated Rigged on CGTrader](https://www.cgtrader.com/3d-models/animal/mammal/rabbit-bunny-animated-rigged)
   - 3,440 polygons and 3,427 vertices.
   - Eighteen animations, including idle, run, jump, skid, dizzy, wave, crash, and power-up.
   - FBX, Maya, and OBJ files.
   - Humanoid-compatible rig that can use Mixamo-style animation.
   - Royalty Free License (No AI).
   - This was the most promising inexpensive ready-made candidate found during the initial search.

2. [Cartoon Rabbit Character on Fab](https://www.fab.com/listings/68a8c3e4-cb71-430c-80b0-18d2acf587ad)
   - Twenty-eight animations.
   - Twenty rabbit color variations.
   - Customizable outfits and accessories.
   - FBX source and a game-ready rig.
   - The storefront price was not exposed to the research tool and must be checked before purchase.

3. [Stuffed Bunny on Fab](https://www.fab.com/listings/51cf7db0-f570-4acc-9bf5-3745966899b8)
   - Approximately 10,320 triangles.
   - Includes idle variations, walking, running, jumping, and dancing.
   - Its toy-like style may suit a warm birthday-game presentation.
   - The storefront price must be checked before purchase.

4. [White Bunny Rabbit on Fab](https://www.fab.com/listings/46403b86-938e-48a9-a95e-2de7b0249eda)
   - Rigged and animated in Blender.
   - Includes idle, running, grazing, and inspection actions.
   - FBX, GLB, glTF, and USDZ formats are listed.

Fab's Standard License permits commercial or private use, modification, and distribution as part of a project. It does not permit redistributing the asset by itself. Both Personal and Professional pricing tiers grant the same usage rights.

- [Fab Standard License summary](https://www.fab.com/eula)
- [Fab licensing and pricing documentation](https://dev.epicgames.com/documentation/fab/licenses-and-pricing-in-fab)
- [CGTrader Royalty Free License](https://help.cgtrader.com/hc/en-us/articles/360015124437-Royalty-Free-License)

## AI-generated 3D options

### Meshy

Meshy provides text-to-3D and image-to-3D generation, texturing, automatic rigging, and animation presets.

At the research date, the individual Pro plan was listed at $20 per month with 1,000 credits, downloadable private models, commercial rights, and more than 600 animation presets. A single paid month could be sufficient to explore and refine one character. The free plan is useful for experimentation but does not currently include model downloads.

References:

- [Meshy plan comparison](https://help.meshy.ai/en/articles/12062933-which-meshy-plan-is-right-for-you-free-vs-pro-vs-premium-vs-ultra)
- [Meshy features](https://www.meshy.ai/features)
- [Meshy commercial-use guidance](https://intercom.help/meshy/en/articles/16102098-can-i-use-meshy-assets-commercially)

### Tripo

Tripo provides image-to-3D and text-to-3D generation, retopology, automatic rigging, animation retargeting, and common export formats including GLB, FBX, OBJ, and USDZ.

Its API pricing at the research date was one cent per credit. Indicative costs were:

- Image-to-3D: 20–30 credits ($0.20–$0.30).
- Automatic rigging: 25 credits ($0.25).
- Animation retargeting: 10 credits ($0.10) per animation.
- Texture generation and retopology incur additional small charges.

Those are operation prices, not the total cost of a finished character. Multiple generations, retries, texture work, and cleanup should be expected. Paid users receive commercial rights; free-user outputs do not receive the same commercial-use grant.

References:

- [Tripo API and pricing](https://developers.tripo3d.ai/)
- [Tripo commercial-use guidance](https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially)

### AI limitations

An AI-generated model should be treated as a strong starting point, not automatically as a finished game asset. Likely cleanup areas include:

- Facial symmetry and eye placement.
- Ear and tail geometry.
- Mesh topology around bending joints.
- Skinning weights and deformation.
- Texture seams.
- Animation foot sliding and clipping.
- Polygon count and texture size.

Any input image should be original or properly licensed. Screenshots or artwork from *Boogie Bunnies* should not be supplied as generation inputs. BunBun needs its own recognizable visual identity rather than a reproduction of the original characters.

## Blender as the production hub

[Blender](https://www.blender.org/) is free and open-source and can handle model cleanup, materials, rigging, animation, lighting, and transparent sprite rendering. Artwork created with Blender belongs to its creator and can be used commercially.

References:

- [Blender license and artwork ownership](https://www.blender.org/about/license/)
- [Blender animation and rigging manual](https://docs.blender.org/manual/en/latest/animation/index.html)

A Blender-centered pipeline also avoids locking the project to one AI vendor. The master model and animations can be retained independently even if the generating service later changes its price or features.

## Animation sources

### Existing model animations

Buying a model with a useful collection of animations is the least labor-intensive option. Animation names alone are not enough; candidate models should be previewed for personality, clean looping, deformation quality, and suitability at BunBun's small on-screen size.

### Adobe Mixamo

Mixamo is free with an Adobe ID, and its characters and animations can be used royalty-free in personal, commercial, and nonprofit games. Its automatic rigger and animation library support bipedal humanoids only.

This makes Mixamo potentially useful if BunBun's bunny is an upright cartoon character with a humanoid skeleton. It is not suitable for automatically rigging a conventional four-legged rabbit.

- [Adobe Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)

### Custom animation in Blender

Custom Blender animation gives the bunny the most personality and allows actions designed around the actual puzzle mechanics. It costs no money but does require learning and production time. AI-generated or purchased animations can serve as a base and then be adjusted.

## 2D skeletal alternatives

### Rive

Rive provides bones, constraints, interactive state machines, and an open-source iOS runtime. It is free for learning; its current Cadet plan is advertised at $9 per month when billed annually for shipping exported runtime files. Its runtime is MIT licensed.

- [Rive pricing](https://www.rive.app/pricing)
- [Rive runtime overview and license](https://github.com/rive-app/help-center/blob/master/runtimes/overview.md)

Rive would be good for a flat illustrated bunny with responsive eyes, ears, face, and body motion. It is less suitable if the goal remains a visibly rounded 3D character.

### Spine

Spine Essential was listed at $69 as a one-time purchase during the research period, while Spine Professional was listed at $379. Essential supports basic skeletal animation but omits advanced features such as meshes and inverse kinematics.

- [Spine purchase and feature comparison](https://us.esotericsoftware.com/spine-purchase)

Spine is mature and game-focused, but BunBun probably does not need another paid tool if the selected workflow uses Blender-rendered sprites.

## Live 3D on Apple platforms

SpriteKit can embed SceneKit content through `SK3DNode`, but Apple now marks SceneKit as deprecated and recommends RealityKit instead. Therefore a new long-term live-3D implementation should not be built around `SK3DNode` and SceneKit.

RealityKit can load animated USD, USDA, USDC, and USDZ assets. A future RealityKit presentation could provide dynamic lighting, camera movement, real-time recoloring, and close-up character celebrations.

References:

- [Apple: SceneKit deprecation notice](https://developer.apple.com/documentation/scenekit/)
- [Apple: SK3DNode](https://developer.apple.com/documentation/spritekit/sk3dnode)
- [Apple: Loading entities in RealityKit](https://developer.apple.com/documentation/realitykit/loading-entities-from-a-file)
- [Apple: Bringing SceneKit projects to RealityKit](https://developer.apple.com/documentation/realitykit/bringing-your-scenekit-projects-to-realitykit)

Live 3D remains technically possible because BunBun's rules and presentation are separated. However, it would be a deliberate presentation-layer project requiring asset conversion, performance profiling, camera work, and new rendering integration. It should not be the next gameplay milestone.

## Proposed production workflow

When BunBun is ready for its character-art pass:

1. Create an original bunny design sheet with front, three-quarter, side, and back views plus several facial expressions.
2. Choose between an inexpensive licensed base model and an AI-generated model based on that original sheet.
3. Clean, optimize, texture, and rig one master bunny in Blender.
4. Use material variations for the gameplay colors instead of maintaining separate models.
5. Build and test the core animation library in Blender.
6. Establish a fixed orthographic camera and lighting setup matching the game board.
7. Render transparent PNG sequences at suitable iPhone resolutions.
8. Pack the frames into SpriteKit texture atlases.
9. Replace the internals of `BunnyNode` without changing the pure Swift game rules.
10. Test memory use and frame rate on the oldest supported physical iPhone.

## Suggested animation library

The character does not need dozens of elaborate animations immediately. Frequent small movements can create much of the remembered liveliness.

### Essential

- Two or three idle loops with blinking, glancing, ear movement, and foot taps.
- March or shuffle toward the hazard.
- Launch/hop through a lane.
- Landing and recovery.
- Match celebration.
- Clear/disappearance reaction.
- Falling or danger reaction.
- Three or four dance loops.

### Later polish

- Neighbor interaction or synchronized idle moments.
- Chain-stage celebrations of increasing intensity.
- Anticipation before advancement.
- Nervous reactions near the hazard.
- Special-bunny activation poses.
- Win celebration and birthday-finale choreography.
- Costume-specific flourishes.

## Licensing and repository precautions

For every downloaded or purchased asset:

1. Record the asset URL, creator, purchase date, license, receipt, and required attribution.
2. Avoid Editorial and NonCommercial licenses.
3. Confirm that modification, rendered output, and distribution inside a game are permitted.
4. Do not assume that a free download permits commercial use.
5. Preserve a copy of the license that applied on the acquisition date.

If BunBun's GitHub repository remains public, purchased FBX, GLB, USDZ, or Blender source files must not be committed unless their license explicitly permits source redistribution. Those files should be stored privately. The public repository should contain only material the project is allowed to redistribute, such as original assets, properly attributed permissive assets, or rendered sprite sheets allowed by the source license.

## Current decision

No purchase or integration is needed during the current gameplay prototypes.

When an art-pipeline experiment becomes useful, begin with a free CC BY model to validate Blender rendering and SpriteKit texture animation. If the experiment succeeds, compare the $20 pre-animated CGTrader character against one paid month of Meshy or a small Tripo generation run.

The expected initial asset/tool budget is approximately **$0–$40**, excluding optional professional artist work. The live-3D RealityKit route remains available later because the game's rules are already isolated from its presentation.
