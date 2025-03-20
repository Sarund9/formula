package vulkandevice


import "core:log"
import "formula:host"

import dev "../device"

import vk "vendor:vulkan"


Window_Canvas :: struct {
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
    swapchainImageIndex: u32, 

    surfaceCapabilities: vk.SurfaceCapabilitiesKHR,
    presentMode: vk.PresentModeKHR,
    preTransform: vk.SurfaceTransformFlagsKHR,

    imageExtents: vk.Extent2D,

    // True when the window is minimized
    outOfDate: bool,
}

MAX_FRAMES_IN_FLIGHT :: 4

window_canvas :: proc(window: host.Window) -> ^Window_Canvas {
    using global
    
    if window not_in windows {
        surface, res := host.create_vulkan_surface(window, instance, allocationCallbacks)
    
        log.assertf(res == .SUCCESS, "Could not create surface for Window: {}", res)
    
        windows[window] = Window_Canvas {
            window = window,
            surface = surface,
        }
    }

    return &windows[window]
}

/* Initializes the target window's Swapchain for Vulkan Rendering
*/
window_register :: proc(window: host.Window) {
    canv := window_canvas(window)

    // Swapchain Initialization
    pd := global.physicalDevice

    sup := query_swapchain_support(pd, canv.surface, context.temp_allocator)

    format := swapchain_choose_format(sup.formats)
    presentMode := swapchain_choose_presentmode(sup.presentModes)
    canv.imageExtents = swapchain_choose_extents(canv, sup.capabilities)

    canv.swapchainImageFormat = format.format
    canv.swapchainImageColorSpace = format.colorSpace
    canv.surfaceCapabilities = sup.capabilities
    canv.presentMode = presentMode
    canv.preTransform = sup.capabilities.currentTransform

    {
        imageCount := canv.surfaceCapabilities.minImageCount + 1
        maxImageCount := sup.capabilities.maxImageCount
        if maxImageCount > 0 && imageCount > maxImageCount {
            imageCount = min(maxImageCount, MAX_FRAMES_IN_FLIGHT)
        }
        canv.swapchainImageCount = imageCount
    }

    swapchain_create(canv)
}

swapchain_create :: proc(canv: ^Window_Canvas) {
    pd := global.physicalDevice

    createInfo := vk.SwapchainCreateInfoKHR {
        sType = .SWAPCHAIN_CREATE_INFO_KHR,
        surface = canv.surface,
        minImageCount = canv.swapchainImageCount,
        imageFormat = canv.swapchainImageFormat,
        imageColorSpace = canv.swapchainImageColorSpace,
        imageExtent = canv.imageExtents,
        imageArrayLayers = 1,
        imageUsage = { .COLOR_ATTACHMENT, .TRANSFER_DST },
        preTransform = canv.preTransform,
        compositeAlpha = { .OPAQUE },
        presentMode = canv.presentMode,
        clipped = true,
    }

    set := findFamilies(pd, canv.surface)
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

    res = vk.CreateSwapchainKHR(ld, &createInfo, alck, &canv.swapchain)
    log.assertf(res == .SUCCESS, "Vulkan: Failed to CreateSwapchain {}", res)

    vk.GetSwapchainImagesKHR(
        ld, canv.swapchain,
        &canv.swapchainImageCount,
        &canv.swapchainImages[0],
    )

    for i in 0..<canv.swapchainImageCount {
        info := vk.ImageViewCreateInfo {
            sType = .IMAGE_VIEW_CREATE_INFO,
            image = canv.swapchainImages[i],
            viewType = .D2,
            format = canv.swapchainImageFormat,
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

        res = vk.CreateImageView(ld, &info, alck, &canv.swapchainImageViews[i])
        log.assertf(res == .SUCCESS,
            "Vulkan: Failed to create Image-View [{}]: {}",
            i, res,
        )
    }
}

swapchain_dispose :: proc(canv: ^Window_Canvas) {
    using global
    for view in canv.swapchainImageViews {
        vk.DestroyImageView(device, view, allocationCallbacks)
    }
    vk.DestroySwapchainKHR(device, canv.swapchain, allocationCallbacks)
}

swapchain_recreate :: proc(canv: ^Window_Canvas) {
    gd := global.device
    pd := global.physicalDevice
    alck := global.allocationCallbacks

    surf := canv.surface

    defer canv.outOfDate = false

    // TODO

    vkcheck(vk.DeviceWaitIdle(gd))

    swapchain_dispose(canv)
    sup := query_swapchain_support(pd, surf, context.temp_allocator)
    next_extents := swapchain_choose_extents(canv, sup.capabilities)

    // log.info("NEXT SIZE:", next_extents)
    canv.imageExtents = next_extents
    swapchain_create(canv)
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
    win: ^Window_Canvas,
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
