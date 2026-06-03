Shader "Custom/SpiderVerse/Dots_Lit_URP"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.05, 0.05, 0.05, 1)
        _LitColor ("Lit Color", Color) = (1, 1, 1, 1)
        _DotColor ("Dot Color", Color) = (1, 1, 1, 1)

        _DotScale ("Dot Scale", Float) = 80
        _MinDotRadius ("Min Dot Radius", Range(0.0, 0.5)) = 0.03
        _MaxDotRadius ("Max Dot Radius", Range(0.01, 0.7)) = 0.28
        _DotStrength ("Dot Strength", Range(0, 1)) = 1

        _Rotation ("Pattern Rotation", Range(-180, 180)) = 0
        _Ambient ("Ambient", Range(0, 1)) = 0.12
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
            Name "SpiderVerseDotsLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

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

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);

                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);

                float ndotl = saturate(dot(normalWS, lightDir));

                // Base cel-ish lighting for now
                float lightAmount = saturate(ndotl + _Ambient);
                float3 baseLighting = lerp(_BaseColor.rgb, _LitColor.rgb, lightAmount);

                // Screen-space UV
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;

                // Keep pattern square/circular
                screenUV.x *= _ScreenParams.x / _ScreenParams.y;

                // Rotate and tile
                float2 patternUV = RotateUV(screenUV, _Rotation);
                patternUV *= _DotScale;

                // Dot radius grows as the surface faces the light
                float radius = lerp(_MinDotRadius, _MaxDotRadius, ndotl);

                float dots = CirclePattern(patternUV, radius);

                // Dots only strongly appear in lit areas
                dots *= ndotl;
                dots *= _DotStrength;

                float3 finalColor = lerp(baseLighting, _DotColor.rgb, dots);

                return half4(finalColor, 1);
            }

            ENDHLSL
        }
    }
}