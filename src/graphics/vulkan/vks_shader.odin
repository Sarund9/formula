//#+private
package vulkandevice


import "base:runtime"
import "core:log"
import "core:slice"

import "formula:host"
import dev "../device"
import vma "formula:vendor/odin-vma"
import vk "vendor:vulkan"


_shader_api :: proc(api: ^dev.API) {
    api.shader.load = shader_load
    api.shader.unload = shader_unload
}

shader_load :: proc(
    code: []byte,
) -> (dev.Shader_Module, bool) {
    code32 := slice.reinterpret([]u32, code)

    createInfo := vk.ShaderModuleCreateInfo {
        sType = .SHADER_MODULE_CREATE_INFO,
        codeSize = len(code32) * size_of(u32),
        pCode = &code32[0],
    }

    module: vk.ShaderModule

    res := vk.CreateShaderModule(
        G.device, &createInfo,
        G.allocationCallbacks, &module,
    )

    if res == .SUCCESS {
        return dev.Shader_Module(uintptr(module)), true
    }

    log.error("Error loading Shader:", res)
    return nil, false
}

shader_unload :: proc(mod: dev.Shader_Module) {
    modvk := transmute(vk.ShaderModule) mod

    vk.DestroyShaderModule(
        G.device, modvk, G.allocationCallbacks)
}
