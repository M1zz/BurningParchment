// FireShader.metal
// Realistic fire: ridge noise tendrils, threshold emission, inner hot core,
// Gaussian envelope, exponential heat decay, blackbody color, smoke

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Noise Primitives

static float hash21(float2 p) {
    p = fract(p * float2(443.8975f, 397.2973f));
    p += dot(p, p.yx + 19.19f);
    return fract(p.x * p.y);
}

static float2 gradDir(float2 p) {
    float a = hash21(p) * 6.28318530f;
    return float2(cos(a), sin(a));
}

// Perlin gradient noise → [0, 1], quintic smoothstep
static float gnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * f * (f * (f * 6.0f - 15.0f) + 10.0f);
    float a = dot(gradDir(i),               f);
    float b = dot(gradDir(i + float2(1,0)), f - float2(1,0));
    float c = dot(gradDir(i + float2(0,1)), f - float2(0,1));
    float d = dot(gradDir(i + float2(1,1)), f - float2(1,1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5f + 0.5f;
}

static float fbm6(float2 p) {
    float v = 0.0f, amp = 0.5f, freq = 1.0f;
    for (int i = 0; i < 6; i++) { v += amp * gnoise(p * freq); amp *= 0.5f; freq *= 2.0f; }
    return v;
}

static float fbm7(float2 p) {
    float v = 0.0f, amp = 0.5f, freq = 1.0f;
    for (int i = 0; i < 7; i++) { v += amp * gnoise(p * freq); amp *= 0.5f; freq *= 2.0f; }
    return v;
}

// Ridged fBm: creates sharp, elongated tendrils (like real flame columns)
// Peaks occur at gnoise ≈ 0.5 (zero crossings of centered noise)
static float fbmRidge6(float2 p) {
    float v = 0.0f, amp = 0.5f, freq = 1.0f;
    for (int i = 0; i < 6; i++) {
        float n = 1.0f - abs(gnoise(p * freq) * 2.0f - 1.0f);
        v += amp * (n * n);   // squaring sharpens ridge crests
        amp *= 0.5f; freq *= 2.0f;
    }
    return saturate(v);
}

// Curl noise: divergence-free 2D velocity → realistic vortex swirls
static float2 curlN(float2 p) {
    const float e = 0.04f;
    return float2(
         gnoise(p + float2(0, e)) - gnoise(p - float2(0, e)),
        -(gnoise(p + float2(e, 0)) - gnoise(p - float2(e, 0)))
    );
}

// MARK: - Blackbody Color Ramp
// Physical fire emission: ember glow → dark red → orange → yellow-orange → hot white
static half4 fireRamp(float t) {
    t = saturate(t);
    if (t < 0.005f) return half4(0);
    float3 col; float a;
    if (t < 0.14f) {
        float s = t / 0.14f;
        col = mix(float3(0.08f,0.00f,0.00f), float3(0.52f,0.03f,0.00f), s);
        a = s * 0.88f;
    } else if (t < 0.34f) {
        float s = (t - 0.14f) / 0.20f;
        col = mix(float3(0.52f,0.03f,0.00f), float3(0.94f,0.22f,0.01f), pow(s, 0.75f));
        a = mix(0.88f, 0.96f, s);
    } else if (t < 0.60f) {
        float s = (t - 0.34f) / 0.26f;
        col = mix(float3(0.94f,0.22f,0.01f), float3(1.00f,0.60f,0.04f), s);
        a = 0.97f;
    } else if (t < 0.80f) {
        float s = (t - 0.60f) / 0.20f;
        col = mix(float3(1.00f,0.60f,0.04f), float3(1.00f,0.90f,0.25f), pow(s, 0.85f));
        a = 1.0f;
    } else {
        float s = (t - 0.80f) / 0.20f;
        col = mix(float3(1.00f,0.90f,0.25f), float3(1.00f,0.97f,0.90f), pow(s, 0.60f));
        a = 1.0f;
    }
    return half4(half3(col * a), half(a));
}

// MARK: - Parchment Burn Fire

[[stitchable]] half4 parchmentFire(
    float2 pos, half4 color,
    float2 size, float time, float progress
) {
    if (progress < 0.006f || progress > 0.994f) return half4(0);

    float2 uv        = pos / size;
    float  diag      = uv.x + uv.y;
    float  burnFront = 2.0f * (1.0f - progress);

    // 3-stage domain warp
    float2 warpA = float2(
        fbm6(uv * 2.7f + float2(time * 0.29f,  time * 0.18f)) - 0.5f,
        fbm6(uv * 2.7f + float2(0.5f + time * 0.23f, time * 0.35f)) - 0.5f
    );

    float2 curl = curlN(uv * 3.0f + float2(time * 0.14f, time * 0.19f));
    float2 warpB = float2(
        fbm6(uv * 5.5f + warpA * 0.65f + curl * 0.015f + float2(time * 0.48f, -time * 0.27f)) - 0.5f,
        fbm6(uv * 5.5f + warpA * 0.65f + curl * 0.015f + float2(-time * 0.25f, time * 0.52f)) - 0.5f
    );
    float2 warpC = float2(
        fbm6(uv * 10.5f + warpB * 0.40f + float2(time * 0.70f, -time * 0.42f)) - 0.5f,
        fbm6(uv * 10.5f + warpB * 0.40f + float2(-time * 0.35f, time * 0.65f)) - 0.5f
    ) * 0.028f;

    float turbDisp = warpB.x * 0.19f + warpA.y * 0.09f + warpC.x;
    float d = (burnFront - diag) + turbDisp;

    if (d < -0.10f) return half4(0);

    // Advection: buoyant rise driven by local heat
    float localHeat = saturate(1.0f - abs(d) / 0.28f);
    float2 advUV = uv + warpA * 0.13f;
    advUV.y -= time * (2.2f + localHeat * 2.2f) * 0.013f;
    advUV.x += curl.x * 0.035f * localHeat;

    // Mixed noise: ridge tendrils + smooth base + fine detail
    float2 fireUV = advUV * float2(4.0f, 7.8f) + float2(time * 0.12f, 0.0f);
    float  ridgeN  = fbmRidge6(fireUV);
    float  smoothN = fbm6(fireUV * 0.85f + float2(0.52f, 0.38f));
    float2 fireUV2 = advUV * float2(8.5f, 13.5f) + float2(-time * 0.19f, -time * 0.55f);
    float  fineN   = fbm6(fireUV2);
    float  noise   = ridgeN * 0.45f + smoothN * 0.32f + fineN * 0.23f;

    float fireWidth = 0.26f + noise * 0.22f;
    if (d > fireWidth) return half4(0);

    // Multi-frequency flicker
    float flicker = 0.80f
        + 0.11f * sin(time * 11.5f + pos.x * 0.065f + pos.y * 0.038f)
        + 0.05f * sin(time * 25.8f + pos.x * 0.115f)
        + 0.04f * cos(time *  7.8f  + pos.y * 0.082f);

    if (d < 0.0f) {
        // ── BURNED SIDE: pulsing hot-coal embers ──
        float emberFade  = 1.0f + d / 0.10f;
        float coalPulse  = 0.78f + 0.22f * sin(time * 3.8f + pos.x * 0.06f + pos.y * 0.04f);
        float emberNoise = ridgeN * 0.55f + fineN * 0.45f;
        float heat = emberFade * (0.58f + emberNoise * 0.46f) * coalPulse * flicker;
        return fireRamp(saturate(heat));

    } else if (d <= fireWidth) {
        // ── FIRE ZONE ──
        // White-hot ignition line at the burn front (d ≈ 0): simulates 1000 °C+ paper ignition
        float hotLine  = exp(-d * 58.0f) * 0.96f;

        // Threshold-based emission → sharp flame boundaries, not smoky blobs
        float heightT  = 1.0f - d / fireWidth;
        float threshold = mix(0.26f, 0.52f, d / max(fireWidth, 0.01f));
        float emission  = smoothstep(threshold, threshold + 0.24f, noise);
        float fireHeat  = pow(saturate(heightT * emission * 2.50f), 0.78f);

        float heat = max(hotLine, fireHeat) * flicker;
        return fireRamp(saturate(heat));

    }

    return half4(0);
}

// MARK: - Heart Erosion

[[stitchable]] half4 heartErosion(
    float2 pos, SwiftUI::Layer layer,
    float2 size, float time, float burnLevel
) {
    half4 src = layer.sample(pos);
    if (src.a < 0.01f) return half4(0);

    float2 uv   = pos / size;
    float2 curl = curlN(uv * 5.0f + float2(time * 0.12f, time * 0.17f));
    float2 warp = float2(
        fbm6(uv * 4.5f + curl * 0.015f + float2(time * 0.20f, 0.0f)) - 0.5f,
        fbm6(uv * 4.5f + curl * 0.015f + float2(0.0f, time * 0.24f)) - 0.5f
    ) * 0.12f;

    float erosionField = fbm7(uv * 8.0f + warp + float2(time * 0.15f, time * 0.11f));

    float nb = 4.0f;
    float aR = layer.sample(pos + float2( nb,  0)).a;
    float aL = layer.sample(pos + float2(-nb,  0)).a;
    float aD = layer.sample(pos + float2(  0, nb)).a;
    float aU = layer.sample(pos + float2(  0,-nb)).a;
    float edgeFactor = 1.0f - min(min(aR,aL), min(aD,aU));

    float erosionValue = erosionField + edgeFactor * 0.26f * burnLevel;
    float threshold    = burnLevel * 0.85f + erosionField * 0.06f * burnLevel;

    if (erosionValue < threshold) return half4(0);

    float edgeDist = erosionValue - threshold;
    float edgeGlow = 1.0f - smoothstep(0.0f, 0.14f, edgeDist);

    // Blackbody edge: blue-white (hottest) → yellow-white → orange
    float3 col0 = float3(0.98f, 0.96f, 1.00f);
    float3 col1 = float3(1.00f, 0.94f, 0.60f);
    float3 col2 = float3(1.00f, 0.40f, 0.03f);
    float  cT   = smoothstep(0.0f, 0.09f, edgeDist);
    float3 burnColor = cT < 0.5f
        ? mix(col0, col1, cT * 2.0f)
        : mix(col1, col2, (cT - 0.5f) * 2.0f);

    half4 result = src;
    result.rgb = mix(src.rgb, half3(burnColor.x, burnColor.y, burnColor.z),
                     half(edgeGlow * min(0.95f, 0.5f + burnLevel * 0.5f)));
    result.a = src.a * saturate(edgeDist * 7.0f);
    return result;
}

// MARK: - Heart Fire

[[stitchable]] half4 heartFire(
    float2 pos, half4 color,
    float2 size, float time, float intensity
) {
    if (intensity < 0.02f) return half4(0);

    float2 uv          = pos / size;
    float2 heartCenter = float2(0.5f, 0.56f);
    float  aboveCenter = heartCenter.y - uv.y;
    float  horizDist   = abs(uv.x - 0.5f);

    float maxFireH   = 0.46f * (0.70f + intensity * 0.48f);
    float smokeStart = maxFireH * 0.76f;
    float smokeEnd   = maxFireH + 0.26f;

    if (aboveCenter < -0.06f || aboveCenter > smokeEnd || horizDist > 0.52f) return half4(0);

    // Domain warp — shared between fire and smoke paths
    float2 warpA = float2(
        fbm6(uv * 3.2f + float2(time * 0.38f, 0.0f)) - 0.5f,
        fbm6(uv * 3.2f + float2(0.3f, time * 0.34f)) - 0.5f
    ) * 0.18f;

    float2 curl = curlN(uv * 3.8f + float2(time * 0.20f, time * 0.25f));

    float2 warpB = float2(
        fbm6(uv * 6.5f + warpA * 0.55f + curl * 0.015f + float2(time * 0.52f, -time * 0.30f)) - 0.5f,
        fbm6(uv * 6.5f + warpA * 0.55f + curl * 0.015f + float2(-time * 0.27f, time * 0.56f)) - 0.5f
    ) * 0.08f;

    float riseT    = saturate(aboveCenter / maxFireH);
    float maxHoriz = 0.35f * (1.0f - riseT * 0.72f) * (0.85f + intensity * 0.30f);
    float hFrac    = horizDist / max(maxHoriz, 0.01f);

    // Advection: buoyant rise + curl lateral drift
    float centerWeight = saturate(1.0f - horizDist / 0.25f);
    float2 advUV = uv + warpA + warpB;
    float  advSpeed = (1.8f + centerWeight * 2.2f * intensity) * (1.0f - riseT * 0.35f);
    advUV.y -= time * advSpeed * 0.014f;
    advUV.x += curl.x * 0.040f * centerWeight;

    // Mixed noise: ridge creates tendrils, smooth holds shape, fine adds texture
    float2 fireUV  = advUV * float2(3.5f, 6.2f)   + float2(time * 0.22f, 0.0f);
    float  ridgeN  = fbmRidge6(fireUV);
    float  smoothN = fbm6(fireUV * 0.88f + float2(0.42f, 0.38f));
    float2 fireUV2 = advUV * float2(7.0f, 10.5f)  + float2(-time * 0.30f, -time * 0.75f);
    float  fineN   = fbm6(fireUV2);

    float noise = ridgeN * 0.50f + smoothN * 0.26f + fineN * 0.24f;

    // ── OUTER FLAME ──
    // Gaussian lateral (sharp boundary), power-law height, threshold emission
    float lateralDecay = exp(-hFrac * hFrac * 1.6f);
    float heightDecay  = pow(saturate(1.0f - riseT), 1.5f);
    float outerThresh  = mix(0.30f, 0.54f, riseT);   // base dense → tip wispy
    float outerEmit    = smoothstep(outerThresh, outerThresh + 0.22f, noise);
    float outerShape   = saturate(lateralDecay * heightDecay * outerEmit * intensity);

    // ── INNER HOT CORE ──
    // Narrow Gaussian column, persists higher, threshold emission at 40%
    float innerHFrac   = horizDist / max(maxHoriz * 0.38f, 0.01f);
    float innerLateral = exp(-innerHFrac * innerHFrac * 3.0f);
    float innerHeight  = pow(saturate(1.0f - riseT), 0.78f);
    float innerEmit    = smoothstep(0.38f, 0.54f, noise);
    float innerShape   = saturate(innerLateral * innerHeight * innerEmit * intensity * 1.15f);

    // ── BASE GLOW ──
    // Very bright attachment zone where flame emerges from heart surface
    float baseGlow = saturate(
        exp(-riseT * 9.0f) * exp(-hFrac * hFrac * 3.2f)
        * (0.55f + 0.45f * noise) * intensity
    );

    // Multi-frequency flicker
    float flicker = 0.76f
        + 0.13f * sin(time * 14.0f  + pos.x * 0.080f + pos.y * 0.055f)
        + 0.06f * sin(time * 28.5f  + pos.x * 0.140f)
        + 0.05f * cos(time *  9.2f  + pos.y * 0.072f);

    outerShape *= flicker;
    innerShape *= flicker * 1.10f;
    baseGlow   *= 0.92f + 0.08f * sin(time * 8.5f);

    if (outerShape < 0.015f && innerShape < 0.015f && baseGlow < 0.04f) {
        // Smoke: gray wisps rising from flame tip
        if (aboveCenter > smokeStart) {
            float smokeT     = saturate((aboveCenter - smokeStart) / (smokeEnd - smokeStart));
            float smokeFade  = 1.0f - smokeT;
            float smokeHMax  = 0.14f + smokeT * 0.10f;
            float smokeHFrac = horizDist / max(smokeHMax, 0.01f);
            if (smokeHFrac < 1.5f) {
                float2 smokeUV = uv * float2(2.0f, 2.8f) + float2(time * 0.04f, -time * 0.62f);
                float  smokeN  = fbm6(smokeUV + warpA * 0.30f);
                float  smokeShape = smokeN * saturate(1.2f - smokeHFrac) * smokeFade;
                smokeShape = smoothstep(0.38f, 0.62f, smokeShape);
                float smokeAlpha = smokeShape * smokeFade * 0.30f * min(intensity, 1.0f);
                if (smokeAlpha > 0.02f) {
                    float gray = 0.32f + smokeN * 0.28f;
                    return half4(gray, gray, gray, smokeAlpha);
                }
            }
        }
        return half4(0);
    }

    // ── TEMPERATURE COMPOSITION ──
    // Each layer maps to a physical temperature range:
    //   outer → 0-0.68 (red-orange)
    //   inner → 0.58-0.93 (orange-yellow-white)
    //   base  → 0.82-0.99 (yellow-white to near-white)
    float outerTemp = outerShape * 0.70f;
    float innerTemp = smoothstep(0.02f, 0.08f, innerShape)
                    * mix(0.58f, 0.93f, innerShape);
    float baseTemp  = smoothstep(0.03f, 0.10f, baseGlow)
                    * mix(0.82f, 0.99f, baseGlow);

    float finalTemp = max(max(outerTemp, innerTemp), baseTemp);

    return fireRamp(saturate(finalTemp));
}

// MARK: - Flame Kinds (FlameView)
//
// 들불·숯불은 Canvas 가 그린 "열 지도"(흰색, 알파 = 열) 위에 layerEffect 로 걸린다.
// 모양은 Swift 쪽 기하(타는 경계선)를 그대로 따르고, 셰이더는 노이즈로 그 열을
// 흐름 방향(flow)으로 일렁이게 끌어내고 흑체 색으로 바꾼다.
//   flow  — 불꽃이 솟는 방향(단위 벡터, 포인트 좌표)
//   scale — 불꽃 크기 배율 (불 끄기 화면은 1.5, 설정 카드는 0.8)

static float fbm4(float2 p) {
    float v = 0.0f, amp = 0.5f;
    for (int i = 0; i < 4; i++) { v += amp * gnoise(p); p *= 2.03f; amp *= 0.5f; }
    return v;
}

static float fbmRidge4(float2 p) {
    float v = 0.0f, amp = 0.5f;
    for (int i = 0; i < 4; i++) {
        float n = 1.0f - abs(gnoise(p) * 2.0f - 1.0f);
        v += amp * n * n;
        p *= 2.03f; amp *= 0.5f;
    }
    return saturate(v * 1.15f);
}

// 들불 — 길게 찢어지는 불길, 하얗게 달아오른 뿌리
[[stitchable]] half4 blazeFire(float2 pos, SwiftUI::Layer layer,
                               float time, float2 flow, float scale) {
    float2 n = normalize(flow);
    float2 t = float2(-n.y, n.x);

    // 주변에 열이 전혀 없으면 노이즈를 계산하지 않는다 (화면 대부분이 여기서 끝난다)
    float reach = 28.0f * scale;
    float probe = max(max(layer.sample(pos).a, layer.sample(pos - n * reach).a),
                      max(layer.sample(pos + t * reach * 0.6f).a, layer.sample(pos - t * reach * 0.6f).a));
    if (probe < 0.003f) return half4(0);

    // 흐름 좌표계: x = 가로, y = 솟는 방향. 세로로 늘여 길쭉한 혀를 만들고 바깥으로 흘려보낸다
    float2 q = float2(dot(pos, t), dot(pos, n)) / (22.0f * scale);
    q.y = q.y * 0.6f - time * 0.95f;

    float2 w = float2(fbm4(q + float2(0.0f, time * 0.12f)),
                      fbm4(q * 1.3f + float2(5.2f, 1.3f))) - 0.5f;

    // 끝으로 갈수록(열이 낮을수록) 크게 흔들린다. 흐름 반대쪽을 읽어 와 뿌리의 열을 밖으로 핥아 올린다
    float h0  = layer.sample(pos).a;
    float amp = mix(22.0f, 7.0f, saturate(h0 * 1.4f)) * scale;
    float2 off = (t * w.x * 1.2f + n * (w.y - 0.28f)) * amp;
    float heat = layer.sample(pos + off).a;
    if (heat < 0.004f) return half4(0);

    float ridge  = fbmRidge4(q * 2.0f + w * 1.8f);
    float detail = gnoise(q * 5.0f + float2(0.0f, -time * 1.6f));
    float flick  = 0.88f + 0.12f * sin(time * 9.0f + q.x * 3.0f);

    // 하얗게 달아오르는 건 뿌리(열 0.8 이상)뿐 — 몸통은 주황, 끝은 붉게 사그라든다
    float temp = pow(heat, 1.25f) * 1.02f * flick
               - (1.0f - ridge) * 0.50f * (1.1f - heat)
               - (detail - 0.5f) * 0.15f;
    return fireRamp(saturate(temp));
}

// 숯불 — 낮게 깔린 붉은 띠, 천천히 숨 쉬는 숯 알갱이와 가끔 하얗게 달아오르는 자리
[[stitchable]] half4 smolderFire(float2 pos, SwiftUI::Layer layer,
                                 float time, float2 flow, float scale) {
    float2 n = normalize(flow);
    float2 t = float2(-n.y, n.x);

    float probe = max(layer.sample(pos).a, layer.sample(pos - n * 9.0f * scale).a);
    if (probe < 0.003f) return half4(0);

    float2 q = float2(dot(pos, t), dot(pos, n)) / (9.0f * scale);
    float2 w = float2(gnoise(q * 0.7f + float2(0.0f, -time * 0.35f)),
                      gnoise(q * 0.7f + float2(3.1f,  time * 0.30f))) - 0.5f;
    float heat = layer.sample(pos + (t * w.x + n * (w.y - 0.15f)) * 6.0f * scale).a;
    if (heat < 0.004f) return half4(0);

    float cells = fbm4(q * 1.4f + float2(time * 0.05f, 0.0f));
    float pulse = 0.5f + 0.5f * sin(time * 1.6f + cells * 9.0f);
    float temp  = heat * (0.40f + 0.36f * cells + 0.20f * pulse);
    temp = min(temp, 0.70f);                                   // 대부분 붉은 주황
    temp += smoothstep(0.60f, 0.78f, cells) * heat * 0.35f;    // 드문드문 달아오른 숯
    return fireRamp(saturate(temp));
}
