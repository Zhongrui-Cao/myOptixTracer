#include <optix.h>
#include <optix_device.h>
#include "Geometries.h"

using namespace optix;

rtBuffer<Sphere> spheres; // a buffer of all spheres

rtDeclareVariable(Ray, ray, rtCurrentRay, );

// Attributes to be passed to material programs 
rtDeclareVariable(Attributes, attrib, attribute attrib, );

RT_PROGRAM void intersect(int primIndex)
{
    // Find the intersection of the current ray and sphere
    Sphere sphere = spheres[primIndex];
    Matrix4x4 itrans = sphere.transform.inverse();
    float4 rayOriH = itrans * make_float4(ray.origin, 1);
    float3 rayOri = make_float3(rayOriH) / rayOriH.w;
    float3 rayDir = normalize(make_float3(itrans * make_float4(ray.direction, 0)));

    float t = 0;
    float3 CP0 = rayOri;
    float P1dotCP0 = dot(rayDir, CP0);
    float CP0dotCP0 = dot(CP0, CP0);
    float r2 = 1.f;
    float disc = P1dotCP0 * P1dotCP0 - CP0dotCP0 + r2;
    if (disc < 0) return;
    if (disc == 0)
        t = -P1dotCP0;
    else if (CP0dotCP0 > r2)
        t = -P1dotCP0 - sqrt(disc);
    else
        t = -P1dotCP0 + sqrt(disc);

    if (t < 0.01f) return;

    // Intersection is found
    float3 P = rayOri + t * rayDir; // intersection in the object space
    float4 intersectionH = sphere.transform * make_float4(P, 1);
    P = make_float3(intersectionH) / intersectionH.w; // intersection in the world space
    t = length(P - ray.origin); // distance

    // Report intersection (material programs will handle the rest)
    if (rtPotentialIntersection(t))
    {
        // Pass attributes
        attrib.phongmat = sphere.phongmat;
        attrib.intersection = P;
        attrib.wo = -ray.direction;
        float4 tintersection = sphere.transform.inverse() * make_float4(attrib.intersection, 1);
        attrib.normal = normalize(make_float3(tintersection) / tintersection.w);
        attrib.normal = normalize(make_float3(sphere.transform.inverse().transpose() * make_float4(attrib.normal, 0)));
        attrib.isQuadLight = false;

        rtReportIntersection(0);
    }
}

RT_PROGRAM void bound(int primIndex, float result[6])
{
    Sphere sphere = spheres[primIndex];

    // TODO: implement sphere bouding box
    float x, y, z;
    x = length(make_float3(sphere.transform.getRow(0)));
    y = length(make_float3(sphere.transform.getRow(1)));
    z = length(make_float3(sphere.transform.getRow(2)));
    result[0] = sphere.transform[3] - x;
    result[1] = sphere.transform[7] - y;
    result[2] = sphere.transform[11] - z;
    result[3] = sphere.transform[3] + x;
    result[4] = sphere.transform[7] + y;
    result[5] = sphere.transform[11] + z;
}