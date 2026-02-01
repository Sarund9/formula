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
    lock: [dynamic]vk.Fence,

    commandPool: vk.CommandPool,
    cmd: vk.CommandBuffer,

    // Self Sync Structures
    // Signaled by Submit
    renderFence: vk.Fence, // Signaled when drawing to this Finishes.
    renderSema: vk.Semaphore,
    // 1: True if ops where submited to renderSema
    // 2: True if canvas has NOT been presented to a Swapchain
    rendering, rendered: bool,

    // State: currently active command ?
    commandState: struct {
        active: bool,

        bound: union {
            ^Program_Vulkan,
            // Brush ..
        },
        bind_writers: [4]Bind_Writer,
    },
}

_canvas_api :: proc(api: ^dev.API) {
    api.canvas.create  = canvas_create
    api.canvas.dispose = canvas_dispose

    api.canvas.begin = canvas_begin
    api.canvas.end   = canvas_end

    // bind = canvas_bind

    // Command API
    _canvas_cmd_api()
}

canvas_create :: proc(desc: dev.Canvas_Desc) -> ^dev.Canvas {
    using this := new(Canvas_Vulkan)
    
    lock = make([dynamic]vk.Fence)

    size = { desc.width, desc.height }

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
        G.allocator, &imgInfo, &imgAllocInfo,
        &image.image, &image.allocation, nil,
    ))

    // Image View
    viewInfo := imageview_create_info(
        image.imageFormat, image.image, { .COLOR },
    )
    vkcheck(vk.CreateImageView(
        G.device, &viewInfo, G.allocationCallbacks,
        &image.imageView,
    ))

    // Command Buffer
    {
        poolInfo := vk.CommandPoolCreateInfo {
            sType = .COMMAND_POOL_CREATE_INFO,
            flags = { .RESET_COMMAND_BUFFER },
            queueFamilyIndex = G.graphicsQueueFamily,
        }

        vkcheck(vk.CreateCommandPool(
            G.device, &poolInfo, G.allocationCallbacks, &commandPool,
        ))

        cmdAllocInfo := vk.CommandBufferAllocateInfo {
            sType = .COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool = commandPool,
            commandBufferCount = 1,
            level = .PRIMARY,
        }

        vkcheck(vk.AllocateCommandBuffers(
            G.device, &cmdAllocInfo, &cmd,
        ))
    }

    // Sync Structures
    {
        fenceInfo := fence_create_info({ })
        semaInfo := semaphore_create_info({})

        ld := G.device
        alck := G.allocationCallbacks

        vkcheck(vk.CreateFence(ld, &fenceInfo, alck, &renderFence))

        vkcheck(vk.CreateSemaphore(ld, &semaInfo, alck, &renderSema))
    }

    return this
}

canvas_dispose :: proc(ptr: ^dev.Canvas) {

    qcollect(ptr, proc(ptr: rawptr) {
        using this := transmute(^Canvas_Vulkan) ptr
        
        canvas_await(this) // Wait
        delete(lock)

        // TODO: Remove Fences from Resources locked by this Canvas ?

        vk.DestroyCommandPool(G.device, commandPool, G.allocationCallbacks)
        vk.DestroyFence(G.device, renderFence, G.allocationCallbacks)
        vk.DestroySemaphore(G.device, renderSema, G.allocationCallbacks)
        vk.DestroyImageView(G.device, image.imageView, G.allocationCallbacks)
        vma.DestroyImage(G.allocator, image.image, image.allocation)
    })
}

@(private="file")
canvas_await :: proc(canv: ^Canvas_Vulkan) {
    if len(canv.lock) == 0 do return
    
    device := G.device

    vkcheck(vk.WaitForFences(
        device, u32(len(canv.lock)), &canv.lock[0],
        true, ONE_SECOND,
    ))
    clear(&canv.lock)

    // If we were drawing to this, we must Reset the fence.
    if canv.rendering {
        vkcheck(vk.ResetFences(
            device, 1, &canv.renderFence,
        ))

        // If we have not presented this Frame to some Swapchain.
        // We must reset the Semaphore.
        // if !this.presenting {
            
            

        //     this.presenting = false
        // }

        canv.rendering = false // 
    }

}

canvas_begin :: proc(ptr: ^dev.Canvas) -> dev.Cmd {
    using this := transmute(^Canvas_Vulkan) ptr
    
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

    commandState.active = true
    // log.info("Hello")
    return dev.Cmd {
        _vtable = &G.canvas_cmd,
        ptr = ptr,
    }
}

canvas_end :: proc(ptr: ^dev.Canvas) {
    using this := transmute(^Canvas_Vulkan) ptr
    
    vkcheck(vk.EndCommandBuffer(cmd))

    commandState.active = true

    // SUBMIT
    
    cmdInfo := command_buffer_submit_info(cmd)

    signalInfo := semaphore_submit_info(renderSema, {
        .ALL_GRAPHICS,
    })

    waitInfo: vk.SemaphoreSubmitInfo
    // If this frame has not been presented to a Swapchain
    //  we must await the Semaphore
    if this.rendered {
        waitInfo = semaphore_submit_info(renderSema, {
            .COLOR_ATTACHMENT_OUTPUT_KHR,
        })
    } else {
        this.rendered = true
    }

    // waitInfo := semaphore_submit_info(frame.swapSema, {
    //     .COLOR_ATTACHMENT_OUTPUT_KHR,
    // })

    // Will signal the Canvas sync structures when the Commands Finish
    submit := submit_info(
        &cmdInfo, &signalInfo,
        waitInfo.sType == {} ? nil : &waitInfo,
    );

    vkcheck(vk.QueueSubmit2(
        G.graphicsQueue, 1, &submit, renderFence
    ))

    // Signal that we are Rendering.
    rendering = true
    rendered = true

    // Canvas will need to wait before using this
    if idx, ok := slice.linear_search(this.lock[:], renderFence); !ok {
        append(&this.lock, renderFence)
    }
    
}

canvas_present :: proc(
    canvas: ^dev.Canvas,
    window: host.Window,
) {
    if host.window_is_minimized(window) {
        return
    }

    swap, ok := &G.windows[window]
    if !ok do return
    
    this := transmute(^Canvas_Vulkan) canvas
    
    // Wait for this slot in the swapchain to have Finished.
    frame := &swap.frames[swap.currentFrame]
    vkcheck(vk.WaitForFences(
        G.device, 1, &frame.renderFinished,
        true, ONE_SECOND,
    ))
    vkcheck(vk.ResetFences(
        G.device, 1, &frame.renderFinished,
    ))

    if swap.outOfDate {
        swapchain_recreate(swap)
    }

    swapchainImageIndex: u32
    vkcheck(vk.AcquireNextImageKHR(
        G.device, swap.swapchain, ONE_SECOND, frame.swapSema,
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
        // TODO: What happens if we are already presenting this Canvas?

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
            G.graphicsQueue, 1, &submit, frame.renderFinished
        ))

        // Canvas will need to wait before using this
        if idx, ok := slice.linear_search(this.lock[:], frame.renderFinished); !ok {
            append(&this.lock, frame.renderFinished)
        }

        // We are Presenting this Frame (Semaphore has been Awaited)
        //  signals the canvas that we should not await it's Semaphore
        this.rendered = false
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
            G.graphicsQueue, &presentInfo,
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
