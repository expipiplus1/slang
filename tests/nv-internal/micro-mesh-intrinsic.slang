// micro-mesh-intrinsic.slang
// This test can only be enabled with a suitable version of DXC so is disabled by default.

//DISABLE_TEST:SIMPLE: -stage closesthit  -target dxil -profile sm_6_5 -entry main -Xdxc -Vd

struct ReflectionRay
{
    float4 color;
};

StructuredBuffer<float4> colors;

void main(
    in out ReflectionRay                     ioPayload,
    BuiltInTriangleIntersectionAttributes     attributes)
{
    uint materialID = InstanceIndex()
        + InstanceID()
        + PrimitiveIndex()
        + HitKind();
        
    float4 color = colors[materialID];

    color *= RayTCurrent() - RayTMin();

    float3x3 objectPositions = HitTriangleObjectPositions();

    float3x2 barycentrics = HitMicroTriangleBarycentrics();
    
    float3x3 microPositions = HitMicroTriangleObjectPositions();

    ioPayload.color = color + objectPositions[0].x + barycentrics[0].x + microPositions[1].y;
}
