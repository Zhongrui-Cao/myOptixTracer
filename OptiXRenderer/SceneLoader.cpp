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
    MaterialProperties matprop;
    matprop.ambient   = optix::make_float3(0);
    matprop.diffuse   = optix::make_float3(0);
    matprop.specular  = optix::make_float3(0);
    matprop.emission  = optix::make_float3(0);
    matprop.shininess = 1;
    optix::float3 attenuation = optix::make_float3(1, 0, 0);

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
            //scene->vertices = std::vector<optix::float3>(fvalues[0]);
        }
        else if (cmd == "vertex" && readValues(s, 3, fvalues))
        {
            scene->vertices.push_back(
                optix::make_float3(fvalues[0], fvalues[1], fvalues[2]));
        }
        else if (cmd == "tri" && readValues(s, 3, ivalues))
        {
            Triangle triangle;
            optix::Matrix4x4 trans = transStack.top();
            triangle.v0 = transformPoint(scene->vertices[ivalues[0]]);
            triangle.v1 = transformPoint(scene->vertices[ivalues[1]]);
            triangle.v2 = transformPoint(scene->vertices[ivalues[2]]);
            triangle.normal = optix::normalize(optix::cross(triangle.v1 - triangle.v0, triangle.v2 - triangle.v0));

            triangle.phongmat = matprop;
            triangle.isLight = false;

            scene->triangles.push_back(triangle);
        }
        else if (cmd == "sphere" && readValues(s, 4, fvalues))
        {
            Sphere sphere;
            sphere.transform = transStack.top();
            sphere.center = optix::make_float3(fvalues[0], fvalues[1], fvalues[2]);
            sphere.radius = fvalues[3];

            sphere.phongmat = matprop;
            scene->spheres.push_back(sphere);
        }
        else if (cmd == "ambient" && readValues(s, 3, fvalues))
        {
            matprop.ambient.x = fvalues[0];
            matprop.ambient.y = fvalues[1];
            matprop.ambient.z = fvalues[2];
        }
        else if (cmd == "diffuse" && readValues(s, 3, fvalues))
        {
            matprop.diffuse.x = fvalues[0];
            matprop.diffuse.y = fvalues[1];
            matprop.diffuse.z = fvalues[2];
        }
        else if (cmd == "specular" && readValues(s, 3, fvalues))
        {
            matprop.specular.x = fvalues[0];
            matprop.specular.y = fvalues[1];
            matprop.specular.z = fvalues[2];
        }
        else if (cmd == "emission" && readValues(s, 3, fvalues))
        {
            matprop.emission.x = fvalues[0];
            matprop.emission.y = fvalues[1];
            matprop.emission.z = fvalues[2];
        }
        else if (cmd == "shininess" && readValues(s, 1, fvalues))
        {
            matprop.shininess = fvalues[0];
        }
        else if (cmd == "translate" && readValues(s, 3, fvalues))
        { 
            rightMultiply(optix::Matrix4x4::translate(optix::make_float3(fvalues[0], fvalues[1], fvalues[2])));
        }
        else if (cmd == "scale" && readValues(s, 3, fvalues))
        {
            rightMultiply(optix::Matrix4x4::scale(optix::make_float3(fvalues[0], fvalues[1], fvalues[2])));
        }
        else if (cmd == "rotate" && readValues(s, 4, fvalues))
        {
            float radians = fvalues[3] * M_PIf / 180.f;
            optix::float3 axis = normalize(optix::make_float3(fvalues[0], fvalues[1], fvalues[2]));
            optix::Matrix4x4 rot = optix::Matrix4x4::rotate(radians, axis);
            rightMultiply(optix::Matrix4x4(rot));
        }
        else if (cmd == "pushTransform")
        {
            transStack.push(transStack.top());
        }
        else if (cmd == "popTransform") {
            if (transStack.size() <= 1)
            {
                std::cerr << "Stack has no elements. Cannot pop" << std::endl;
            }
            else
            {
                transStack.pop();
            }
        }
        else if (cmd == "directional" && readValues(s, 6, fvalues))
        {
            DirectionalLight dl;
            dl.direction = optix::normalize(optix::make_float3(fvalues[0], fvalues[1], fvalues[2]));
            dl.color     = optix::make_float3(fvalues[3], fvalues[4], fvalues[5]);
            scene->dlights.push_back(dl);
        }
        else if (cmd == "point" && readValues(s, 6, fvalues))
        {
            PointLight pl;
            pl.location = optix::make_float3(fvalues[0], fvalues[1], fvalues[2]);
            pl.color = optix::make_float3(fvalues[3], fvalues[4], fvalues[5]);
            pl.attenuation = attenuation;
            scene->plights.push_back(pl);
        }
        else if (cmd == "attenuation" && readValues(s, 3, fvalues))
        {
            attenuation = optix::make_float3(fvalues[0], fvalues[1], fvalues[2]);
        }
        else if (cmd == "integrator" && readValues(s, 1, svalues))
        {
            scene->integratorName = svalues[0];
        }
        else if (cmd == "quadLight" && readValues(s, 12, fvalues))
        {
            QuadLight ql;
            ql.a = optix::make_float3(fvalues[0], fvalues[1], fvalues[2]);
            ql.ab = optix::make_float3(fvalues[3], fvalues[4], fvalues[5]);
            ql.ac = optix::make_float3(fvalues[6], fvalues[7], fvalues[8]);
            ql.intensity = optix::make_float3(fvalues[9], fvalues[10], fvalues[11]);
            scene->qlights.push_back(ql);

            // create 2 triangle to represent light
            optix::float3 a = ql.a;
            optix::float3 b = ql.a + ql.ab;
            optix::float3 d = b + ql.ac;
            optix::float3 c = a + ql.ac;

            Triangle triangle1;
            triangle1.v0 = a;
            triangle1.v1 = b;
            triangle1.v2 = c;
            triangle1.normal = optix::normalize(optix::cross(triangle1.v1 - triangle1.v0, triangle1.v2 - triangle1.v0));
            triangle1.phongmat.emission = ql.intensity;
            triangle1.isLight = true;

            Triangle triangle2;
            triangle2.v0 = b;
            triangle2.v1 = d;
            triangle2.v2 = c;
            triangle2.normal = optix::normalize(optix::cross(triangle2.v1 - triangle2.v0, triangle2.v2 - triangle2.v0));
            triangle2.phongmat.emission = ql.intensity;
            triangle2.isLight = true;

            scene->triangles.push_back(triangle1);
            scene->triangles.push_back(triangle2);
        }

        // TODO: use the examples above to handle other commands
    }

    in.close();

    return scene;
}