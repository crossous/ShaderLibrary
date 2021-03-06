Shader "Soco/FakeVolumetriLight"
{
    Properties
    {
		[HDR]_LightColor("LightColor", Color) = (1, 1, 1, 1)
    	_pa("pa", Vector) = (-0.1, -0.1, 0.2, 1)
    	_pb("pb", Vector) = (0.4, 0.3,0.3, 1)
    	_ra("ra", Float) = 0.4
    	_rb("rb", Float) = 0.1
    	_InnerRate("Inner Rate", Range(0, 1)) = 0.9
//    	_Noise("_Noise", 2D) = "white"{}
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 200

        Pass
		{
			Tags { "LightMode"="UniversalForward" }
			
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off
			
			HLSLPROGRAM
			#pragma enable_d3d11_debug_symbols
			#pragma vertex vert
			#pragma fragment frag

			#pragma enable_d3d11_debug_symbols
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			struct Attributes
			{
				float3 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float2 TexC : TEXCOORD;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float3 normalWS : NORMAL;
				//float2 uv : TEXCOORD;
				float3 positionWS : TEXCOORD1;
				float4 projectPosition : TEXCOORD2;
			};

			TEXTURE2D(_CameraDepthTexture);
			SAMPLER(sampler_CameraDepthTexture);

			TEXTURE2D(_CameraOpaqueTexture);
			SAMPLER(sampler_CameraOpaqueTexture);

			//TEXTURE2D(_Noise);
			//SAMPLER(sampler_Noise);

			CBUFFER_START(UnityPerMaterial)
			float3 _LightColor;
			float3 _pa;
			float3 _pb;
			float _ra;
			float _rb;
			float _InnerRate;
			float4 _Noise_ST;
			CBUFFER_END

			Varyings vert(Attributes input)
			{
				Varyings output = (Varyings)0;
				
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
				output.positionCS = vertexInput.positionCS;
				output.positionWS = vertexInput.positionWS;

				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS.xyz);
				output.normalWS = normalInput.normalWS;

				//output.uv = input.TexC;
				output.projectPosition = vertexInput.positionNDC;

				return output;
			}

			float4 GetScreenWorldPos(float2 screenUV, float depth)
			{
	        #if UNITY_REVERSED_Z
	            depth = 1.0 - depth;
				screenUV.y = 1 - screenUV.y;
	        #endif

	            depth = 2.0 * depth - 1.0;

	            float3 viewPos = ComputeViewSpacePosition(screenUV, depth, unity_CameraInvProjection);
	            float4 worldPos = float4(mul(unity_CameraToWorld, float4(viewPos, 1.0)).xyz, 1.0);

				return worldPos;
			}

			float dot2(float a)
			{
				return dot(a, a);
			}

			float inversesqrt(float a)
			{
				return 1 / sqrt(a);
			}

			float diskIntersect( in float3 ro, in float3 rd, float3 c, float3 n, float r )
			{
			    float3  o = ro - c;
			    float t = -dot(n,o)/dot(rd,n);
			    float3  q = o + rd*t;
			    return (dot(q,q)<r*r) ? t : -1.0;
			}
			
			//output (distance, distance2)
			//input (rayOri, rayDirection)
			void coneIntersect(in float3  ro, in float3  rd, in float3  pa, in float3  pb, in float ra, in float rb, out float4 p1, out float4 p2)
			{
				float3  ba = pb - pa;
			    float3  oa = ro - pa;
			    float3  ob = ro - pb;
			    
			    float m0 = dot(ba,ba);
			    float m1 = dot(oa,ba);
			    float m2 = dot(ob,ba); 
			    float m3 = dot(rd,ba);
				
				float3 n = normalize(pa - pb);

				bool hit = false;
				
			    //caps
				// if( m1<0.0 )//a
				// {
					float diskDis = diskIntersect(ro, rd, pa, n, ra);
					if(diskDis > 0)
					{
						p1 = float4(diskDis, n);
						hit = true;
					}
				// }
			 //    else if( m2>0.0 )//b
			 //    {
			    	diskDis = diskIntersect(ro, rd, pb, -n, rb);
					if(diskDis > 0)
					{
						if(hit)
						{
							p2 = float4(diskDis, -n);
							return;
						}
						else
						{
							p1 = float4(diskDis, -n);
							hit = true;
						}
							
					}
			    // }

				//return float4(-1, 0, 0, 0);
			    // body
			    float m4 = dot(rd,oa);
			    float m5 = dot(oa,oa);
			    float rr = ra - rb;
			    float hy = m0 + rr*rr;
			    
			    float k2 = m0*m0    - m3*m3*hy;
			    float k1 = m0*m0*m4 - m1*m3*hy + m0*ra*(rr*m3*1.0        );
			    float k0 = m0*m0*m5 - m1*m1*hy + m0*ra*(rr*m1*2.0 - m0*ra);
			    
			    float h = k1*k1 - k2*k0;
			    if( h<0.0 )
			    {
					if(hit)
						p2 = float4(-1, 0, 0, 0);
					else
						p1 = float4(-1, 0, 0, 0);
			    	return;
			    }

			    float t = (-k1-sqrt(h))/k2;

			    float y = m1 + t*m3;
			    if( y> 0.0 && y < m0 ) 
			    {
			    	if(hit)
			    	{
			    		p2 = float4(t, normalize(m0*(m0*(oa+t*rd)+rr*ba*ra)-ba*hy*y));
			    		return;
			    	}
			        else
			        {
				        p1 = float4(t, normalize(m0*(m0*(oa+t*rd)+rr*ba*ra)-ba*hy*y));
			        	hit = true;
			        }
			    }

				t = (sqrt(h) - k1)/k2;
				y = m1 + t*m3;
				if( y> 0.0 && y < m0 ) 
			    {
			    	if(hit)
			    	{
			    		p2 = float4(t, normalize(m0*(m0*(oa+t*rd)+rr*ba*ra)-ba*hy*y));
			    		return;
			    	}
			        else
			        {
				        p1 = float4(t, normalize(m0*(m0*(oa+t*rd)+rr*ba*ra)-ba*hy*y));
			        	hit = true;
			        }
			    }
			}
			
			float2 sphIntersect( in float3 ro, in float3 rd, in float3 ce, float ra )
			{
			    float3 oc = ro - ce;
			    float b = dot( oc, rd );
			    float c = dot( oc, oc ) - ra*ra;
			    float h = b*b - c;
			    if( h<0.0 ) return float2(-1.0, -1.0); // no intersection
			    h = sqrt( h );
			    return float2( -b-h, -b+h );
			}

			float InScatter(float3 start, float3 rd, float3 lightPos, float d)
			{
			    float3 q = start - lightPos;
			    float b = dot(rd, q);
			    float c = dot(q, q);
			    float iv = 1.0f / sqrt(c - b*b);
			    float l = iv * (atan( (d + b) * iv) - atan( b*iv ));

			    return l;
			}

			//float NoiseAtten(float3 startWS, float3 startToEndWS, float3 lightPosWS, float distance)
			//{
			//	float3 startOS = TransformWorldToObject(startWS);
			//	float3 startToEndOS = normalize(TransformWorldToObjectDir(startToEndWS));
			//	float3 lightPosOS = TransformWorldToObject(lightPosWS);
			//	
			//	float3 marchStep = distance * (1.0 / 11) * startToEndOS;
			//
			//	float3 currentPointOS = startOS;
			//
			//	float total = 0;
			//	for(int i = 0; i < 10; ++i)
			//	{
			//		currentPointOS += marchStep;
			//
			//		float3 buttomOS = float3(0, currentPointOS.y, 0);
			//		float3 discDir = normalize(currentPointOS - buttomOS);
			//		
			//		float buttomRadius = length(currentPointOS - buttomOS);
			//		float height = length(lightPosOS - buttomOS);
			//		float3 topOS = float3(0, -1, 0);
			//		float topHeight = length(lightPosOS - topOS);
			//		float topRadius = topHeight / height * buttomRadius;
			//
			//		//[-oriRadius, oriRadius]
			//		float3 topDiscOS = topOS + discDir * topRadius;
			//		float2 uv = topDiscOS.xz * 0.5 + 0.5;
			//		uv = uv * _Noise_ST.xy +_Noise_ST.zw;
			//
			//		float3 destOS = float3(0, 1, 0);
			//		int lod = (lightPosOS - currentPointOS) / (lightPosOS - destOS) * 10;
			//		
			//		total += SAMPLE_TEXTURE2D_LOD(_Noise, sampler_Noise, uv, lod).r;
			//	}
			//
			//	return total * 0.1;
			//}
			
			float4 frag(Varyings input) : SV_Target
			{
				float2 screenUV = input.projectPosition.xy / input.projectPosition.w;
				
				//float3 backgroundColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV).rgb;

				float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screenUV).r;

				float3 screenWorldPos = GetScreenWorldPos(screenUV, depth).xyz;
				
				float3 rayOri = _WorldSpaceCameraPos;
				float3 rayDir = normalize(screenWorldPos - rayOri);

				float4 marchResult1, marchResult2;
				coneIntersect(rayOri, rayDir, _pa, _pb, _ra, _rb, marchResult1, marchResult2);

				//保证t1是近交点
				if(marchResult1.x > marchResult2.x)
				{
					float4 temp = marchResult1;
					marchResult1 = marchResult2;
					marchResult2 = temp;
				}

				float t1 = marchResult1.x;
				float t2 = marchResult2.x;

				float tScreenPixel = length(screenWorldPos - rayOri);

				if(t2 > tScreenPixel)
				{
					t2 = tScreenPixel;
				}
				
				if(t1 > 0 && t2 > 0 && t1 < tScreenPixel)
				{
					float pointDistance = t2 - t1;
					
					float ob = _rb * length(_pb - _pa) / (_ra - _rb);
					float3 lightPosWS = _pb - normalize(_pa - _pb) * ob;
					
					float3 startPoint = rayOri + t1 * rayDir;
					float3 endPoint = rayOri + t2 * rayDir;
					float inScatter = InScatter(startPoint, rayDir, lightPosWS, pointDistance);

					float coneHigh = length(lightPosWS - _pa);
					float coneSlope = sqrt(coneHigh * coneHigh + _ra * _ra);
					
					float cosAlpha = coneHigh / coneSlope;

					float3 os = startPoint - lightPosWS;
					float3 oe = endPoint - lightPosWS;

					float3 dirOB = normalize(_pb - lightPosWS);
					//视线切平面的法线
					float3 nCut = normalize(cross(os, oe));
					float3 dirOP = normalize(dirOB - dot(nCut, dirOB) * nCut);
					float cosTheta = dot(dirOP, dirOB);
					
					float atten = 1 - saturate((1 - cosTheta) / (1 - cosAlpha) - _InnerRate);
					//float noiseAtten = NoiseAtten(startPoint, rayDir, lightPosWS, pointDistance);
					
					return float4(_LightColor, inScatter * atten);
					// float3 color = lerp(backgroundColor, _LightColor, inScatter * atten);
					// return float4(color, 1);
				}
				
				//return float4(backgroundColor, 1);
				return float4(0, 0, 0, 0);
			}
			
			
			ENDHLSL
			
		}
    }
}