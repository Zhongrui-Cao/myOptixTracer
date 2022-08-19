#pragma once

#include <optixu/optixu_math_namespace.h>

struct Config
{
    unsigned int maxDepth;
    float epsilon;
    int lightSamples;
    bool lightStratify;

    Config()
    {
        maxDepth = 5;
        epsilon = 0.0001f;
        lightSamples = 9;
        lightStratify = false;
    }
};