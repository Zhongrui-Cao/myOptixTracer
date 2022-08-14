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
    float t;

    // TODO: implement sphere intersection test here
    float3 p0 = make_float3(sphere.transform.inverse() * make_float4(ray.origin, 1) + ray.tmin * make_float4(ray.direction, 0));
    float3 d  = make_float3(normalize(sphere.transform.inverse() * make_float4(ray.direction, 0)));

    float3 oc   = p0 - sphere.center;
    float a     = dot(d, d);
    float halfb = dot(d, oc);
    float b     = 2.0f * halfb;
    float c     = dot(oc, oc) - sphere.radius * sphere.radius;

    float discriminant = b * b - 4 * a * c;

    // roots
    float rootminus = (-b - sqrt(discriminant)) / (2.f * a);
    float rootplus  = (-b + sqrt(discriminant)) / (2.f * a);

    // complex root
    if (discriminant < 0) {
        return;
    }
    else if (discriminant > 0.f) {
        //choose positive one if 2 real roots
        if (((rootminus > 0) && (rootplus < 0)) || ((rootminus < 0) && (rootplus > 0))) {
            t = (rootminus > 0 ? rootminus : rootplus);
        }
        //choose the smaller one if 2 positive roots
        else if (rootminus > 0 && rootplus > 0) {
            t = (rootminus > rootplus ? rootplus : rootminus);
        }
        else {
            return; 
        }
    }
    else {
        // one root
        t = rootminus;
    }

    float3 p = (p0 + d * t);
    //TODO
    float3 intercection = make_float3(sphere.transform * make_float4(p, 1));
    t = length(intercection - ray.origin);

    // Report intersection (material programs will handle the rest)
    if (rtPotentialIntersection(t))
    {
        // Pass attributes
        attrib = sphere.attribute;
        // TODO: assign attribute variables here

        rtReportIntersection(0);
    }
}

RT_PROGRAM void bound(int primIndex, float result[6])
{
    Sphere sphere = spheres[primIndex];

    // TODO: implement sphere bouding box
    result[0] = -1000.f;
    result[1] = -1000.f;
    result[2] = -1000.f;
    result[3] = 1000.f;
    result[4] = 1000.f;
    result[5] = 1000.f;
}