//#+private
package vulkandevice


import "base:runtime"
import "core:log"

import "formula:host"
import dev "../device"
import vma "formula:vendor/odin-vma"
import vk "vendor:vulkan"


Canvas_Vulkan :: struct {
    using __base: dev.Canvas,

    image: Allocated_Image,
    extent: vk.Extent2D,
}

_canvas_api :: proc(api: ^dev.API) {
    using api.canvas
    create = canvas_create
    dispose = canvas_dispose
    // present = canvas_present
}

canvas_create :: proc(desc: dev.Canvas_Desc) -> ^dev.Canvas {
    using this := new(Canvas_Vulkan)
    
    drawImageExent := vk.Extent3D {
        width = desc.width,
        height = desc.height,
        depth = 1,
    }

    // Hardcoding the draw format to 32bit float
    image.imageFormat = .R16G16B16A16_SFLOAT
    image.imageExtent = drawImageExent

    drawImageUsages: vk.ImageUsageFlags
    drawImageUsages += {
        .TRANSFER_DST, .TRANSFER_SRC,
        .TRANSFER_SRC, .TRANSFER_DST,
        .STORAGE, .COLOR_ATTACHMENT,
    }

    imgInfo := image_create_info(
        image.imageFormat, drawImageUsages, drawImageExent,
    )

    imgAllocInfo := vma.AllocationCreateInfo {
        usage = .GPU_ONLY,
        requiredFlags = { .DEVICE_LOCAL },
    }

    // Create the Image
    vkcheck(vma.CreateImage(
        global.allocator, &imgInfo, &imgAllocInfo,
        &image.image, &image.allocation, nil,
    ))

    // Image View
    viewInfo := imageview_create_info(
        image.imageFormat, image.image, { .COLOR },
    )
    vkcheck(vk.CreateImageView(
        global.device, &viewInfo, global.allocationCallbacks,
        &image.imageView,
    ))

    return this
}

canvas_dispose :: proc(ptr: rawptr) {
    using this := transmute(^Canvas_Vulkan) ptr
    using global
    vk.DestroyImageView(device, image.imageView, allocationCallbacks)
    vma.DestroyImage(allocator, image.image, image.allocation)
}

canvas_begin :: proc(ptr: rawptr) {
    using this := transmute(^Canvas_Vulkan) ptr
    using global

    // TODO
    /* Await any swapchain's 
    
    */
}

canvas_end :: proc(ptr: rawptr) {
    using this := transmute(^Canvas_Vulkan) ptr
    using global



}

canvas_present :: proc(
    canvas: ^dev.Canvas,
    window: host.Window,
) {
    if host.window_is_minimized(window) {
        return
    }

    swap, ok := &global.windows[window]
    if !ok do return
    
    this := transmute(^Canvas_Vulkan) canvas
    using global
    
    // Wait for this slot in the swapchain to have Finished.
    frame := &swap.frames[swap.currentFrame]
    vkcheck(vk.WaitForFences(
        device, 1, &frame.renderFinished,
        true, ONE_SECOND,
    ))
    vkcheck(vk.ResetFences(
        device, 1, &frame.renderFinished,
    ))

    if swap.outOfDate {
        swapchain_recreate(swap)
    }

    swapchainImageIndex: u32
    vkcheck(vk.AcquireNextImageKHR(
        device, swap.swapchain, ONE_SECOND, frame.swapSema,
        0, &swapchainImageIndex,
    ))

    cmd := frame.mainCommandBuffer

    vkcheck(vk.ResetCommandBuffer(cmd, {}))

    beginInfo := command_buffer_begin_info({ .ONE_TIME_SUBMIT })
    vkcheck(vk.BeginCommandBuffer(cmd, &beginInfo))

    swapImage := swap.swapchainImages[swapchainImageIndex]

    // transition_image(cmd, swapImage, .UNDEFINED, .GENERAL)
    {

        // clearValue := vk.ClearColorValue {
        //     float32 = { 0.11, 0.12, 0.13, 1.0 },
        // }

        // clearRange := image_subresource_range({ .COLOR })

        // vk.CmdClearColorImage(
        //     cmd, swapImage, .GENERAL,
        //     &clearValue, 1, &clearRange,
        // )
    }

    // transition_image(cmd, this.image.image, .UNDEFINED, .GENERAL)

    transition_image(cmd, this.image.image, .UNDEFINED, .TRANSFER_SRC_OPTIMAL)

    transition_image(cmd, swapImage, .UNDEFINED, .TRANSFER_DST_OPTIMAL)

    canvasExtent := vk.Extent2D {
        width = this.image.imageExtent.width,
        height = this.image.imageExtent.height,
    }
    copy_image_to_image(
        cmd, this.image.image, swapImage,
        canvasExtent, swap.imageExtents,
    )
    transition_image(cmd, swapImage, .TRANSFER_DST_OPTIMAL, .PRESENT_SRC_KHR)

    
    vkcheck(vk.EndCommandBuffer(cmd))

    // SUBMIT
    {
        cmdInfo := command_buffer_submit_info(cmd)

        signalInfo := semaphore_submit_info(frame.presentSema, {
            .ALL_GRAPHICS,
        })
        waitInfo := semaphore_submit_info(frame.swapSema, {
            .COLOR_ATTACHMENT_OUTPUT_KHR,
        })

        submit := submit_info(&cmdInfo, &signalInfo, &waitInfo)

        vkcheck(vk.QueueSubmit2(
            graphicsQueue, 1, &submit, frame.renderFinished
        ))
    }

    // Present
    {
        presentInfo := vk.PresentInfoKHR {
            sType = .PRESENT_INFO_KHR,
            swapchainCount = 1,
            pSwapchains = &swap.swapchain,
            pImageIndices = &swapchainImageIndex,

            waitSemaphoreCount = 1,
            pWaitSemaphores = &frame.presentSema,
        }

        res: vk.Result
        res = (vk.QueuePresentKHR(
            graphicsQueue, &presentInfo,
        ))
        #partial switch res {
        case .SUCCESS:
        case .ERROR_OUT_OF_DATE_KHR, .SUBOPTIMAL_KHR:
            swap.outOfDate = true
        case: vkcheck(res)
        }
    }

    // Increase the Frames
    swap.currentFrame = (swap.currentFrame + 1) %
        swap.swapchainImageCount
    //

    // assert(false)
}
