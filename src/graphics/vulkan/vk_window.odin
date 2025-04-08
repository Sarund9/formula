package vulkandevice


import "core:log"
import "formula:host"

import dev "../device"

import vk "vendor:vulkan"

MAX_FRAMES_IN_FLIGHT :: 4

Swapchain :: struct {
    window: host.Window,
    surface: vk.SurfaceKHR,

    // SWAPCHAIN
    swapchain: vk.SwapchainKHR,
    swapchainImages: [MAX_FRAMES_IN_FLIGHT]vk.Image,
    swapchainImageViews: [MAX_FRAMES_IN_FLIGHT]vk.ImageView,
    swapchainImageCount: u32,
    swapchainImageFormat: vk.Format,
    swapchainImageColorSpace: vk.ColorSpaceKHR,

    // Currently rendering Index
    // swapchainImageIndex: u32, 

    surfaceCapabilities: vk.SurfaceCapabilitiesKHR,
    presentMode: vk.PresentModeKHR,
    preTransform: vk.SurfaceTransformFlagsKHR,

    imageExtents: vk.Extent2D,

    outOfDate: bool,

    // Frame Structures
    frames: [MAX_FRAMES_IN_FLIGHT]Swapchain_Frame,
    currentFrame: u32,
}

Swapchain_Frame :: struct {
    commandPool: vk.CommandPool,
    mainCommandBuffer: vk.CommandBuffer,

    swapSema, presentSema: vk.Semaphore,
    renderFinished: vk.Fence,

    deletionQueue: Action_Queue,
}

get_swapchain :: proc(window: host.Window) -> ^Swapchain {
    using global
    
    if window not_in windows {
        surface, res := host.create_vulkan_surface(window, instance, allocationCallbacks)
    
        log.assertf(res == .SUCCESS, "Could not create surface for Window: {}", res)
    
        windows[window] = Swapchain {
            window = window,
            surface = surface,
        }
    }

    return &windows[window]
}

/* Initializes the target window's Swapchain for Vulkan Rendering
*/
window_register :: proc(window: host.Window) {
    swap := get_swapchain(window)

    // Swapchain Initialization
    pd := global.physicalDevice

    sup := query_swapchain_support(pd, swap.surface, context.temp_allocator)

    format := swapchain_choose_format(sup.formats)
    presentMode := swapchain_choose_presentmode(sup.presentModes)
    swap.imageExtents = swapchain_choose_extents(swap, sup.capabilities)

    swap.swapchainImageFormat = format.format
    swap.swapchainImageColorSpace = format.colorSpace
    swap.surfaceCapabilities = sup.capabilities
    swap.presentMode = presentMode
    swap.preTransform = sup.capabilities.currentTransform

    {
        imageCount := swap.surfaceCapabilities.minImageCount + 1
        maxImageCount := sup.capabilities.maxImageCount
        if maxImageCount > 0 && imageCount > maxImageCount {
            imageCount = min(maxImageCount, MAX_FRAMES_IN_FLIGHT)
        }
        swap.swapchainImageCount = imageCount
    }

    swapchain_create(swap)
    swapchain_frames_init(swap)
}

swapchain_create :: proc(swap: ^Swapchain) {
    pd := global.physicalDevice

    createInfo := vk.SwapchainCreateInfoKHR {
        sType = .SWAPCHAIN_CREATE_INFO_KHR,
        surface = swap.surface,
        minImageCount = swap.swapchainImageCount,
        imageFormat = swap.swapchainImageFormat,
        imageColorSpace = swap.swapchainImageColorSpace,
        imageExtent = swap.imageExtents,
        imageArrayLayers = 1,
        imageUsage = { .COLOR_ATTACHMENT, .TRANSFER_DST },
        preTransform = swap.preTransform,
        compositeAlpha = { .OPAQUE },
        presentMode = swap.presentMode,
        clipped = true,
    }

    set := findFamilies(pd, swap.surface)
    indices: [Queue_Family]u32
    indices[.Graphics] = set[.Graphics].(u32)
    indices[.Present] = set[.Graphics].(u32)

    if indices[.Graphics] != indices[.Present] {
        createInfo.imageSharingMode = .CONCURRENT
        createInfo.queueFamilyIndexCount = 2
        createInfo.pQueueFamilyIndices = &indices[auto_cast 0]
    }

    ld := global.device
    assert(ld != nil)

    alck := global.allocationCallbacks
    res: vk.Result

    res = vk.CreateSwapchainKHR(ld, &createInfo, alck, &swap.swapchain)
    log.assertf(res == .SUCCESS, "Vulkan: Failed to CreateSwapchain {}", res)

    vk.GetSwapchainImagesKHR(
        ld, swap.swapchain,
        &swap.swapchainImageCount,
        &swap.swapchainImages[0],
    )

    for i in 0..<swap.swapchainImageCount {
        info := vk.ImageViewCreateInfo {
            sType = .IMAGE_VIEW_CREATE_INFO,
            image = swap.swapchainImages[i],
            viewType = .D2,
            format = swap.swapchainImageFormat,
            components = {
                r = .IDENTITY,
                g = .IDENTITY,
                b = .IDENTITY,
                a = .IDENTITY,
            },
            subresourceRange = {
                aspectMask = { .COLOR },
                levelCount = 1,
                layerCount = 1,
            }
        }

        res = vk.CreateImageView(ld, &info, alck, &swap.swapchainImageViews[i])
        log.assertf(res == .SUCCESS,
            "Vulkan: Failed to create Image-View [{}]: {}",
            i, res,
        )
    }
}

swapchain_dispose :: proc(swap: ^Swapchain) {
    using global
    for view in swap.swapchainImageViews {
        vk.DestroyImageView(device, view, allocationCallbacks)
    }
    vk.DestroySwapchainKHR(device, swap.swapchain, allocationCallbacks)
}

swapchain_recreate :: proc(swap: ^Swapchain) {
    gd := global.device
    pd := global.physicalDevice
    alck := global.allocationCallbacks

    surf := swap.surface

    defer swap.outOfDate = false

    // TODO

    vkcheck(vk.DeviceWaitIdle(gd))

    swapchain_dispose(swap)
    sup := query_swapchain_support(pd, surf, context.temp_allocator)
    next_extents := swapchain_choose_extents(swap, sup.capabilities)

    // log.info("NEXT SIZE:", next_extents)
    swap.imageExtents = next_extents
    swapchain_create(swap)
}

swapchain_frames_init :: proc(swap: ^Swapchain) {

    poolInfo := vk.CommandPoolCreateInfo {
        sType = .COMMAND_POOL_CREATE_INFO,
        flags = { .RESET_COMMAND_BUFFER },
        queueFamilyIndex = global.graphicsQueueFamily,
    }

    fenceInfo := fence_create_info({ .SIGNALED })
    semaInfo := semaphore_create_info({})

    ld := global.device
    alck := global.allocationCallbacks

    res: vk.Result
    for i in 0..<swap.swapchainImageCount {
        frame := &swap.frames[i]
        
        res = vk.CreateCommandPool(ld, &poolInfo, alck, &frame.commandPool)
        vkcheck(res)

        cmdAllocInfo := vk.CommandBufferAllocateInfo {
            sType = .COMMAND_BUFFER_ALLOCATE_INFO,
            commandPool = frame.commandPool,
            commandBufferCount = 1,
            level = .PRIMARY,
        }

        res = vk.AllocateCommandBuffers(ld, &cmdAllocInfo, &frame.mainCommandBuffer)
        vkcheck(res)

        res = vk.CreateFence(ld, &fenceInfo, alck, &frame.renderFinished)
        vkcheck(res)

        res = vk.CreateSemaphore(ld, &semaInfo, alck, &frame.swapSema)
        vkcheck(res)

        res = vk.CreateSemaphore(ld, &semaInfo, alck, &frame.presentSema)
        vkcheck(res)
    }
}

swapchain_frames_deinit :: proc(swap: ^Swapchain) {
    ld := global.device
    alck := global.allocationCallbacks
    for &frame in swap.frames {
        vk.DestroyCommandPool(ld, frame.commandPool, alck)
        vk.DestroyFence(ld, frame.renderFinished, alck)
        vk.DestroySemaphore(ld, frame.swapSema, alck)
        vk.DestroySemaphore(ld, frame.presentSema, alck)

        exec_queue(&frame.deletionQueue)
        destroy_queue(&frame.deletionQueue)
    }
}

Swapchain_Support :: struct {
    capabilities: vk.SurfaceCapabilitiesKHR,
    formats: []vk.SurfaceFormatKHR,
    presentModes: []vk.PresentModeKHR,
}

query_swapchain_support :: proc(
    dev: vk.PhysicalDevice, surf: vk.SurfaceKHR, allocator := context.allocator,
) -> (details: Swapchain_Support) {
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(dev, surf, &details.capabilities)

    formatCount: u32
    vk.GetPhysicalDeviceSurfaceFormatsKHR(dev, surf, &formatCount, nil)
    details.formats = make([]vk.SurfaceFormatKHR, formatCount, allocator)
    vk.GetPhysicalDeviceSurfaceFormatsKHR(dev, surf, &formatCount, &details.formats[0])

    presentModeCount: u32
    vk.GetPhysicalDeviceSurfacePresentModesKHR(
        dev, surf, &presentModeCount, nil)
    details.presentModes = make([]vk.PresentModeKHR, presentModeCount, allocator)
    vk.GetPhysicalDeviceSurfacePresentModesKHR(
        dev, surf, &presentModeCount, &details.presentModes[0])

    // log.info("Formats:", len(details.formats), "Modes:", len(details.presentModes))
    
    return
}

swapchain_supported :: proc(sup: Swapchain_Support) -> bool {
    return len(sup.formats) > 0 && len(sup.presentModes) > 0
}

swapchain_choose_format :: proc(availableFormats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
    for format in availableFormats {
        if format.format == .B8G8R8A8_UNORM && format.colorSpace == .SRGB_NONLINEAR {
            return format
        }
    }

    log.warn("Vulkan: BGRA32 UNROM NONLINEAR Surface Format not Found, using:", availableFormats[0])
    return availableFormats[0]
}

swapchain_choose_presentmode :: proc(presentModes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
    for mode in presentModes {
        if mode == .MAILBOX {
            return mode
        }
    }

    log.warn("Vulkan: MAILBOX Present Mode not Found, using:", presentModes[0])
    return presentModes[0]
}

swapchain_choose_extents :: proc(
    win: ^Swapchain,
    cap: vk.SurfaceCapabilitiesKHR,
) -> vk.Extent2D {
    // if cap.currentExtent.width != max(u32) {
    //     log.warn("CURR")
    //     return cap.currentExtent
    // }
    size := host.window_size(win.window)

    return vk.Extent2D {
        width = clamp(u32(size.x), cap.minImageExtent.width, cap.maxImageExtent.width),
        height = clamp(u32(size.y), cap.minImageExtent.height, cap.maxImageExtent.height),
    }
}
