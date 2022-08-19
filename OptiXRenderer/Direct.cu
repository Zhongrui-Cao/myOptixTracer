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
        
        for (int i = 0; i < cf.lightSamples; i++) {
            //for tratified sampling
            int M = sqrt((double)cf.lightSamples);
            int row = i / M;
            int col = i % M;

            float u1 = rnd(payload.seed);
            float u2 = rnd(payload.seed);
            //light sample position
            float3 xprime = ql.a + u1 * ql.ab + u2 * ql.ac;
            if (cf.lightStratify == true) {
                xprime = ql.a + (col + u1) / M * ql.ab + (row + u2) / M * ql.ac;
            }
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
            //rtPrintf("specular term is: %f, %f, %f\n", brdf_specular.x, brdf_specular.y, brdf_specular.z);

            //calc geometry term
            float g1 = clamp(dot(attrib.normal, wi), 0.0f, M_PIf / 2.0f);
            float3 nl = normalize(cross(ql.ab, ql.ac));
            float g2 = clamp(dot(nl, wi), 0.0f, M_PIf / 2.0f);
            float geometryTerm = (g1 * g2) / powf(length(attrib.intersection - xprime), 2.0f);

            //shoot shadow ray
            float lightDist = length(xprime - attrib.intersection);
            ShadowPayload shadowPayload;
            shadowPayload.isVisible = true;
            Ray shadowRay = make_Ray(attrib.intersection + wi * 0.001f,
                wi, 1, 0.001f, lightDist - 0.1f);
            rtTrace(root, shadowRay, shadowPayload);

            float visibility;
            if (shadowPayload.isVisible) {
                visibility = 1.0f;
            }
            else {
                visibility = 0.0f;
            }
            
            sum += brdf * geometryTerm * visibility;
        }

        float A = length(cross(ql.ab, ql.ac));

        result += ql.intensity * (A / cf.lightSamples) * sum;
    }

    // Compute the final radiance
    payload.radiance = result * payload.throughput;

    payload.done = true;

}