#include "optix.h"
#include "optix_device.h"
#include "Geometries.h"

using namespace optix;

rtBuffer<Triangle> triangles; // a buffer of all spheres

rtDeclareVariable(Ray, ray, rtCurrentRay, );

// Attributes to be passed to material programs 
rtDeclareVariable(Attributes, attrib, attribute attrib, );

RT_PROGRAM void intersect(int primIndex)
{
    // Find the intersection of the current ray and triangle
    Triangle tri = triangles[primIndex];
    float t;

    // TODO: implement triangle intersection test here
    float3 normal = normalize(cross((tri.v1 - tri.v0), (tri.v2 - tri.v0)));
    float normray = dot(ray.direction, normal);

    //check if parallel
    if (fabs(normray) < ray.tmin)
        return;

    float An = dot(tri.v0, normal);
    float P0n = dot(ray.origin, normal);

    // intersect distance
    t = (An - P0n) / normray;
    // intersect point
    float3 p = ray.origin + t * ray.direction;

    // test if inside triangle using lamda
    float lamda0;
    float3 edge0 = tri.v1 - tri.v0;
    float3 vp0 = p - tri.v0;
    lamda0 = dot(normal, cross(edge0, vp0));

    float3 edge1 = tri.v2 - tri.v1;
    float3 vp1 = p - tri.v1;
    float lamda1 = dot(normal, cross(edge1, vp1));

    float3 edge2 = tri.v0 - tri.v2;
    float3 vp2 = p - tri.v2;
    float lamda2 = dot(normal, cross(edge2, vp2));

    if (lamda0 < 0 || lamda1 < 0 || lamda2 < 0)
        return;

    // Report intersection (material programs will handle the rest)
    if (rtPotentialIntersection(t))
    {
        // Pass attributes
        attrib.phongmat = tri.phongmat;
        attrib.intersection = p;
        attrib.wo = -ray.direction;
        attrib.normal = dot(tri.normal, -ray.direction) > 0 ? tri.normal : -tri.normal;
        attrib.isQuadLight = tri.isLight;

        rtReportIntersection(0);
    }
}

RT_PROGRAM void bound(int primIndex, float result[6])
{
    Triangle tri = triangles[primIndex];

    // TODO: implement triangle bouding box
    result[0] = fminf(fminf(tri.v0.x, tri.v1.x), tri.v2.x);
    result[1] = fminf(fminf(tri.v0.y, tri.v1.y), tri.v2.y);
    result[2] = fminf(fminf(tri.v0.z, tri.v1.z), tri.v2.z);
    result[3] = fmaxf(fmaxf(tri.v0.x, tri.v1.x), tri.v2.x);
    result[4] = fmaxf(fmaxf(tri.v0.y, tri.v1.y), tri.v2.y);
    result[5] = fmaxf(fmaxf(tri.v0.z, tri.v1.z), tri.v2.z);
}