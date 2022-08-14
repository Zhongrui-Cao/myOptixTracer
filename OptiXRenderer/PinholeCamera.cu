#include <optix.h>
#include <optix_device.h>
#include <optixu/optixu_math_namespace.h>

#include "Payloads.h"

using namespace optix;

rtBuffer<float3, 2> resultBuffer; // used to store the render result

rtDeclareVariable(rtObject, root, , ); // Optix graph

rtDeclareVariable(uint2, launchIndex, rtLaunchIndex, ); // a 2d index (x, y)

rtDeclareVariable(int1, frameID, , );

// Camera info 

// TODO:: delcare camera varaibles here
rtDeclareVariable(float3, eye, , );
rtDeclareVariable(float3, up, , );
rtDeclareVariable(float3, center, , );
rtDeclareVariable(float1, fovx, , );
rtDeclareVariable(float1, fovy, , );
rtDeclareVariable(float1, width, , );
rtDeclareVariable(float1, height, , );

RT_PROGRAM void generateRays()
{
    float3 result = make_float3(0.f);

    float3 origin = eye; 
    
    float epsilon = 0.001f; 

    float3 w = normalize(eye - center);
    float3 u = normalize(cross(up, w));
    float3 v = cross(w, u);

    float alpha = tan(fovx.x / 2.f) * ((((float)launchIndex.x + 0.5) - (width.x / 2.f)) / (width.x / 2.f));
    float beta = tan(fovy.x / 2.f) * ((((float)launchIndex.y + 0.5) - (height.x / 2.f)) / (height.x / 2.f));
    float3 dir = normalize(alpha * u + beta * v - w);

    // TODO: modify the following lines if you need
    // Shoot a ray to compute the color of the current pixel
    Ray ray = make_Ray(origin, dir, 0, epsilon, RT_DEFAULT_MAX);
    Payload payload;
    rtTrace(root, ray, payload);

    // Write the result
    resultBuffer[launchIndex] = payload.radiance;
}