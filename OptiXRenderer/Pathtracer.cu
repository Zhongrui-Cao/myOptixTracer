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
        payload.radiance = mv.emission * payload.throughput;
        payload.done = true;
        return;
    }

    float3 r = normalize(reflect(-attrib.wo, attrib.normal));
        
    float xi1 = rnd(payload.seed);
    float xi2 = rnd(payload.seed);

    float theta = acosf(xi1);
    float phi   = 2.0f * M_PIf * xi2;

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