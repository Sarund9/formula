//#+private
package vulkandevice


import "base:runtime"
import "core:log"
import "core:slice"

import "formula:host"
import dev "../device"
import vma "formula:vendor/odin-vma"
import vk "vendor:vulkan"


Canvas_Vulkan :: struct {
    using __base: dev.Canvas,

    image: Allocated_Image,
    extent: vk.Extent2D,
    
    // Fences of swapchain frames we are presenting to.
    // Awaiting is only required when drawing (Write) to the Canvas, not presenting (Read) it.
    presenting: [dynamic]vk.Fence,

    commandPool: vk.CommandPool,
    cmd: vk.CommandBuffer,

    // Self Sync Structures
    // Signaled by Submit
    renderFence: vk.Fence, // Signaled when drawing to this Finishes.
    renderSema: vk.Semaphore,
    rendering: bool, // True if ops where submited to renderSema
}

Canvas_Frame :: struct {

}

_canvas_api :: proc(api: ^dev.API) {
    using api.canvas
    create = canvas_create
    dispose = canvas_dispose
    // present = canvas_present
}

canvas_create :: proc(desc: dev.Canvas_Desc) -> ^dev.Canvas {
    using this := new(Canvas_Vulkan)
    
    presenting = make([dynamic]vk.Fence)

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

    // Command Buffer
    {
        poolInfo := vk.CommandPoolCreateInfo {
            sType = .COMMAND_POOL_CREATE_INFO,
            flags = { .RESET_COMMAND_BUFFER },
            queueFamilyIndex = global.graphicsQueueFamily,
        }

        vkcheck(vk.CreateCommandPool(
            global.device, &poolInfo, global.allocationCallbacks, &commandPool,
        ))

        cmdAllocInfo := vk.CommandBufferAllocateInfo {
            sType = .COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool = commandPool,
            commandBufferCount = 1,
            level = .PRIMARY,
        }

        vkcheck(vk.AllocateCommandBuffers(
            global.device, &cmdAllocInfo, &cmd,
        ))
    }

    // Sync Structures
    {
        fenceInfo := fence_create_info({ })
        semaInfo := semaphore_create_info({})

        ld := global.device
        alck := global.allocationCallbacks

        vkcheck(vk.CreateFence(ld, &fenceInfo, alck, &renderFence))

        vkcheck(vk.CreateSemaphore(ld, &semaInfo, alck, &renderSema))
    }

    return this
}

canvas_dispose :: proc(ptr: rawptr) {
    using this := transmute(^Canvas_Vulkan) ptr
    using global
    canvas_await(this) // Wait
    delete(presenting)
    vk.DestroyCommandPool(device, commandPool, allocationCallbacks)
    vk.DestroyFence(device, renderFence, allocationCallbacks)
    vk.DestroySemaphore(device, renderSema, allocationCallbacks)
    vk.DestroyImageView(device, image.imageView, allocationCallbacks)
    vma.DestroyImage(allocator, image.image, image.allocation)
}

@(private="file")
canvas_await :: proc(using this: ^Canvas_Vulkan) {
    if len(presenting) == 0 do return
    
    device := global.device

    vkcheck(vk.WaitForFences(
        device, u32(len(presenting)), &presenting[0],
        true, ONE_SECOND,
    ))
    clear(&presenting)

    // If we were drawing to this, we must Reset the fence.
    if rendering {
        vkcheck(vk.ResetFences(
            device, 1, &renderFence,
        ))

        rendering = false // 
    }

}

canvas_begin :: proc(ptr: ^dev.Canvas, pass: dev.Pass) {
    using this := transmute(^Canvas_Vulkan) ptr
    using global

    // Await all currently presenting Swapchains
    // And rendering operations
    canvas_await(this)

    // Begin CMD Buffer.
    vkcheck(vk.ResetCommandBuffer(cmd, {}))

    beginInfo := command_buffer_begin_info({ .ONE_TIME_SUBMIT })
    vkcheck(vk.BeginCommandBuffer(cmd, &beginInfo))

    // TODO: CmdClear for Testing
    transition_image_2(cmd, &this.image, .GENERAL)

    clearValue := vk.ClearColorValue {
        float32 = {
            0.2, 0.5, 0.6, 1.0,
        }
    }

    clearRange := image_subresource_range({ .COLOR })

    vk.CmdClearColorImage(
        cmd, this.image.image, .GENERAL, 
        &clearValue, 1, &clearRange,
    )

    // log.info("Hello")
}

canvas_end :: proc(ptr: ^dev.Canvas, pass: dev.Pass) {
    using this := transmute(^Canvas_Vulkan) ptr
    using global

    vkcheck(vk.EndCommandBuffer(cmd))

    // SUBMIT
    
    cmdInfo := command_buffer_submit_info(cmd)

    signalInfo := semaphore_submit_info(renderSema, {
        .ALL_GRAPHICS,
    })
    // waitInfo := semaphore_submit_info(frame.swapSema, {
    //     .COLOR_ATTACHMENT_OUTPUT_KHR,
    // })

    // Will signal the Canvas sync structures when the Commands Finish
    submit := submit_info(&cmdInfo, &signalInfo, nil)

    vkcheck(vk.QueueSubmit2(
        graphicsQueue, 1, &submit, renderFence
    ))

    rendering = true

    // Canvas will need to wait before using this
    if idx, ok := slice.linear_search(this.presenting[:], renderFence); !ok {
        append(&this.presenting, renderFence)
    }
    
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

    transition_image_2(cmd, &this.image, .TRANSFER_SRC_OPTIMAL)

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

    // log.info("Copy Image")

    
    vkcheck(vk.EndCommandBuffer(cmd))

    // SUBMIT
    {
        cmdInfo := command_buffer_submit_info(cmd)

        signalInfo := semaphore_submit_info(frame.presentSema, {
            .ALL_GRAPHICS,
        })

        waitAquireImage := semaphore_submit_info(frame.swapSema, {
            .COLOR_ATTACHMENT_OUTPUT_KHR,
        })
        waitCanvasDrawing := semaphore_submit_info(this.renderSema, {
            .COLOR_ATTACHMENT_OUTPUT_KHR,
        })

        waits: [2]vk.SemaphoreSubmitInfo
        waits[0] = waitAquireImage
        waits[1] = waitCanvasDrawing

        submit := submit_info_2(
            {cmdInfo}, {signalInfo},
            waits[:this.rendering ? 2 : 1], // Wait for canvas only if drawn
        )

        vkcheck(vk.QueueSubmit2(
            graphicsQueue, 1, &submit, frame.renderFinished
        ))

        // Canvas will need to wait before using this
        if idx, ok := slice.linear_search(this.presenting[:], frame.renderFinished); !ok {
            append(&this.presenting, frame.renderFinished)
        }
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
