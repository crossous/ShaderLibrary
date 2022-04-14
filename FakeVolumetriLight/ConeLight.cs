using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Renderer))]
[ExecuteAlways]
public class ConeLight : MonoBehaviour
{
    [ColorUsage(false, true)]
    public Color lightColor = Color.white;
    [Range(0, 0.499f)]
    public float oriRadius = 0.2f;
    [Range(0, 0.5f)]
    public float destRadius = 0.5f;

    // [Range(0, 90.0f)]
    // public float InnerAngle = 5;
    [Range(0, 1.0f)]
    public float InnerRate = 0.9f;
    
    private Material mat;
    
    void Start()
    {
        Renderer renderer = GetComponent<Renderer>();
        mat = renderer.material;
    }

    // Update is called once per frame
    void Update()
    {
        Vector3 oriPos = transform.localToWorldMatrix.MultiplyPoint(new Vector3(0, -1f, 0));
        Vector3 destPos = transform.localToWorldMatrix.MultiplyPoint(new Vector3(0, 1f, 0));

        float oriR = oriRadius * transform.lossyScale.x;
        float destR = destRadius * transform.lossyScale.x;
        
        float ob = oriR * (oriPos - destPos).magnitude / (destR - oriR);
        Vector3 lightPosWS = oriPos - (destPos - oriPos).normalized * ob;
        
        if (mat != null)
        {
            mat.SetColor("_LightColor", lightColor);
            mat.SetVector("_pa", destPos);
            mat.SetVector("_pb", oriPos);
            mat.SetFloat("_ra", destR);
            mat.SetFloat("_rb", oriR);
            mat.SetFloat("_InnerRate", InnerRate);
        }
    }

    private void OnDrawGizmos()
    {
        Vector3 oriPos = transform.localToWorldMatrix.MultiplyPoint(new Vector3(0, -1f, 0));
        Vector3 destPos = transform.localToWorldMatrix.MultiplyPoint(new Vector3(0, 1f, 0));

        float oriR = oriRadius * transform.lossyScale.x;
        float destR = destRadius * transform.lossyScale.x;
        
        float ob = oriR * (oriPos - destPos).magnitude / (destR - oriR);
        Vector3 lightPosWS = oriPos - (destPos - oriPos).normalized * ob;

        UnityEditor.Handles.DrawWireDisc(destPos, (destPos - oriPos).normalized, destR);

        float coneHigh = (lightPosWS - destPos).magnitude;
        float coneSlope = Mathf.Sqrt(coneHigh * coneHigh + destR * destR);
        
        //圆锥外张角
        // float cosAlpha = coneHigh / coneSlope;
        // float alpha = Mathf.Acos(cosAlpha);
        
        //圆锥内张角
        // float theta = Mathf.Max(0.01f, alpha - Mathf.Deg2Rad * InnerAngle);
        // float tanTheta = Mathf.Tan(theta);
        //
        // float InnerRadius = coneHigh * tanTheta;
        // UnityEditor.Handles.DrawWireDisc(destPos, (destPos - oriPos).normalized, InnerRadius);

    }
}
