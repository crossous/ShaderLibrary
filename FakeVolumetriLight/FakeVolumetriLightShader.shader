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
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Transparent" }
        LOD 200

        Pass
		{
			Tags { "LightMode"="UniversalForward" }
			
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

			CBUFFER_START(UnityPerMaterial)
			float3 _LightColor;
			float3 _pa;
			float3 _pb;
			float _ra;
			float _rb;
			float _InnerRate;
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
				// //获取像素的屏幕空间位置
				// float3 ScreenPos = float3(ScreenUV , Depth);
				// float4 normalScreenPos = float4(ScreenPos * 2.0 - 1.0 , 1.0);
				// //得到ndc空间下像素位置
				// float4 ndcPos = mul( unity_CameraInvProjection , normalScreenPos );
				// ndcPos = float4(ndcPos.xyz / ndcPos.w , 1.0);
				// //获取世界空间下像素位置
				// float4 sencePos = mul( unity_CameraToWorld , ndcPos * float4(1,1,-1,1));
				// sencePos = float4(sencePos.xyz , 1.0);
				// return sencePos;
				
	        #if UNITY_REVERSED_Z
	            depth = 1.0 - depth;
	        #endif

	            depth = 2.0 * depth - 1.0;
				screenUV.y = 1 - screenUV.y;

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
			
			float4 frag(Varyings input) : SV_Target
			{
				float2 screenUV = input.projectPosition.xy / input.projectPosition.w;
				
				float3 backgroundColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV).rgb;

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
					
					float3 color = lerp(backgroundColor, _LightColor, inScatter * atten);
					return float4(color, 1);
				}
				
				return float4(backgroundColor, 1);
			}
			
			
			ENDHLSL
			
		}
    }
}