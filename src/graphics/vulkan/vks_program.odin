//#+private
package vulkandevice


import "base:runtime"
import "core:log"
import "core:slice"
import sarr "core:container/small_array"

import "formula:host"
import dev "../device"
import vma "formula:vendor/odin-vma"
import vk "vendor:vulkan"


Program_Vulkan :: struct {
    using __base: dev.Program,

    layout: vk.PipelineLayout,
    descriptorLayouts: sarr.Small_Array(4, vk.DescriptorSetLayout),
    pipeline: vk.Pipeline,
}

_program_api :: proc(api: ^dev.API) {
    using api.program

    create  = program_create
    dispose = program_dispose
}

program_create :: proc(desc: dev.Program_Desc) -> ^dev.Program {
    using this := new(Program_Vulkan)

    // Make the descriptor set layout

    
    // Descriptor Set Layouts
    for desc_bindings, i in desc.bindings {
        // No Binding Here
        if desc_bindings == nil {
            continue
        }

        bindings := make(
            []vk.DescriptorSetLayoutBinding, len(desc_bindings))
        for bind_desc, c in desc_bindings {
            bindings[c] = vk.DescriptorSetLayoutBinding {
                binding = bind_desc.binding,
                descriptorType = binding_type(bind_desc.type),
                descriptorCount = 1,
            }
        }

        info := vk.DescriptorSetLayoutCreateInfo {
            sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,

        }

        current := sarr.len(descriptorLayouts)
        sarr.append(&descriptorLayouts, vk.DescriptorSetLayout {})

        vkcheck(vk.CreateDescriptorSetLayout(
            global.device, &info, global.allocationCallbacks,
            &descriptorLayouts.data[current],
        ))

    }

    // Layout
    layoutInfo := vk.PipelineLayoutCreateInfo {
        sType = .PIPELINE_LAYOUT_CREATE_INFO,
        setLayoutCount = cast(u32) sarr.len(descriptorLayouts),
    }
    if layoutInfo.setLayoutCount > 0 {
        layoutInfo.pSetLayouts = &descriptorLayouts.data[0]
    }

    vkcheck(vk.CreatePipelineLayout(
        global.device, &layoutInfo,
        global.allocationCallbacks, &layout,
    ))

    // Pipeline
    shaderModule := transmute(vk.ShaderModule) desc.shader.module

    stageInfo := vk.PipelineShaderStageCreateInfo {
        sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage  = { stage_to_flags(desc.shader.stage) },
        module = shaderModule,
        pName  = desc.shader.entrypoint,
    }
    
    pipelineInfo := vk.ComputePipelineCreateInfo {
        sType = .COMPUTE_PIPELINE_CREATE_INFO,
        layout = layout,
        stage = stageInfo,
    }

    vkcheck(vk.CreateComputePipelines(
        global.device, 0, 1, &pipelineInfo, nil, &pipeline,
    ))

    return this
}

program_dispose :: proc(ptr: ^dev.Program) {
    using this := transmute(^Program_Vulkan) ptr

}

program_A :: proc(ptr: ^dev.Program) {
    using this := transmute(^Program_Vulkan) ptr

}
