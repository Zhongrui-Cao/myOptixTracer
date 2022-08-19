#include <optix.h>
#include <optix_device.h>
#include <optixu/optixu_math_namespace.h>
#include "random.h"

#include "Payloads.h"
#include "Geometries.h"
#include "Light.h"
#include "Config.h"

using namespace optix;

// Declare light buffers
rtBuffer<PointLight> plights;
rtBuffer<DirectionalLight> dlights;
rtBuffer<QuadLight> qlights;

// Config buffer
rtBuffer<Config> config;

// Declare variables
rtDeclareVariable(Payload, payload, rtPayload, );
rtDeclareVariable(rtObject, root, , );

// Declare attibutes 
rtDeclareVariable(Attributes, attrib, attribute attrib, );

RT_PROGRAM void closestHit()
{
    Config cf = config[0];

    MaterialProperties mv = attrib.phongmat;

    float3 result = make_float3(0, 0, 0);

    if (attrib.isQuadLight) {
        payload.radiance = mv.emission;
        return;
    }

    float3 r = normalize(reflect(-attrib.wo, attrib.normal));

    for (int i = 0; i < qlights.size(); i++)
    {
        QuadLight ql = qlights[i];
        float3 sum = make_float3(0, 0, 0);
        // random sampling
        for (int i = 0; i < cf.lightSamples; i++) {
            float u1 = rnd(payload.seed);
            float u2 = rnd(payload.seed);
            float3 xprime = ql.a + u1 * ql.ab + u2 * ql.ac;
            float3 wi = normalize(xprime - attrib.intersection);

            float3 brdf_diffuse = (mv.diffuse / M_PIf);
            float rdotWiPows = powf(clamp(dot(r, wi), 0.0f, M_PIf / 2.0f), mv.shininess);
            float3 brdf_specular = mv.specular * ((mv.shininess + 2) / (2 * M_PIf)) * rdotWiPows;
            float3 brdf = brdf_diffuse + brdf_specular;

            float g1 = clamp(dot(attrib.normal, wi), 0.0f, M_PIf / 2.0f);
            float3 nl = normalize(cross(ql.ab, ql.ac));
            float g2 = clamp(dot(nl, wi), 0.0f, M_PIf / 2.0f);
            float geometryTerm = (g1 * g2) / powf(length(attrib.intersection - xprime), 2.0f);
            
            sum += brdf * geometryTerm * 1;
        }

        float A = length(cross(ql.ab, ql.ac));

        result += ql.intensity * (A / cf.lightSamples) * sum;
    }

    // Compute the final radiance
    payload.radiance = result;

    payload.done = true;

}