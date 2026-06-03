Shader "Custom/SpiderVerse/Dots_URP"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.05, 0.05, 0.05, 1)
        _DotColor ("Dot Color", Color) = (1, 1, 1, 1)
        _DotScale ("Dot Scale", Float) = 80
        _DotRadius ("Dot Radius", Range(0.01, 0.7)) = 0.25
        _Rotation ("Pattern Rotation", Range(-180, 180)) = 0
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
            Name "SpiderVerseDots"

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _DotColor;
                float _DotScale;
                float _DotRadius;
                float _Rotation;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float4 screenPos : TEXCOORD0;
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

                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;

                // Aspect ratio correction so dots stay circular/square-patterned
                screenUV.x *= _ScreenParams.x / _ScreenParams.y;

                // Rotate and tile the screen-space pattern
                float2 patternUV = RotateUV(screenUV, _Rotation);
                patternUV *= _DotScale;

                float dots = CirclePattern(patternUV, _DotRadius);

                float3 finalColor = lerp(_BaseColor.rgb, _DotColor.rgb, dots);

                return half4(finalColor, 1);
            }

            ENDHLSL
        }
    }
}