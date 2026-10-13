Shader "Ubisworld/URP/River Water"
{
    Properties
    {
        [Header(Water Color)]
        _ShallowColor("Shallow Color", Color) = (0.18, 0.55, 0.48, 0.3)
        _DeepColor("Deep Color", Color) = (0.025, 0.16, 0.19, 0.85)
        _DepthDistance("Depth Color Distance (meters)", Range(0.05, 20)) = 3
        _EdgeFade("Shore Fade Distance (meters)", Range(0.01, 2)) = 0.15
        [Header(Flowing Normals)]
        [Normal] _NormalA("Normal Map A", 2D) = "bump" {}
        [Normal] _NormalB("Normal Map B", 2D) = "bump" {}
        _NormalStrength("Normal Strength", Range(0, 2)) = 0.6
        _FlowA("Flow A (XY direction, Z speed)", Vector) = (1, 0, 0.08, 0)
        _FlowB("Flow B (XY direction, Z speed)", Vector) = (0.8, 0.3, 0.05, 0)
        [Header(Shore Foam)]
        _FoamColor("Foam Color", Color) = (0.85, 0.95, 0.93, 1)
        _FoamWidth("Foam Width (meters)", Range(0.01, 2)) = 0.25
        _FoamAmount("Foam Amount", Range(0, 1)) = 0.45
        [Header(Lighting)]
        _Smoothness("Smoothness", Range(0, 1)) = 0.88
        _ReflectionStrength("Reflection Strength", Range(0, 1)) = 0.65
        _RefractionStrength("Refraction Strength (screen UV)", Range(0, 0.05)) = 0.008
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        Pass
        {
            Name "RiverWater"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Back
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            TEXTURE2D(_NormalA); SAMPLER(sampler_NormalA);
            TEXTURE2D(_NormalB); SAMPLER(sampler_NormalB);
            CBUFFER_START(UnityPerMaterial)
                float4 _NormalA_ST, _NormalB_ST;
                half4 _ShallowColor, _DeepColor, _FoamColor;
                float4 _FlowA, _FlowB;
                float _DepthDistance, _EdgeFade, _FoamWidth, _RefractionStrength;
                half _NormalStrength, _FoamAmount, _Smoothness, _ReflectionStrength;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half4 tangentWS : TEXCOORD2;
                float2 uv : TEXCOORD3;
                half fog : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };
            Varyings Vert(Attributes input)
            {
                Varyings o = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                VertexPositionInputs p = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs n = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.normalWS = n.normalWS;
                o.tangentWS = half4(n.tangentWS, input.tangentOS.w * GetOddNegativeScale());
                o.uv = input.uv;
                o.fog = ComputeFogFactor(p.positionCS.z);
                return o;
            }
            float EyeDepth(float rawDepth)
            {
                // Orthographic and perspective cameras have different depth encodings.
                if (unity_OrthoParams.w > 0.5)
                {
                    #if UNITY_REVERSED_Z
                        rawDepth = 1.0 - rawDepth;
                    #endif
                    return lerp(_ProjectionParams.y, _ProjectionParams.z, rawDepth);
                }
                return LinearEyeDepth(rawDepth, _ZBufferParams);
            }
            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 screenUV = GetNormalizedScreenSpaceUV(input.positionCS);
                float surfaceDepth = -TransformWorldToView(input.positionWS).z;
                float waterDepth = max(0.0, EyeDepth(SampleSceneDepth(screenUV)) - surfaceDepth);
                half depthBlend = 1.0 - exp(-waterDepth / max(_DepthDistance, 0.001));
                half4 water = lerp(_ShallowColor, _DeepColor, depthBlend);

                float2 uvA = input.uv * _NormalA_ST.xy + _NormalA_ST.zw - _FlowA.xy * _FlowA.z * _Time.y;
                float2 uvB = input.uv * _NormalB_ST.xy + _NormalB_ST.zw - _FlowB.xy * _FlowB.z * _Time.y;
                half3 a = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalA, sampler_NormalA, uvA), _NormalStrength);
                half3 b = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalB, sampler_NormalB, uvB), _NormalStrength);
                half3 normalTS = normalize(half3(a.xy + b.xy, max(a.z * b.z, 0.01)));
                half3 baseNormal = normalize(input.normalWS);
                half3 tangent = normalize(input.tangentWS.xyz);
                half3 bitangent = cross(baseNormal, tangent) * input.tangentWS.w;
                half3 normalWS = normalize(mul(normalTS, half3x3(tangent, bitangent, baseNormal)));
                half3 viewWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

                // Reject refraction into foreground geometry at the bank.
                float2 offset = TransformWorldToViewDir(normalWS).xy * _RefractionStrength * saturate(waterDepth);
                float2 refractedUV = saturate(screenUV + offset);
                if (EyeDepth(SampleSceneDepth(refractedUV)) <= surfaceDepth)
                    refractedUV = screenUV;
                half3 background = SampleSceneColor(refractedUV);
                half3 transmission = lerp(background, water.rgb, water.a);

                Light light = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                half3 halfDir = SafeNormalize(light.direction + viewWS);
                half specPower = exp2(3.0 + 8.0 * _Smoothness);
                half3 specular = pow(saturate(dot(normalWS, halfDir)), specPower)
                    * light.color * light.distanceAttenuation * light.shadowAttenuation * _Smoothness;
                half fresnel = 0.02 + 0.98 * pow(1.0 - saturate(dot(normalWS, viewWS)), 5.0);
                half3 reflection = GlossyEnvironmentReflection(reflect(-viewWS, normalWS), 1.0 - _Smoothness, 1.0);
                half3 color = lerp(transmission, reflection, fresnel * _ReflectionStrength) + specular;

                half shore = 1.0 - saturate(waterDepth / max(_FoamWidth, 0.001));
                half foamPattern = smoothstep(0.25, 0.7, saturate(0.5 + (a.x + b.y) * 1.5));
                half foam = shore * foamPattern * _FoamAmount * _FoamColor.a;
                color = lerp(color, _FoamColor.rgb, foam);
                // Scene color is already composited above. Alpha only softens contact edges.
                half alpha = saturate(waterDepth / max(_EdgeFade, 0.001));
                return half4(MixFog(color, input.fog), alpha);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
