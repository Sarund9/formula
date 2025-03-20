//#+private
package vulkandevice


import "base:runtime"
import "formula:host"

import "core:log"

import vma "formula:vendor/odin-vma"
import vk "vendor:vulkan"


global: Global

Global :: struct {
    instance: vk.Instance,
    allocationCallbacks: ^vk.AllocationCallbacks,

    initContext: runtime.Context,
    debugMessenger: vk.DebugUtilsMessengerEXT,

    // Initialized after a Window has been created.
    physicalDevice: vk.PhysicalDevice,
    device: vk.Device,
    graphicsQueueFamily, presentQueueFamily: u32,
    graphicsQueue, presentQueue: vk.Queue,

    // VMA Allocator
    allocator: vma.Allocator,

    // Per-Window State
    windows: map[host.Window]Window_Canvas,

    // Per-Frame State
    frames: [MAX_FRAMES_IN_FLIGHT]Frame,
    currentFrame: u32,
}

Frame :: struct {
    commandPool: vk.CommandPool,
    mainCommandBuffer: vk.CommandBuffer,

    swapSema, presentSema: vk.Semaphore,
    renderFinished: vk.Fence,


}

begin_frame :: proc() {
    using global
    
    frame := &frames[currentFrame]

    ONE_SECOND :: 1000000000

    // Wait for the frame on current slot to have finished rendering.
    vkcheck(vk.WaitForFences(
        device, 1, &frame.renderFinished, true, ONE_SECOND,
    ))

    // TODO: Multi-Window System ?
    canv: ^Window_Canvas
    {
        for _, &canvas in windows {
            canv = &canvas
            break
        }
        assert(canv != nil, "Window not Initialized!")
    }
    
    // Do not render if the Swapchain is minimized
    if host.window_is_minimized(canv.window) {
        return
    }

    if canv.outOfDate {
        swapchain_recreate(canv)
    }

    vkcheck(vk.AcquireNextImageKHR(
        device, canv.swapchain, ONE_SECOND, frame.swapSema,
        0, &canv.swapchainImageIndex,
    ))

    vkcheck(vk.ResetFences(
        device, 1, &frame.renderFinished
    ))

    cmd := frame.mainCommandBuffer

    vkcheck(vk.ResetCommandBuffer(cmd, {}))

    // Begin Command Recording
    beginInfo := command_buffer_begin_info({ .ONE_TIME_SUBMIT })
    vkcheck(vk.BeginCommandBuffer(cmd, &beginInfo))

}

end_frame :: proc() {
    using global

    frame := &frames[currentFrame]
    canv: ^Window_Canvas
    {
        for _, &canvas in windows {
            canv = &canvas
            break
        }
        assert(canv != nil, "Window not Initialized!")
    }

    if host.window_is_minimized(canv.window) {
        return
    }

    swapImage := canv.swapchainImages[canv.swapchainImageIndex]

    cmd := frame.mainCommandBuffer

    // Make the swapchain writeable to begin Rendering.
    transition_image(cmd, swapImage, .UNDEFINED, .GENERAL)

    // Clearcolor
    clearValue := vk.ClearColorValue {
        float32 = { 0.11, 0.12, 0.13, 1.0 },
    }

    clearRange := image_subresource_range({ .COLOR })

    vk.CmdClearColorImage(
        cmd, swapImage,
        .GENERAL, &clearValue, 1, &clearRange,
    )

    transition_image(cmd, swapImage, .GENERAL, .PRESENT_SRC_KHR)

    vkcheck(vk.EndCommandBuffer(cmd))

    
    // SUBMIT
    submitInfo := command_buffer_submit_info(cmd)
    waitInfo := semaphore_submit_info(frame.swapSema, {
        .COLOR_ATTACHMENT_OUTPUT
    })
    signalInfo := semaphore_submit_info(frame.presentSema, {
        .ALL_GRAPHICS,
    })

    submit := submit_info(&submitInfo, &signalInfo, &waitInfo)

    vkcheck(vk.QueueSubmit2(
        graphicsQueue, 1, &submit, frame.renderFinished,
    ))


    // PRESENT
    
    {
        presentInfo := vk.PresentInfoKHR {
            sType = .PRESENT_INFO_KHR,
            swapchainCount = 1,
            pSwapchains = &canv.swapchain,
    
            waitSemaphoreCount = 1,
            pWaitSemaphores = &frame.presentSema,
    
            pImageIndices = &canv.swapchainImageIndex,
        }
        res: vk.Result
        res = vk.QueuePresentKHR(graphicsQueue, &presentInfo)
        #partial switch res {
        case .ERROR_OUT_OF_DATE_KHR, .SUBOPTIMAL_KHR:
            canv.outOfDate = true
        case: vkcheck(res)
        }
    }

    currentFrame = (currentFrame + 1) % canv.swapchainImageCount
}
