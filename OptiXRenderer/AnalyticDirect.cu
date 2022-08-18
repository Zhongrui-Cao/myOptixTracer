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
    MaterialProperties mv = attrib.phongmat;

    float3 result = mv.emission;

    float3 bdrf = mv.diffuse / 3.14159265358979323846f;

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

        result += bdrf * qlights[i].intensity * dot(Phi, attrib.normal);
    }

    // Calculate the direct illumination of point lights
    for (int i = 0; i < plights.size(); i++)
    {
        // Shoot a shadow to determin whether the object is in shadow
        float3 lightDir = normalize(plights[i].location - attrib.intersection);
        float lightDist = length(plights[i].location - attrib.intersection);
        ShadowPayload shadowPayload;
        shadowPayload.isVisible = true;
        Ray shadowRay = make_Ray(attrib.intersection + lightDir * 0.001f,
            lightDir, 1, 0.001f, lightDist);
        rtTrace(root, shadowRay, shadowPayload);

        // If not in shadow
        if (shadowPayload.isVisible)
        {
            float3 H = normalize(lightDir + attrib.wo);
            float att = dot(plights[i].attenuation, make_float3(1, lightDist, lightDist * lightDist));
            float3 I = mv.diffuse * fmaxf(dot(attrib.normal, lightDir), 0);
            I += mv.specular * pow(fmaxf(dot(attrib.normal, H), 0), mv.shininess);
            I *= plights[i].color / att;
            result += I;
        }
    }

    // Calculate the direct illumination of directional lights
    for (int i = 0; i < dlights.size(); i++)
    {
        // Shoot a shadow to determin whether the object is in shadow
        float3 lightDir = dlights[i].direction;
        float lightDist = RT_DEFAULT_MAX;
        ShadowPayload shadowPayload;
        shadowPayload.isVisible = true;
        Ray shadowRay = make_Ray(attrib.intersection + lightDir * 0.001f,
            lightDir, 1, 0.001f, lightDist);
        rtTrace(root, shadowRay, shadowPayload);

        // If not in shadow
        if (shadowPayload.isVisible)
        {
            float3 H = normalize(lightDir + attrib.wo);
            float3 I = mv.diffuse * fmaxf(dot(attrib.normal, lightDir), 0);
            I += mv.specular * pow(fmaxf(dot(attrib.normal, H), 0), mv.shininess);
            I *= dlights[i].color;
            result += I;
        }
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