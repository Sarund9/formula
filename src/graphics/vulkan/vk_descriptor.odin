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
        G.device, &info, G.allocationCallbacks,
        &set,
    ))

    return set
}

Descriptor_Allocator :: struct {
    // pool: vk.DescriptorPool,
    ratios: [dynamic]Pool_Size_Ratio,
    fullPools, readyPools: [dynamic]vk.DescriptorPool,
    setsPerPool: u32,
}

Pool_Size_Ratio :: struct {
    type: vk.DescriptorType,
    ratio: f32,
}

@(private="file")
get_pool :: proc(alloc: ^Descriptor_Allocator) -> vk.DescriptorPool {
    if len(alloc.readyPools) > 0 {
        return pop(&alloc.readyPools)
    }
    newPool := create_pool(alloc, alloc.setsPerPool, alloc.ratios[:])

    alloc.setsPerPool = u32(f32(alloc.setsPerPool) * 1.5)
    alloc.setsPerPool = min(alloc.setsPerPool, 4092)

    return newPool
}

@(private="file")
create_pool :: proc(
    alloc: ^Descriptor_Allocator,
    setCount: u32, poolRatios: []Pool_Size_Ratio,
) -> vk.DescriptorPool {
    poolSizes := make(
        []vk.DescriptorPoolSize,
        len(poolRatios), context.temp_allocator,
    )
    for ratio, i in poolRatios {
        poolSizes[i] = vk.DescriptorPoolSize {
            type = ratio.type,
            descriptorCount = u32(ratio.ratio * f32(setCount)),
        }
    }

    poolInfo := vk.DescriptorPoolCreateInfo {
        sType = .DESCRIPTOR_POOL_CREATE_INFO,
        maxSets = setCount,
        poolSizeCount = u32(len(poolSizes)),
        pPoolSizes = &poolSizes[0],
    }

    newPool: vk.DescriptorPool
    vk.CreateDescriptorPool(
        G.device, &poolInfo,
        G.allocationCallbacks,
        &newPool,
    )

    return newPool
}

pool_create :: proc(
    alloc: ^Descriptor_Allocator,
) {
    alloc.ratios = make([dynamic]Pool_Size_Ratio)
    alloc.fullPools = make([dynamic]vk.DescriptorPool)
    alloc.readyPools = make([dynamic]vk.DescriptorPool)
}

pool_destroy :: proc(
    alloc: ^Descriptor_Allocator,
) {
    delete(alloc.ratios)
    delete(alloc.fullPools)
    delete(alloc.readyPools)
}

init_pool :: proc(
    alloc: ^Descriptor_Allocator,
    maxSets: u32, poolRatios: []Pool_Size_Ratio,
) {
    clear(&alloc.ratios)

    for rat in poolRatios {
        append(&alloc.ratios, rat)
    }

    newPool := create_pool(alloc, maxSets, poolRatios)

    alloc.setsPerPool = u32(f32(maxSets) * 1.5)

    append(&alloc.readyPools, newPool)

    // poolSizes := make(
    //     []vk.DescriptorPoolSize,
    //     len(poolRatios),
    //     context.temp_allocator)
    
    // for ratio, idx in poolRatios {
    //     poolSizes[idx] = vk.DescriptorPoolSize {
    //         type = ratio.type,
    //         descriptorCount = u32(ratio.ratio * f32(maxSets)),
    //     }
    // }

    // poolInfo := vk.DescriptorPoolCreateInfo {
    //     sType = .DESCRIPTOR_POOL_CREATE_INFO,
    //     maxSets = maxSets,
    //     poolSizeCount = u32(len(poolSizes)),
    //     pPoolSizes = &poolSizes[0],
    // }

    // vkcheck(vk.CreateDescriptorPool(
    //     global.device, &poolInfo,
    //     global.allocationCallbacks, &pool,
    // ))
}

clear_pools :: proc(alloc: ^Descriptor_Allocator) {

}

// clear_pool :: proc(using alloc: ^Descriptor_Allocator) {
//     vk.ResetDescriptorPool(global.device, pool, {})
// }

// destroy_pool :: proc(using alloc: ^Descriptor_Allocator) {
//     vk.DestroyDescriptorPool(
//         global.device, pool, global.allocationCallbacks,
//     )
// }

// allocate_descriptor :: proc(
//     using alloc: ^Descriptor_Allocator,
//     layout: ^vk.DescriptorSetLayout,
// ) -> vk.DescriptorSet {
//     allocInfo := vk.DescriptorSetAllocateInfo {
//         sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
//         descriptorPool = pool,
//         descriptorSetCount = 1,
//         pSetLayouts = layout,
//     }

//     dset: vk.DescriptorSet
//     vkcheck(vk.AllocateDescriptorSets(
//         global.device, &allocInfo, &dset,
//     ))

//     return dset
// }

