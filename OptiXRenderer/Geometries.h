#pragma once

#include <optixu/optixu_math_namespace.h>
#include <optixu/optixu_matrix_namespace.h>

/**
 * Structures describing different geometries should be defined here.
 */

struct Attributes
{
    // TODO: define the attributes structure
    optix::float3 ambient;
    optix::float3 diffuse;
    optix::float3 specular;
    optix::float3 emission;
    int shininess;
};

struct Triangle
{
    // TODO: define the triangle structure
    optix::float3 v0, v1, v2;
    Attributes attribute;
};

struct Sphere
{
    // TODO: define the sphere structure
    optix::float3 center;
    float radius;
    optix::Matrix4x4 transform;
    Attributes attribute;
};
