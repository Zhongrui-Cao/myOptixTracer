#include <optix.h>
#include <optix_device.h>
#include <optixu/optixu_math_namespace.h>
#include "random.h"

#include "Payloads.h"
#include "Geometries.h"
#include "Light.h"

using namespace optix;

// Declare light buffers
rtBuffer<PointLight> plights;
rtBuffer<DirectionalLight> dlights;
rtBuffer<QuadLight> qlights;

// Declare variables
rtDeclareVariable(Payload, payload, rtPayload, );
rtDeclareVariable(rtObject, root, , );

// Declare attibutes 
rtDeclareVariable(Attributes, attrib, attribute attrib, );

RT_PROGRAM void closestHit()
{
    float PI_F = 3.1415926535f;
    MaterialProperties mv = attrib.phongmat;

    float3 result = mv.emission;

    float3 brdf = (mv.diffuse / PI_F);

    if (attrib.isQuadLight) {
        payload.radiance = result;
        return;
    }

    for (int i = 0; i < qlights.size(); i++)
    {
        float3 a = qlights[i].a;
        float3 b = qlights[i].a + qlights[i].ab;
        float3 d = b + qlights[i].ac;
        float3 c = a + qlights[i].ac;

        float thetaK = acosf(dot(normalize(a - attrib.intersection), normalize(b - attrib.intersection)));
        float3 gammaK = normalize(cross((a - attrib.intersection), (b - attrib.intersection)));
        float3 tg = thetaK * gammaK;

        float thetaK1 = acosf(dot(normalize(b - attrib.intersection), normalize(d - attrib.intersection)));
        float3 gammaK1 = normalize(cross((b - attrib.intersection), (d - attrib.intersection)));
        float3 tg1 = thetaK1 * gammaK1;

        float thetaK2 = acosf(dot(normalize(d - attrib.intersection), normalize(c - attrib.intersection)));
        float3 gammaK2 = normalize(cross((d - attrib.intersection), (c - attrib.intersection)));
        float3 tg2 = thetaK2 * gammaK2;

        float thetaK3 = acosf(dot(normalize(c - attrib.intersection), normalize(a - attrib.intersection)));
        float3 gammaK3 = normalize(cross((c - attrib.intersection), (a - attrib.intersection)));
        float3 tg3 = thetaK3 * gammaK3;

        float3 Phi = (tg + tg1 + tg2 + tg3) / 2.0f;

        result += brdf * qlights[i].intensity * dot(Phi, attrib.normal);
    }

    // Compute the final radiance
    payload.radiance = result * payload.throughput;

    // Calculate reflection
    if (length(mv.specular) > 0)
    {
        // Set origin and dir for tracing the reflection ray
        payload.origin = attrib.intersection;
        payload.dir = reflect(-attrib.wo, attrib.normal); // mirror reflection

        payload.depth++;
        payload.throughput *= mv.specular;
    }
    else
    {
        payload.done = true;
    }
}