Shader "Custom/SpiderVerse/Dots_Lit_Shadows_URP"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.09, 0.04, 0.07, 1)
        _LitColor ("Lit Color", Color) = (0.29, 0.12, 0.18, 1)
        _DotColor ("Dot Color", Color) = (1.0, 0.19, 0.35, 1)

        _DotScale ("Dot Scale", Float) = 90
        _MinDotRadius ("Min Dot Radius", Range(0.0, 0.5)) = 0.01
        _MaxDotRadius ("Max Dot Radius", Range(0.01, 0.7)) = 0.16
        _DotStrength ("Dot Strength", Range(0, 1)) = 0.75

        _Rotation ("Pattern Rotation", Range(-180, 180)) = -10
        _Ambient ("Ambient", Range(0, 1)) = 0.14
        _ShadowStrength ("Received Shadow Strength", Range(0, 1)) = 0.75
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "SpiderVerseDotsLitShadows"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _LitColor;
                float4 _DotColor;

                float _DotScale;
                float _MinDotRadius;
                float _MaxDotRadius;
                float _DotStrength;

                float _Rotation;
                float _Ambient;
                float _ShadowStrength;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float4 shadowCoords : TEXCOORD3;
            };

            float2 RotateUV(float2 uv, float degrees)
            {
                float radians = degrees * 3.14159265 / 180.0;
                float s = sin(radians);
                float c = cos(radians);

                return float2(
                    uv.x * c - uv.y * s,
                    uv.x * s + uv.y * c
                );
            }

            float CirclePattern(float2 uv, float radius)
            {
                float2 cellUV = frac(uv) - 0.5;
                float distToCenter = length(cellUV);
                return step(distToCenter, radius);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS);

                OUT.positionHCS = posInputs.positionCS;
                OUT.positionWS = posInputs.positionWS;
                OUT.normalWS = normalize(normalInputs.normalWS);
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                OUT.shadowCoords = GetShadowCoord(posInputs);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);

                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);

                float ndotl = saturate(dot(normalWS, lightDir));

                // 1 = fully lit, 0 = fully shadowed
                half shadowAmount = MainLightRealtimeShadow(IN.shadowCoords);

                // Let us control how much the received shadow affects the stylized material
                float shadowControl = lerp(1.0, shadowAmount, _ShadowStrength);

                float lightAmount = saturate((ndotl * shadowControl) + _Ambient);

                float3 baseLighting = lerp(_BaseColor.rgb, _LitColor.rgb, lightAmount);

                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;
                screenUV.x *= _ScreenParams.x / _ScreenParams.y;

                float2 patternUV = RotateUV(screenUV, _Rotation);
                patternUV *= _DotScale;

                float radius = lerp(_MinDotRadius, _MaxDotRadius, ndotl * shadowControl);

                float dots = CirclePattern(patternUV, radius);
                dots *= ndotl;
                dots *= shadowControl;
                dots *= _DotStrength;

                float3 finalColor = lerp(baseLighting, _DotColor.rgb, dots);

                return half4(finalColor, 1);
            }

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            ENDHLSL
        }
    }
}