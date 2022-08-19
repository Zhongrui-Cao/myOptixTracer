#pragma once

#include <optixu/optixu_math_namespace.h>
#include <optixu/optixu_matrix_namespace.h>

#include "Geometries.h"
#include "Light.h"
#include "Config.h"

struct Scene
{
    // Info about the output image
    std::string outputFilename;
    unsigned int width, height;

    std::string integratorName;

    std::vector<optix::float3> vertices;

    std::vector<Triangle> triangles;
    std::vector<Sphere> spheres;

    std::vector<DirectionalLight> dlights;
    std::vector<PointLight> plights;
    std::vector<QuadLight> qlights;

    // TODO: add other variables that you need here
    Config config;

    // camera variables
    optix::float3 eye;
    optix::float3 up;
    optix::float3 center;
    float fovy;
    float fovx;

    Scene()
    {
        outputFilename = "raytrace.png";
        integratorName = "raytracer";
    }
};