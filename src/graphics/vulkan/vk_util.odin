//#+private
package vulkandevice


import "base:runtime"

import "core:log"

import vk "vendor:vulkan"


not :: proc(res: vk.Result) -> bool {
    return res != .SUCCESS
}

vkcheck :: proc(res: vk.Result, loc := #caller_location) {
    log.assertf(res == .SUCCESS, "Vulkan Call Failed: {}", res, loc = loc)
}

transition_image :: proc(
    cmd: vk.CommandBuffer, image: vk.Image,
    currentLayout: vk.ImageLayout, newLayout: vk.ImageLayout,
) {
    aspectMask: vk.ImageAspectFlags = newLayout ==
    .DEPTH_ATTACHMENT_OPTIMAL ? { .DEPTH } : { .COLOR }
    //

    imageBarrier := vk.ImageMemoryBarrier2 {
        sType = .IMAGE_MEMORY_BARRIER_2,
        srcStageMask = { .ALL_COMMANDS },
        srcAccessMask = { .MEMORY_WRITE },
        dstStageMask = { .ALL_COMMANDS },
        dstAccessMask = { .MEMORY_WRITE, .MEMORY_READ },

        oldLayout = currentLayout,
        newLayout = newLayout,

        subresourceRange = image_subresource_range(aspectMask),
        image = image,
    }

    depInfo := vk.DependencyInfo {
        sType = .DEPENDENCY_INFO,
        imageMemoryBarrierCount = 1,
        pImageMemoryBarriers = &imageBarrier,
    }

    vk.CmdPipelineBarrier2(cmd, &depInfo)
}

image_subresource_range :: proc(
    aspectMask: vk.ImageAspectFlags,
) -> vk.ImageSubresourceRange {
    return {
        aspectMask = aspectMask,
        levelCount = vk.REMAINING_MIP_LEVELS,
        layerCount = vk.REMAINING_ARRAY_LAYERS,
    }
}
