Shader "Hidden/SpiderVerse/PostProcess"
{
    Properties
    {
        _PosterizeSteps ("Posterize Steps", Range(2, 16)) = 7
        _PosterizeStrength ("Posterize Strength", Range(0, 1)) = 0.35

        _Contrast ("Contrast", Range(0.5, 2.0)) = 1.15
        _Brightness ("Brightness", Range(-0.25, 0.25)) = 0.0

        _GrainStrength ("Grain Strength", Range(0, 0.25)) = 0.035
        _GrainScale ("Grain Scale", Float) = 220
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
        }

        Pass
        {
            Name "SpiderVersePost"

            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _PosterizeSteps;
                float _PosterizeStrength;
                float _Contrast;
                float _Brightness;
                float _GrainStrength;
                float _GrainScale;
            CBUFFER_END

            float Hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float3 Posterize(float3 color, float steps)
            {
                steps = max(steps, 1.0);
                return floor(color * steps) / steps;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;

                float4 col = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);
                float3 color = col.rgb;

                // Contrast around mid-grey
                color = (color - 0.5) * _Contrast + 0.5;
                color += _Brightness;

                // Posterized print colour
                float3 posterized = Posterize(color, _PosterizeSteps);
                color = lerp(color, posterized, _PosterizeStrength);

                // Tiny print grain
                float grain = Hash21(floor(uv * _ScreenParams.xy / _GrainScale) + _Time.y);
                grain = grain * 2.0 - 1.0;
                color += grain * _GrainStrength;

                color = saturate(color);

                return half4(color, col.a);
            }

            ENDHLSL
        }
    }
}