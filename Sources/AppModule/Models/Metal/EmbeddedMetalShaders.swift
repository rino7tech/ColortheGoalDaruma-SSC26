import Foundation

/// Swift Playgrounds でも扱えるよう、Metal シェーダーを Swift 文字列で保持する。
enum EmbeddedMetalShaders {
    static let calligraphyBrush = #"""
#include <metal_stdlib>
using namespace metal;

struct BrushVertexIn {
    float2 position [[attribute(0)]];
    float  crossU   [[attribute(1)]];
    float  alongV   [[attribute(2)]];
    float  speed    [[attribute(3)]];
    float  pressure [[attribute(4)]];
};

struct BrushVertexOut {
    float4 position [[position]];
    float  crossU;
    float  alongV;
    float  speed;
    float  pressure;
};

struct BrushUniforms {
    float2 viewportSize;
    float4 inkColor;
};

float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * valueNoise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

vertex BrushVertexOut calligraphyVertex(
    BrushVertexIn in [[stage_in]],
    constant BrushUniforms& uniforms [[buffer(1)]])
{
    BrushVertexOut out;

    float2 ndc;
    ndc.x = (in.position.x / uniforms.viewportSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (in.position.y / uniforms.viewportSize.y) * 2.0;

    out.position = float4(ndc, 0.0, 1.0);
    out.crossU   = in.crossU;
    out.alongV   = in.alongV;
    out.speed    = in.speed;
    out.pressure = in.pressure;

    return out;
}

fragment half4 calligraphyFragment(
    BrushVertexOut in [[stage_in]],
    constant BrushUniforms& uniforms [[buffer(1)]])
{
    float distFromCenter = abs(in.crossU - 0.5) * 2.0;
    float edgeAlpha = 1.0 - smoothstep(0.75, 1.0, distFromCenter);

    float2 noiseCoord = float2(in.crossU * 8.0, in.alongV * 30.0);
    float brushTexture = fbm(noiseCoord);
    float textureFactor = mix(1.0, brushTexture * 0.25 + 0.75, distFromCenter);

    float speedNormalized = clamp(in.speed / 800.0, 0.0, 1.0);
    float dryBrushNoise = valueNoise(float2(in.alongV * 50.0, in.crossU * 10.0));
    float dryBrushAlpha = 1.0 - speedNormalized * 0.25 * step(0.62, dryBrushNoise);

    float taperIn  = smoothstep(0.0, 0.03, in.alongV);
    float taperOut = smoothstep(1.0, 0.97, in.alongV);
    float taper = taperIn * taperOut;

    float alpha = edgeAlpha * textureFactor * dryBrushAlpha * taper;
    alpha *= mix(0.95, 1.15, in.pressure);
    alpha *= 1.25;
    alpha = clamp(alpha, 0.0, 1.0);

    half4 color = half4(uniforms.inkColor);
    color.a *= half(alpha);
    return color;
}
"""#

    static let liquidFill = #"""
#include <metal_stdlib>
using namespace metal;

struct LiquidFillUniforms {
    float fillProgress;
    float time;
    float waveAmplitude;
    float waveFrequency;
    float4 liquidColor;
};

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texCoords;
};

struct SCNSceneBuffer {
    float4x4 modelTransform;
    float4x4 inverseModelTransform;
    float4x4 modelViewTransform;
    float4x4 inverseModelViewTransform;
    float4x4 normalTransform;
    float4x4 modelViewProjectionTransform;
    float4x4 inverseModelViewProjectionTransform;
    float2x3 boundingBox;
};

vertex VertexOut liquidFillVertex(
    VertexIn in [[stage_in]],
    constant SCNSceneBuffer& scn_frame [[buffer(0)]],
    constant LiquidFillUniforms& uniforms [[buffer(1)]])
{
    VertexOut out;
    float4 worldPos = scn_frame.modelTransform * float4(in.position, 1.0);
    out.worldPosition = worldPos.xyz;
    out.position = scn_frame.modelViewProjectionTransform * float4(in.position, 1.0);
    out.normal = (scn_frame.normalTransform * float4(in.normal, 0.0)).xyz;
    out.texCoords = in.texCoords;
    return out;
}

fragment float4 liquidFillFragment(
    VertexOut in [[stage_in]],
    constant LiquidFillUniforms& uniforms [[buffer(0)]],
    texture2d<float> baseTexture [[texture(0)]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 baseColor = baseTexture.sample(textureSampler, in.texCoords);

    float yPosition = in.worldPosition.y;
    float wave = sin(in.worldPosition.x * uniforms.waveFrequency + uniforms.time * 2.0) * uniforms.waveAmplitude;
    wave += sin(in.worldPosition.z * uniforms.waveFrequency * 1.3 - uniforms.time * 1.5) * uniforms.waveAmplitude * 0.5;

    float fillThreshold = mix(2.0, -2.0, uniforms.fillProgress);
    float fillLine = yPosition + wave;

    float edgeSoftness = 0.15;
    float fillMask = smoothstep(fillThreshold - edgeSoftness, fillThreshold + edgeSoftness, fillLine);

    float4 transparentColor = float4(baseColor.rgb, 0.0);
    float4 filledColor = float4(uniforms.liquidColor.rgb, baseColor.a * uniforms.liquidColor.a);
    float4 finalColor = mix(filledColor, transparentColor, fillMask);
    return finalColor;
}
"""#
}
