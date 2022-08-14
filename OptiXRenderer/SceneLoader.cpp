#include "SceneLoader.h"

void SceneLoader::rightMultiply(const optix::Matrix4x4& M)
{
    optix::Matrix4x4& T = transStack.top();
    T = T * M;
}

optix::float3 SceneLoader::transformPoint(optix::float3 v)
{
    optix::float4 vh = transStack.top() * optix::make_float4(v, 1);
    return optix::make_float3(vh) / vh.w; 
}

optix::float3 SceneLoader::transformNormal(optix::float3 n)
{
    return optix::make_float3(transStack.top() * make_float4(n, 0));
}

template <class T>
bool SceneLoader::readValues(std::stringstream& s, const int numvals, T* values)
{
    for (int i = 0; i < numvals; i++)
    {
        s >> values[i];
        if (s.fail())
        {
            std::cout << "Failed reading value " << i << " will skip" << std::endl;
            return false;
        }
    }
    return true;
}


std::shared_ptr<Scene> SceneLoader::load(std::string sceneFilename)
{
    // Attempt to open the scene file 
    std::ifstream in(sceneFilename);
    if (!in.is_open())
    {
        // Unable to open the file. Check if the filename is correct.
        throw std::runtime_error("Unable to open scene file " + sceneFilename);
    }

    auto scene = std::make_shared<Scene>();

    transStack.push(optix::Matrix4x4::identity());

    std::string str, cmd;

    // temp vars
    int vertexCount = 0;
    optix::float3 ambient;
    optix::float3 diffuse;
    optix::float3 specular;
    optix::float3 emission;
    int shininess;

    // Read a line in the scene file in each iteration
    while (std::getline(in, str))
    {
        // Ruled out comment and blank lines
        if ((str.find_first_not_of(" \t\r\n") == std::string::npos) 
            || (str[0] == '#'))
        {
            continue;
        }

        // Read a command
        std::stringstream s(str);
        s >> cmd;

        // Some arrays for storing values
        float fvalues[12];
        int ivalues[3];
        std::string svalues[1];

        if (cmd == "size" && readValues(s, 2, fvalues))
        {
            scene->width = (unsigned int)fvalues[0];
            scene->height = (unsigned int)fvalues[1];
        }
        else if (cmd == "output" && readValues(s, 1, svalues))
        {
            scene->outputFilename = svalues[0];
        }
        else if (cmd == "camera" && readValues(s, 10, fvalues))
        {
            scene->eye = optix::make_float3(fvalues[0], fvalues[1], fvalues[2]);
            scene->center = optix::make_float3(fvalues[3], fvalues[4], fvalues[5]);

            optix::float3 uptemp = optix::make_float3(fvalues[6], fvalues[7], fvalues[8]);
            optix::float3 view = scene->eye - scene->center;
            optix::float3 x = optix::cross(uptemp, view);
            optix::float3 y = optix::cross(view, x);
            scene->up = optix::normalize(y);

            scene->fovy = (fvalues[9] * M_PI) / 180.0f;
            scene->fovx = 2.f * atan(((float)scene->width / (float)(scene->height)) * tan(scene->fovy / 2.f));
        }
        else if (cmd == "maxverts" && readValues(s, 1, fvalues))
        {
            scene->vertices = std::vector<optix::float3>(fvalues[0]);
        }
        else if (cmd == "vertex" && readValues(s, 3, fvalues))
        {
            scene->vertices[vertexCount].x = fvalues[0];
            scene->vertices[vertexCount].y = fvalues[1];
            scene->vertices[vertexCount].z = fvalues[2];
            vertexCount++;
        }
        else if (cmd == "tri" && readValues(s, 3, fvalues))
        {
            Triangle triangle;
            optix::Matrix4x4& m = transStack.top();
            triangle.v0 = optix::make_float3(m * optix::make_float4(scene->vertices[fvalues[0]], 1));
            triangle.v1 = optix::make_float3(m * optix::make_float4(scene->vertices[fvalues[1]], 1));
            triangle.v2 = optix::make_float3(m * optix::make_float4(scene->vertices[fvalues[2]], 1));

            triangle.attribute.ambient = ambient;
            triangle.attribute.diffuse = diffuse;
            triangle.attribute.specular = specular;
            triangle.attribute.emission = emission;
            triangle.attribute.shininess = shininess;

            scene->triangles.push_back(triangle);
        }
        else if (cmd == "sphere" && readValues(s, 4, fvalues))
        {
            Sphere sphere;
            optix::Matrix4x4& m = transStack.top();
            sphere.center = optix::make_float3(fvalues[0], fvalues[1], fvalues[2]);
            sphere.radius = fvalues[3];
            sphere.transform = transStack.top();

            sphere.attribute.ambient = ambient;
            sphere.attribute.diffuse = diffuse;
            sphere.attribute.specular = specular;
            sphere.attribute.emission = emission;
            sphere.attribute.shininess = shininess;

            scene->spheres.push_back(sphere);
        }
        else if (cmd == "ambient" && readValues(s, 3, fvalues))
        {
            ambient.x = fvalues[0];
            ambient.y = fvalues[1];
            ambient.z = fvalues[2];
        }
        else if (cmd == "diffuse" && readValues(s, 3, fvalues))
        {
            diffuse.x = fvalues[0];
            diffuse.y = fvalues[1];
            diffuse.z = fvalues[2];
        }
        else if (cmd == "specular" && readValues(s, 3, fvalues))
        {
            specular.x = fvalues[0];
            specular.y = fvalues[1];
            specular.z = fvalues[2];
        }
        else if (cmd == "emission" && readValues(s, 3, fvalues))
        {
            emission.x = fvalues[0];
            emission.y = fvalues[1];
            emission.z = fvalues[2];
        }
        else if (cmd == "shininess" && readValues(s, 1, fvalues))
        {
            shininess = fvalues[0];
        }
        // TODO: use the examples above to handle other commands
    }

    in.close();

    return scene;
}