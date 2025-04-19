//#+private
package vulkandevice


import "base:runtime"
import "core:log"
import deq "core:container/queue"

import dev "../device"

import vk "vendor:vulkan"




Descriptor_Layout_Builder :: struct {
    bindings: [dynamic]vk.DescriptorSetLayoutBinding,
}

build_descriptor :: proc() -> Descriptor_Layout_Builder {
    b := Descriptor_Layout_Builder {}
    b.bindings = make([dynamic]vk.DescriptorSetLayoutBinding)
    return b
}

add_binding :: proc(
    build: ^Descriptor_Layout_Builder,
    binding: u32, type: vk.DescriptorType,
) {
    newBind := vk.DescriptorSetLayoutBinding {
        binding = binding,
        descriptorCount = 1,
        descriptorType = type,
    }

    append(&build.bindings, newBind)
}

finalize :: proc(
    build: ^Descriptor_Layout_Builder,
    stages: vk.ShaderStageFlags,
    pNext: rawptr = nil,
    flags: vk.DescriptorSetLayoutCreateFlags = {},
) -> vk.DescriptorSetLayout {

    for &bind in build.bindings {
        bind.stageFlags += stages
    }

    info := vk.DescriptorSetLayoutCreateInfo {
        sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        pNext = pNext,
        flags = flags,

        bindingCount = u32(len(build.bindings)),
        pBindings = &build.bindings[0],
    }

    set: vk.DescriptorSetLayout
    vkcheck(vk.CreateDescriptorSetLayout(
        global.device, &info, global.allocationCallbacks,
        &set,
    ))

    return set
}

Descriptor_Allocator :: struct {
    pool: vk.DescriptorPool,
}

Pool_Size_Ratio :: struct {
    type: vk.DescriptorType,
    ratio: f32,
}

init_pool :: proc(
    using alloc: ^Descriptor_Allocator,
    maxSets: u32, poolRatios: []Pool_Size_Ratio,
) {
    poolSizes := make(
        []vk.DescriptorPoolSize,
        len(poolRatios),
        context.temp_allocator)
    
    for ratio, idx in poolRatios {
        poolSizes[idx] = vk.DescriptorPoolSize {
            type = ratio.type,
            descriptorCount = u32(ratio.ratio * f32(maxSets)),
        }
    }

    poolInfo := vk.DescriptorPoolCreateInfo {
        sType = .DESCRIPTOR_POOL_CREATE_INFO,
        maxSets = maxSets,
        poolSizeCount = u32(len(poolSizes)),
        pPoolSizes = &poolSizes[0],
    }

    vkcheck(vk.CreateDescriptorPool(
        global.device, &poolInfo,
        global.allocationCallbacks, &pool,
    ))
}

clear_pool :: proc(using alloc: ^Descriptor_Allocator) {
    vk.ResetDescriptorPool(global.device, pool, {})
}

destroy_pool :: proc(using alloc: ^Descriptor_Allocator) {
    vk.DestroyDescriptorPool(
        global.device, pool, global.allocationCallbacks,
    )
}

allocate_descriptor :: proc(
    using alloc: ^Descriptor_Allocator,
    layout: ^vk.DescriptorSetLayout,
) -> vk.DescriptorSet {
    allocInfo := vk.DescriptorSetAllocateInfo {
        sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
        descriptorPool = pool,
        descriptorSetCount = 1,
        pSetLayouts = layout,
    }

    dset: vk.DescriptorSet
    vkcheck(vk.AllocateDescriptorSets(
        global.device, &allocInfo, &dset,
    ))

    return dset
}

