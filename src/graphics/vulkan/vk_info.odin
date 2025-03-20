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

        waitSemaphoreInfoCount = count(waitSemaphoreInfo),
        pWaitSemaphoreInfos = waitSemaphoreInfo,

        signalSemaphoreInfoCount = count(signalSemaphoreInfo),
        pSignalSemaphoreInfos = signalSemaphoreInfo,
    }
}
