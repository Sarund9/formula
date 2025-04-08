package vulkandevice



import vma "formula:vendor/odin-vma"
import vk "vendor:vulkan"


Allocated_Image :: struct {
    image: vk.Image,
    imageView: vk.ImageView,
    allocation: vma.Allocation,
    imageExtent: vk.Extent3D,
    imageFormat: vk.Format,
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

copy_image_to_image :: proc(
    cmd: vk.CommandBuffer,
    src, dst: vk.Image,
    srcSize, dstSize: vk.Extent2D,
) {
    using blitRegion := vk.ImageBlit2 {
        sType = .IMAGE_BLIT_2,
    }

    srcOffsets[1] = vk.Offset3D {
        i32(srcSize.width), i32(srcSize.height), 1,
    }
    dstOffsets[1] = vk.Offset3D {
        i32(dstSize.width), i32(dstSize.height), 1,
    }

    srcSubresource = vk.ImageSubresourceLayers {
        aspectMask = { .COLOR },
        layerCount = 1,
    }
    dstSubresource = vk.ImageSubresourceLayers {
        aspectMask = { .COLOR },
        layerCount = 1,
    }

    blitInfo := vk.BlitImageInfo2 {
        sType = .BLIT_IMAGE_INFO_2,
        
        srcImage = src,
        srcImageLayout = .TRANSFER_SRC_OPTIMAL,

        dstImage = dst,
        dstImageLayout = .TRANSFER_DST_OPTIMAL,

        filter = .LINEAR,
        regionCount = 1,
        pRegions = &blitRegion,
    }

    vk.CmdBlitImage2(cmd, &blitInfo)
}

