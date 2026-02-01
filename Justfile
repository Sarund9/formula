

set dotenv-filename := "user.env"





build-shaders:
    # TODO: cwd = shaders
    glslc -o gradient.spv --target-env=vulkan1.3 gradient.comp


