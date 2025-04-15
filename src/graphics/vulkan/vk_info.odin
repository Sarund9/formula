//#+private
package vulkandevice




import vma "formula:vendor/odin-vma"
import vk "vendor:vulkan"


fence_create_info :: proc(
    flags: vk.FenceCreateFlags,
) -> vk.FenceCreateInfo {
    return {
        sType = .FENCE_CREATE_INFO,
        flags = flags,
    }
}

semaphore_create_info :: proc(
    flags: vk.SemaphoreCreateFlags,
) -> vk.SemaphoreCreateInfo {
    return {
        sType = .SEMAPHORE_CREATE_INFO,
        flags = flags,
    }
}

command_buffer_begin_info :: proc(
    flags: vk.CommandBufferUsageFlags,
) -> vk.CommandBufferBeginInfo {
    return {
        sType = .COMMAND_BUFFER_BEGIN_INFO,
        flags = flags,
    }
}

semaphore_submit_info :: proc(
    semaphore: vk.Semaphore,
    stageMask: vk.PipelineStageFlags2,
) -> vk.SemaphoreSubmitInfo {
    return {
        sType = .SEMAPHORE_SUBMIT_INFO,
        semaphore = semaphore,
        stageMask = stageMask,
        value = 1,
    }
}

command_buffer_submit_info :: proc(
    cmd: vk.CommandBuffer,
) -> vk.CommandBufferSubmitInfo {
    return {
        sType = .COMMAND_BUFFER_SUBMIT_INFO,
        commandBuffer = cmd,
    }
}

submit_info :: proc(
    cmdSubmitInfo: ^vk.CommandBufferSubmitInfo,
    signalSemaphoreInfo: ^vk.SemaphoreSubmitInfo,
    waitSemaphoreInfo: ^vk.SemaphoreSubmitInfo,
) -> vk.SubmitInfo2 {
    count :: proc(ptr: ^$T) -> u32 {
        return ptr == nil ? 0 : 1
    }
    return {
        sType = .SUBMIT_INFO_2,
        commandBufferInfoCount = 1,
        pCommandBufferInfos = cmdSubmitInfo,

        signalSemaphoreInfoCount = count(signalSemaphoreInfo),
        pSignalSemaphoreInfos = signalSemaphoreInfo,

        waitSemaphoreInfoCount = count(waitSemaphoreInfo),
        pWaitSemaphoreInfos = waitSemaphoreInfo,
    }
}

submit_info_2 :: proc(
    submits: []vk.CommandBufferSubmitInfo,
    signals: []vk.SemaphoreSubmitInfo,
    awaits: []vk.SemaphoreSubmitInfo,
) -> vk.SubmitInfo2 {

    return {
        sType = .SUBMIT_INFO_2,

        commandBufferInfoCount = u32(len(submits)),
        pCommandBufferInfos = &submits[0],
        
        signalSemaphoreInfoCount = u32(len(signals)),
        pSignalSemaphoreInfos = &signals[0],

        waitSemaphoreInfoCount = u32(len(awaits)),
        pWaitSemaphoreInfos = &awaits[0],
    }
}


image_create_info :: proc(
    format: vk.Format, usageFlags: vk.ImageUsageFlags,
    extent: vk.Extent3D,
) -> vk.ImageCreateInfo {
    return vk.ImageCreateInfo {
        sType = .IMAGE_CREATE_INFO,
        imageType = .D2,
        format = format,
        extent = extent,
        mipLevels = 1,
        arrayLayers = 1,
        samples = { ._1 },
        tiling = .OPTIMAL,
        usage = usageFlags,
    }
}

imageview_create_info :: proc(
    format: vk.Format, image: vk.Image,
    aspectFlags: vk.ImageAspectFlags,
) -> vk.ImageViewCreateInfo {
    return vk.ImageViewCreateInfo {
        sType = .IMAGE_VIEW_CREATE_INFO,
        viewType = .D2,
        image = image,
        format = format,
        subresourceRange = {
            levelCount = 1,
            layerCount = 1,
            aspectMask = aspectFlags,
        }
    }
}
