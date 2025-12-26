#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

float sdfSuperellipse(float2 p, float2 r, float n) {
    float2 rr = max(r, float2(1e-6));
    float nx = n + 1.0;
    float ny = max(n - 1.0, 0.1);
    float ax = abs(p.x / rr.x);
    float ay = abs(p.y / rr.y);
    float v = pow(ax, nx) + pow(ay, ny);
    float k = 1.0 / min(nx, ny);
    float R = pow(v + 1e-12, k);
    return (R - 1.0) * min(rr.x, rr.y);
}

[[stitchable]] half4 liquidGlass(
    float2 position,
    SwiftUI::Layer layer,
    float4 rect,
    float zoomFactor,
    float aberration,
    float rimThickness,
    float strenghten
) {
    float2 glassSize = rect.zw;
    float2 glassCenter = rect.xy + (glassSize * 0.5);
    float2 p = position - glassCenter + 1e-5;
    float nShape = 2.8;

    float distValue = sdfSuperellipse(p, glassSize * 0.5, nShape);
    
    if (distValue > 20.0) { return layer.sample(position); }

    half4 bg = layer.sample(position);
    half4 outsideColor = bg;

    if (distValue > 0.0) {
        float yNorm = p.y / (glassSize.y * 0.4);
        float bottomZone = smoothstep(0.3, 1.5, yNorm);
        float glowFade = exp(-distValue * 0.3);
        float intensity = bottomZone * glowFade * 0.25;
        
        half4 glowColor = half4(0.3, 0.3, 0.3, 0.3);
        outsideColor = mix(outsideColor, glowColor, half(intensity));
        return outsideColor;
    }

    float distToEdge = -distValue;
    float minDim = min(glassSize.x, glassSize.y);
    float normalizedDist = clamp(1.0 - (distToEdge / (minDim * 0.15)), 0.0, 1.0);

    float distortionCurve = 1.0 - sqrt(1.0 - pow(normalizedDist, 1.0));
    float2 direction = normalize(p);
    
    float xRatio = abs(p.x) / (glassSize.x * 0.5);
    
    float sideBias = smoothstep(0.2, 2, xRatio);
    
    float strengthProfile = mix(0, 1.7, sideBias);

    if (strenghten != 1.0) { strengthProfile = 1.0; }
    float2 lensOffset = direction * distortionCurve * 20.5 * strengthProfile;
    
    float2 sampleBase;
    if (abs(zoomFactor - 1.0) < 0.001) {
        sampleBase = position;
    } else {
        sampleBase = glassCenter + (p * zoomFactor);
    }
    
    float2 sampleCoord = sampleBase - lensOffset;

    half3 glassRGB;
    half glassAlpha;

    if (aberration < 0.001) {
        half4 s = layer.sample(sampleCoord);
        glassRGB = s.rgb;
        glassAlpha = s.a;
    } else {
        float2 caVec = 1.0 * (aberration * 1.5) * distortionCurve;
        
        half r1 = layer.sample(sampleCoord + caVec).r;
        half r2 = layer.sample(sampleCoord + caVec * 0.5).r;
        half r = (r1 + r2) * 0.5;

        half b1 = layer.sample(sampleCoord - caVec).b;
        half b2 = layer.sample(sampleCoord - caVec * 0.5).b;
        half b = (b1 + b2) * 0.5;

        half4 sG = layer.sample(sampleCoord);
        half g = sG.g;

        glassRGB = half3(r, g, b);
        glassAlpha = sG.a;
    }

    float verticalDir = normalize(p).y;
    
    float topArchMask = smoothstep(-0.5, 1.1, -verticalDir);
    float topEdgeFade = exp(-distToEdge * 0.13);
    float shadowFactor = topArchMask * topEdgeFade * 0.2;
    
    glassRGB *= (1.0 - half(shadowFactor));
    glassAlpha = max(glassAlpha, half(shadowFactor * 0.6));

    float bottomCupMask = smoothstep(-0.5, 1.2, verticalDir);
    float bottomEdgeFade = exp(-distToEdge * 0.15);
    half highlightStr = half(bottomCupMask * bottomEdgeFade * 0.05);
    glassRGB += half3(1.0, 1.0, 1.0) * highlightStr * glassAlpha;

    if (rimThickness > 0.01) {
        float safeThickness = rimThickness;
        float2 lightDir = normalize(float2(0.3, 0.8));
        float2 normal = normalize(p);
        
        float lighting = dot(normal, lightDir);
        float rimMask = 1.0 - smoothstep(0.0, safeThickness, distToEdge);
        float rimIntensity = smoothstep(0.0, 0.5, lighting) * rimMask;
        
        glassRGB += half3(1.0) * half(rimIntensity * 0.6);
        glassAlpha = max(glassAlpha, half(rimIntensity * 0.9));

        float2 shadowDir = normalize(float2(-0.3, -0.8));
        float shadowing = dot(normal, shadowDir);
        float shadowIntensity = smoothstep(0.0, 0.5, shadowing) * rimMask;
        
        glassRGB += half3(-1.0) * half(shadowIntensity * 0.6);
        glassAlpha = max(glassAlpha, half(shadowIntensity * 0.9));
    }

    half4 insideColor = half4(glassRGB + (0.05 * glassAlpha), glassAlpha);

    float pixelSmoothness = 1.0;
    float glassCoverage = 1.0 - smoothstep(-pixelSmoothness, pixelSmoothness, distValue);

    return mix(outsideColor, (insideColor+0.1) * 0.9, half(glassCoverage));
}


[[stitchable]] half4 liquidGlassTabBar(
    float2 position,
    SwiftUI::Layer layer,
    float4 rect,
    float zoomFactor,
    float aberration,
    float rimThickness,
    float strenghten
) {
    float2 glassSize = rect.zw;
    float2 glassCenter = rect.xy + (glassSize * 0.5);
    float2 p = position - glassCenter + 1e-5;
    float nShape = 2.8;

    float distValue = sdfSuperellipse(p, glassSize * 0.5, nShape);
    
    if (distValue > 20.0) { return layer.sample(position); }

    half4 bg = layer.sample(position);
    half4 outsideColor = bg;

    if (distValue > 0.0) {
        float yNorm = p.y / (glassSize.y * 0.4);
        float bottomZone = smoothstep(0.3, 1.5, yNorm);
        float glowFade = exp(-distValue * 0.3);
        float intensity = bottomZone * glowFade * 0.25;
        outsideColor = mix(outsideColor, half4(0.3, 0.3, 0.3, 0.3), half(intensity));
        return outsideColor;
    }

    float distToEdge = -distValue;
    float minDim = min(glassSize.x, glassSize.y);
    float normalizedDist = clamp(1.0 - (distToEdge / (minDim * 0.28)), 0.0, 1.0);

    float distortionCurve = 1.0 - sqrt(1.0 - pow(normalizedDist, 4.0));
    float2 direction = normalize(p);
    
    float xRatio = abs(p.x) / (glassSize.x * 0.5);
    float sideBias = smoothstep(0.2, 2, xRatio);
    float strengthProfile = mix(0, 1.7, sideBias);
    if (strenghten != 1.0) { strengthProfile = 1.0; }
    
    float2 lensOffset = direction * distortionCurve * 50.0 * strengthProfile;
    
    float2 sampleBase;
    if (abs(zoomFactor - 1.0) < 0.001) {
        sampleBase = position;
    } else {
        sampleBase = glassCenter + (p * zoomFactor);
    }
    
    half3 glassRGB;
    half glassAlpha;

    if (aberration < 0.001) {
        float2 sampleCoord = sampleBase - lensOffset;
        half4 s = layer.sample(sampleCoord);
        glassRGB = s.rgb;
        glassAlpha = s.a;
    } else {
        float2 rCoord = sampleBase - (lensOffset * (1.0 + aberration * 0.5));
        half r = layer.sample(rCoord).r;

        float2 bCoord = sampleBase - (lensOffset * (1.0 - aberration * 0.5));
        half b = layer.sample(bCoord).b;

        float2 gCoord = sampleBase - lensOffset;
        half4 sG = layer.sample(gCoord);
        half g = sG.g;

        glassRGB = half3(r, g, b);
        glassAlpha = sG.a;
    }

    float verticalDir = normalize(p).y;
    
    float topArchMask = smoothstep(-0.5, 1.1, -verticalDir);
    float topEdgeFade = exp(-distToEdge * 0.13);
    float shadowFactor = topArchMask * topEdgeFade * 0.0;
    
    glassRGB *= (1.0 - half(shadowFactor));
    glassAlpha = max(glassAlpha, half(shadowFactor * 0.6));

    float bottomCupMask = smoothstep(-0.5, 1.2, verticalDir);
    float bottomEdgeFade = exp(-distToEdge * 0.15);
    half highlightStr = half(bottomCupMask * bottomEdgeFade * 0.00);
    glassRGB += half3(1.0, 1.0, 1.0) * highlightStr * glassAlpha;

    if (rimThickness > 0.01) {
        float safeThickness = rimThickness;
        float2 normal = normalize(p);
        float rimMask = 1.0 - smoothstep(0.0, safeThickness, distToEdge);

        float2 lightDir1 = normalize(float2(0.3, 0.8));
        float lighting1 = dot(normal, lightDir1);
        float rimIntensity1 = smoothstep(0.0, 0.5, lighting1) * rimMask;
        glassRGB += half3(1.0) * half(rimIntensity1 * 0.6);
        glassAlpha = max(glassAlpha, half(rimIntensity1 * 0.9));

        float2 lightDir2 = normalize(float2(-0.3, -0.8));
        float lighting2 = dot(normal, lightDir2);
        float rimIntensity2 = smoothstep(0.0, 0.5, lighting2) * rimMask;
        glassRGB += half3(1.0) * half(rimIntensity2 * 0.6);
        glassAlpha = max(glassAlpha, half(rimIntensity2 * 0.9));
    }

    half4 insideColor = half4(glassRGB + (0.05 * glassAlpha), glassAlpha);
    float pixelSmoothness = 1.0;
    float glassCoverage = 1.0 - smoothstep(-pixelSmoothness, pixelSmoothness, distValue);

    return mix(outsideColor, (insideColor+0.02), half(glassCoverage));
}
