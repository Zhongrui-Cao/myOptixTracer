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
        if (!cf.nextEventEstimation || payload.depth == 0) {
            payload.radiance += mv.emission * payload.throughput;
            payload.done = true;
            return;
        }
        payload.done = true;
        return;
    }

    float3 r = normalize(reflect(-attrib.wo, attrib.normal));
    // direct lighting
    for (int i = 0; i < qlights.size(); i++)
    {
        QuadLight ql = qlights[i];
        float3 sum = make_float3(0, 0, 0);

        float u1 = rnd(payload.seed);
        float u2 = rnd(payload.seed);
        //light sample position
        float3 xprime = ql.a + u1 * ql.ab + u2 * ql.ac;

        //light sample direction
        float3 wi = normalize(xprime - attrib.intersection);

        //calc brdf
        float3 brdf_diffuse = (mv.diffuse / M_PIf);
        float rdotWiPows = powf(clamp(dot(r, wi), 0.0f, M_PIf / 2.0f), mv.shininess);
        float3 brdf_specular = make_float3(0, 0, 0);
        if (length(mv.specular) > 0) {
            brdf_specular = mv.specular * ((mv.shininess + 2) / (2 * M_PIf)) * rdotWiPows;
        }
        float3 brdf = brdf_diffuse + brdf_specular;

        //calc geometry term
        float g1 = clamp(dot(attrib.normal, wi), 0.0f, M_PIf / 2.0f);
        float3 nl = normalize(cross(ql.ab, ql.ac));
        float g2 = clamp(dot(nl, wi), 0.0f, M_PIf / 2.0f);
        float geometryTerm = (g1 * g2) / powf(length(attrib.intersection - xprime), 2.0f);

        //shoot shadow ray
        float lightDist = length(xprime - attrib.intersection);
        ShadowPayload shadowPayload;
        shadowPayload.isVisible = true;
        // lightDist - 0.01f to not let the trangles shadow the entire light
        Ray shadowRay = make_Ray(attrib.intersection + wi * 0.001f,
            wi, 1, 0.001f, lightDist - 0.01f);
        rtTrace(root, shadowRay, shadowPayload);

        float visibility;
        if (shadowPayload.isVisible) {
            visibility = 1.0f;
        }
        else {
            visibility = 0.0f;
        }

        sum = brdf * geometryTerm * visibility;

        float A = length(cross(ql.ab, ql.ac));

        result += ql.intensity * A * sum;
    }

    if (cf.nextEventEstimation) {
        payload.radiance += result * payload.throughput;
        if (payload.depth >= cf.maxDepth - 1 && !cf.russianRoulette) {
            payload.done = true;
            return;
        }
    }

    // russian roulette
    if (cf.russianRoulette) {
        // load gun
        float q = 1.0f - fminf(fmaxf(fmaxf(payload.throughput.x, payload.throughput.y), payload.throughput.z), 1.0f);
        // spin wheel
        //unsigned int world = tea<16>(rnd(payload.seed), rnd(payload.seed));
        float spin = rnd(payload.seed);
        // pull trigger
        if (spin < q) {
            // get killed, no indirect ray shot
            payload.done = true;
            return;
        }
        else {
            // alive with boosted throughput
            payload.throughput *= 1.0f / (1.0f - q);
        }
    }

    // indirect lighting
    float xi1 = rnd(payload.seed);
    float xi2 = rnd(payload.seed);

    float theta = acosf(xi1);
    float phi = 2.0f * M_PIf * xi2;

    float3 s = make_float3(cosf(phi) * sinf(theta), sinf(phi) * sinf(theta), cosf(theta));

    float3 w = normalize(attrib.normal);
    float3 up = make_float3(0, 1, 0);
    //float3 a = length(normalize(w - up)) < 0.1f ? make_float3(1, 0, 0) : up;
    //TODO if a close to w what to do
    float3 a = make_float3(1, 2, 3);
    float3 u = normalize(cross(a, w));
    float3 v = normalize(cross(w, u));
    float3 wi = s.x * u + s.y * v + s.z * w;

    //calc brdf
    float3 brdf_diffuse = (mv.diffuse / M_PIf);
    float rdotWiPows = powf(clamp(dot(r, wi), 0.0f, M_PIf / 2.0f), mv.shininess);
    float3 brdf_specular = make_float3(0, 0, 0);
    if (length(mv.specular) > 0) {
        brdf_specular = mv.specular * ((mv.shininess + 2) / (2 * M_PIf)) * rdotWiPows;
    }
    float3 brdf = brdf_diffuse + brdf_specular;
    
    // Set origin and dir for tracing the reflection ray
    payload.origin = attrib.intersection;
    payload.dir = wi; // random reflection
    payload.depth++;
    payload.throughput *= 2.0f * M_PIf * brdf * dot(attrib.normal, wi);

}