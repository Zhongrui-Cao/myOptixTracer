#include <optix.h>
#include <optix_device.h>
#include <optixu/optixu_math_namespace.h>
#include "random.h"

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
    size_t2 resultSize = resultBuffer.size();
    unsigned int index = launchIndex.x * resultSize.y + launchIndex.y;
    unsigned int seed = tea<16>(index * frameID.x, 0);

    float3 origin = eye; 

    float3 w = normalize(eye - center);
    float3 u = normalize(cross(up, w));
    float3 v = normalize(cross(w, u));

    float2 tanHFov = make_float2(tan(fovx.x / 2.f), tan(fovy.x / 2.f));
    float2 hSize = optix::make_float2(width.x / 2.f, height.x / 2.f);
    float2 xy = make_float2(launchIndex);
    xy.x += frameID.x == 1 ? 0.5f : rnd(seed);
    xy.y += frameID.x == 1 ? 0.5f : rnd(seed);

    float2 ab = tanHFov * (xy - hSize) / hSize;
    float3 dir = normalize(ab.x * u + ab.y * v - w); // ray direction

    //float alpha = tan(fovx.x / 2.f) * ((((float)launchIndex.x + 0.5) - (width.x / 2.f)) / (width.x / 2.f));
    //float beta = tan(fovy.x / 2.f) * ((((float)launchIndex.y + 0.5) - (height.x / 2.f)) / (height.x / 2.f));
    //float3 dir = normalize(alpha * u + beta * v - w);

    // TODO: modify the following lines if you need
    // Shoot a ray to compute the color of the current pixel
    Payload payload;
    payload.radiance = make_float3(0.f);
    payload.throughput = make_float3(1.0f);
    payload.depth = 0;
    payload.done = false;
    int i = 0;

    do
    {
        payload.seed = tea<16>(index * frameID.x, i++);

        // Trace a ray
        Ray ray = make_Ray(origin, dir, 0, 0.001f, RT_DEFAULT_MAX);
        rtTrace(root, ray, payload);

        // Accumulate radiance
        result += payload.radiance;
        payload.radiance = make_float3(0.f);

        // Prepare to shoot next ray
        origin = payload.origin;
        dir = payload.dir;
    } while (!payload.done && payload.depth != 5);

    if (frameID.x == 1) 
        resultBuffer[launchIndex] = result;
    else
    {
        float u = 1.0f / (float)frameID.x;
        float3 oldResult = resultBuffer[launchIndex];
        resultBuffer[launchIndex] = lerp(oldResult, result, u);
    }
}