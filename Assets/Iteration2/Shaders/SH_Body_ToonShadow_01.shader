Shader "Spiderverse/Body_ToonHatch_02"
{
    Properties
    {
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineThickness ("Outline Thickness", Range(0, 0.08)) = 0.015

        _BaseColor ("Base Color", Color) = (0.85, 0.85, 0.82, 1)
        _LightColor ("Lit Color", Color) = (1, 1, 0.95, 1)
        _ShadowColor ("Shadow Color", Color) = (0.25, 0.25, 0.25, 1)

        _HatchTex ("Hatch Texture", 2D) = "white" {}
        _HatchScale ("Hatch Scale", Range(1, 100)) = 35
        _HatchStrength ("Hatch Strength", Range(0, 1)) = 0.65

        _ShadowThreshold ("Shadow Threshold", Range(0, 1)) = 0.55
        _ShadowSoftness ("Shadow Softness", Range(0.001, 0.5)) = 0.03
        _ShadowStrength ("Cast Shadow Strength", Range(0, 1)) = 1.0

        _Ambient ("Ambient", Range(0, 1)) = 0.28
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }

        Pass
        {
            Name "Outline"
            Tags { "LightMode"="SRPDefaultUnlit" }

            Cull Front
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _OutlineColor;
                float _OutlineThickness;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                float3 posOS = input.positionOS.xyz;
                float3 normalOS = normalize(input.normalOS);

                posOS += normalOS * _OutlineThickness;

                output.positionHCS = TransformObjectToHClip(posOS);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                return _OutlineColor;
            }

            ENDHLSL
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_HatchTex);
            SAMPLER(sampler_HatchTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _LightColor;
                float4 _ShadowColor;
                float4 _HatchTex_ST;
                float _HatchScale;
                float _HatchStrength;
                float _ShadowThreshold;
                float _ShadowSoftness;
                float _ShadowStrength;
                float _Ambient;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS  : TEXCOORD0;
                float3 normalWS    : TEXCOORD1;
                float4 shadowCoord : TEXCOORD2;
                float4 screenPos   : TEXCOORD3;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);

                output.positionHCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;
                output.normalWS = normalize(normalInputs.normalWS);
                output.shadowCoord = GetShadowCoord(posInputs);
                output.screenPos = ComputeScreenPos(output.positionHCS);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float3 normalWS = normalize(input.normalWS);

                Light mainLight = GetMainLight(input.shadowCoord);

                float NdotL = saturate(dot(normalWS, mainLight.direction));

                // Toon light band
                float toonLight = smoothstep(
                    _ShadowThreshold - _ShadowSoftness,
                    _ShadowThreshold + _ShadowSoftness,
                    NdotL
                );

                // Real Unity shadow
                float realtimeShadow = mainLight.shadowAttenuation;
                float shadowMix = lerp(1.0, realtimeShadow, _ShadowStrength);

                toonLight *= shadowMix;

                // 0 = lit, 1 = shadow
                float shadowArea = 1.0 - toonLight;

                // Screen-space hatch UV
                float2 screenUV = input.screenPos.xy / input.screenPos.w;
                float aspect = _ScreenParams.x / _ScreenParams.y;
                screenUV.x *= aspect;

                float hatch = SAMPLE_TEXTURE2D(
                    _HatchTex,
                    sampler_HatchTex,
                    screenUV * _HatchScale
                ).r;

                // Make hatch appear earlier inside shadow areas
                float hatchThreshold = saturate(shadowArea * 1.4);
                float hatchMask = step(hatch, hatchThreshold);

                float3 litCol = _BaseColor.rgb * _LightColor.rgb;
                float3 shadowCol = _BaseColor.rgb * _ShadowColor.rgb;

                // Main toon shade
                float3 finalCol = lerp(shadowCol, litCol, toonLight);

                // Ink hatch darkening
                float hatchInk = hatchMask * shadowArea * _HatchStrength;
                finalCol = lerp(finalCol, finalCol * 0.05, hatchInk);

                // Ambient only helps a little, not enough to destroy shadows
                finalCol += _BaseColor.rgb * _Ambient * 0.35;

                return half4(finalCol, _BaseColor.a);
            }

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            ENDHLSL
        }
    }
}