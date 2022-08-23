#pragma once

#include <optixu/optixu_math_namespace.h>

struct Config
{
    unsigned int maxDepth;
    float epsilon;
    int lightSamples;
    bool lightStratify;
    bool nextEventEstimation;
    int frames;

    Config()
    {
        maxDepth = 5;
        epsilon = 0.0001f;
        lightSamples = 9;
        lightStratify = false;
        nextEventEstimation = false;
        frames = 10000;
    }
};