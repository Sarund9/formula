package vulkandevice


import "core:log"
import sarray "core:container/small_array"

import "formula:host"
import vma "formula:vendor/odin-vma"

import dev "../device"

import vk "vendor:vulkan"


@private
validationLayers := []cstring {
    "VK_LAYER_KHRONOS_validation"
}

initialize :: proc(opt: dev.Opt, mainWindow: host.Window) {
    using global

    initContext = context

    vk.load_proc_addresses(host.load_vulkan())

    create_instance()

    // Load instance dependant procedures
    vk.load_proc_addresses_instance(instance)

    // Register the main window's Surface, but not create the Swapchain yet
    canvas := window_canvas(mainWindow)

    pick_physical_device(opt, canvas.surface)
    create_logical_device(canvas.surface)

    // Initialize Memory Allocator
    {
        func := vma.create_vulkan_functions()

        info := vma.AllocatorCreateInfo {
            physicalDevice = physicalDevice,
            device = device,
            instance = instance,
            flags = { .BUFFER_DEVICE_ADDRESS },
            pVulkanFunctions = &func,
        }

        res := vma.CreateAllocator(&info, &allocator)
        vkcheck(res)
    }

    // Run the register function, this will Initialize the Swapchain
    window_register(mainWindow)

    // Create structures for as many frames as there are in the Swapchain
    // TODO: Multi-Swapchain for Windows
    create_frame_structures(canvas.swapchainImageCount)
}

shutdown :: proc() {
    using global

    vk.DeviceWaitIdle(device)

    for &frame in frames {
        vk.DestroyCommandPool(device, frame.commandPool, allocationCallbacks)
        vk.DestroyFence(device, frame.renderFinished, allocationCallbacks)
        vk.DestroySemaphore(device, frame.swapSema, allocationCallbacks)
        vk.DestroySemaphore(device, frame.presentSema, allocationCallbacks)

        // TODO: Frame queues
        // exec_queue(&frame.deletionQueue)
        // deq.destroy(&frame.deletionQueue)
    }

    for win, &canv in windows {
        swapchain_dispose(&canv)
        vk.DestroySurfaceKHR(instance, canv.surface, allocationCallbacks)
    }

    vma.DestroyAllocator(allocator)

    vk.DestroyDevice(device, allocationCallbacks)

    vk.DestroyDebugUtilsMessengerEXT(instance, debugMessenger, allocationCallbacks)

    vk.DestroyInstance(instance, allocationCallbacks)
}

@(private="file")
create_instance :: proc() {
    appInfo := vk.ApplicationInfo {
        sType = .APPLICATION_INFO,
        pApplicationName = "Formula Engine Application",
        applicationVersion = vk.MAKE_VERSION(0, 1, 0), // TODO: Unify Versions
        pEngineName = "Formula Engine",
        engineVersion = vk.MAKE_VERSION(0, 1, 0),
        apiVersion = vk.API_VERSION_1_3,
    }

    enabledExtensions := make([dynamic]cstring)
    defer delete(enabledExtensions)

    when ODIN_OS == .Windows {
        append(&enabledExtensions, vk.KHR_SURFACE_EXTENSION_NAME)
        append(&enabledExtensions, vk.KHR_WIN32_SURFACE_EXTENSION_NAME)
    } else {
        panic("Vulkan: Platform not Implemented")
    }

    // Enable Validation Layers
    if !checkValidationLayers(validationLayers) {
        panic("Vulkan: Validation layers not Supported")
    }

    append(&enabledExtensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

    createInfo := vk.InstanceCreateInfo {
        sType = .INSTANCE_CREATE_INFO,
        pApplicationInfo = &appInfo,
        enabledExtensionCount = u32(len(enabledExtensions)),
        ppEnabledExtensionNames = raw_data(enabledExtensions),
        enabledLayerCount = u32(len(validationLayers)), // TODO: Layers
        ppEnabledLayerNames = raw_data(validationLayers),
    }

    using global

    res := vk.CreateInstance(&createInfo, allocationCallbacks, &instance)
    log.assertf(res == .SUCCESS, "Failed to initialize VK instance: {}", res)
}

@(private="file")
create_debug_messenger :: proc() {
    createInfo := vk.DebugUtilsMessengerCreateInfoEXT {
        sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        messageSeverity = { .VERBOSE, .INFO, .WARNING, .ERROR },
        messageType = { .GENERAL, .VALIDATION, .PERFORMANCE, .DEVICE_ADDRESS_BINDING },
        pfnUserCallback = debugCallback,

    }
    using global
    res := vk.CreateDebugUtilsMessengerEXT(
        instance, &createInfo, allocationCallbacks, &debugMessenger,
    )
    log.assertf(res == .SUCCESS, "Failed to create VK debug messenger: ", res)

    // ----------------- \\

    debugCallback :: proc "system" (
        messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
        messageType: vk.DebugUtilsMessageTypeFlagsEXT,
        pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
        userData: rawptr,
    ) -> b32 {
        context = global.initContext
        lev: log.Level
        switch messageSeverity {
        case { .VERBOSE }:  lev = .Debug
        case { .INFO }:     lev = .Info
        case { .WARNING }:  lev = .Warning
        case { .ERROR }:    lev = .Error
        }
        if lev < log.Level.Warning do return false // Hard-Set log level to Warning
        
        typeMsg: string
        switch messageType {
        case { .GENERAL }:          typeMsg = "GENERAL"
        case { .VALIDATION }:       typeMsg = "VALIDATION"
        case { .PERFORMANCE }:      typeMsg = "PERFORMANCE"
        case { .DEVICE_ADDRESS_BINDING }: typeMsg = "DEVICE ADDRESS BINDING"
        }
        log.logf(lev, "VK-VL [{}]: {}", typeMsg, pCallbackData.pMessage)

        return false
    }
}

@(private="file")
pick_physical_device :: proc(opt: dev.Opt, surface: vk.SurfaceKHR) {
    using global
    deviceCount: u32
    vk.EnumeratePhysicalDevices(instance, &deviceCount, nil)

    physicalDevices := make([]vk.PhysicalDevice, deviceCount)
    defer delete(physicalDevices)

    vk.EnumeratePhysicalDevices(instance, &deviceCount, raw_data(physicalDevices))

    switch len(physicalDevices) {
    case 0:
        log.panic("Cannot initialize Vulkan: No physical devices found!")
    case 1:
        // Pick the only available Device
        physicalDevice = physicalDevices[0]
        pref := tovk(opt.deviceTypePreference)
        props: vk.PhysicalDeviceProperties
        vk.GetPhysicalDeviceProperties(physicalDevice, &props)
        if opt.forceDeviceType {
            log.assertf(props.deviceType == pref,
                "Cannot initialize Vulkan for device of type: '{}', " +
                "the only device available is '{}' of type {}",
                opt.deviceTypePreference,
                cstring(&props.deviceName[0]), props.deviceType,
            )
        }
        indices := findFamilies(physicalDevice, surface)
        log.assertf(familyComplete(indices),
            "Cannot initialize Vulkan, the only device: '{}', " +
            " does not have a Graphics capable Queue",
            cstring(&props.deviceName[0]),
        )

        log.assertf(check_device_ext(physicalDevice),
            "Cannot initialize Vulkan, the only device: '{}', " + 
            "does not support Swapchain Extensions",
            cstring(&props.deviceName[0]),
        )

        swapsupport := query_swapchain_support(physicalDevice, surface, context.temp_allocator)
        log.assertf(swapchain_supported(swapsupport), 
            "Cannot initialize Vulkan, the only device: '{}', " +
            "has inadecuate Swapchain Support",
            cstring(&props.deviceName[0]),
        )
    case:
        score := min(int)
        pref := tovk(opt.deviceTypePreference)
        for device in physicalDevices {
            props: vk.PhysicalDeviceProperties
            vk.GetPhysicalDeviceProperties(device, &props)

            feats: vk.PhysicalDeviceFeatures
            vk.GetPhysicalDeviceFeatures(device, &feats)

            indices := findFamilies(physicalDevice, surface)
            swapsupport := query_swapchain_support(
                physicalDevice, surface, context.temp_allocator)

            // Required GPU Features
            if !familyComplete(indices)          do continue
            if !check_device_ext(physicalDevice) do continue
            if !swapchain_supported(swapsupport) do continue

            currentScore := 0

            // Force selection of specific device type
            if opt.forceDeviceType && props.deviceType != pref {
                continue
            }
            
            // Device type preference
            if props.deviceType == pref do currentScore += 5000
            
            switch props.deviceType {
            case .DISCRETE_GPU:   currentScore += 30
            case .INTEGRATED_GPU: currentScore += 10
            case .CPU:            currentScore += 5
            case .VIRTUAL_GPU:
            case .OTHER:
            }

            // TODO: More Device Selection Preferences
            // - Required Features
            // - Exclude Limits
            if currentScore > score {
                score = currentScore
                physicalDevice = device
            }
            
        }

        log.assertf(physicalDevice != nil,
            "Vulkan Initialization Failed: " +
            "could not find Device of type {}",
            pref,
        )
    }

    // ----------------- \\

    tovk :: proc(type: dev.Device_Preference) -> vk.PhysicalDeviceType {
        switch type {
        case .Discrete:   return .DISCRETE_GPU
        case .Integrated: return .INTEGRATED_GPU
        case .Software:   return .CPU
        case .Virtual:    return .VIRTUAL_GPU
        }
        unreachable()
    }
}

@(private="file")
create_logical_device :: proc(surface: vk.SurfaceKHR) {
    using global
    indices := findFamilies(physicalDevice, surface)

    graphicsQueueFamily = indices[.Graphics].?
    presentQueueFamily = indices[.Present].?

    priority := f32(1)

    queues: sarray.Small_Array(4, vk.DeviceQueueCreateInfo)

    index_loop: for &index, family in indices {
        for i in 0..<sarray.len(queues) {
            if queues.data[i].queueFamilyIndex == index { break index_loop }
        }
        info := vk.DeviceQueueCreateInfo {
            sType = .DEVICE_QUEUE_CREATE_INFO,
            queueFamilyIndex = indices[family].?,
            queueCount = 1,
            pQueuePriorities = &priority,
        }
        sarray.append(&queues, info)
    }

    // TODO: Proper feature requests
    vk13feat := vk.PhysicalDeviceVulkan13Features {
        sType = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
        dynamicRendering = true,
        synchronization2 = true,
    }

    vk12feat := vk.PhysicalDeviceVulkan12Features {
        sType = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
        pNext = &vk13feat,

        bufferDeviceAddress = true,
        descriptorIndexing = true,
    }

    deviceFeatures := vk.PhysicalDeviceFeatures2 {
        sType = .PHYSICAL_DEVICE_FEATURES_2,
        pNext = &vk12feat,
    }

    deviceExtensions := make([dynamic]cstring)
    defer delete(deviceExtensions)
    append(&deviceExtensions, vk.KHR_SWAPCHAIN_EXTENSION_NAME)

    createInfo := vk.DeviceCreateInfo {
        sType = .DEVICE_CREATE_INFO,
        pNext = &deviceFeatures,

        queueCreateInfoCount = u32(sarray.len(queues)),
        pQueueCreateInfos = &queues.data[0],

        enabledExtensionCount = u32(len(deviceExtensions)),
        ppEnabledExtensionNames = raw_data(deviceExtensions),
        
        enabledLayerCount = u32(len(validationLayers)), // TODO: Layers
        ppEnabledLayerNames = raw_data(validationLayers),
    }

    res := vk.CreateDevice(physicalDevice, &createInfo, allocationCallbacks, &device)
    log.assertf(res == .SUCCESS,
        "Cannot initialize Vulkan: " + 
        "failed to create logical device: {}", res,
    )

    vk.GetDeviceQueue(device, indices[.Graphics].(u32), 0, &graphicsQueue)
    vk.GetDeviceQueue(device, indices[.Present].(u32), 0, &presentQueue)
}

@(private="file")
create_frame_structures :: proc(framesInFlight: u32) {

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
    for i in 0..<framesInFlight {
        frame := &global.frames[i]
        
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

checkValidationLayers :: proc(requiredLayers: []cstring) -> bool {

    layerCount: u32

    vk.EnumerateInstanceLayerProperties(&layerCount, nil)

    availableLayers := make([]vk.LayerProperties, layerCount)
    defer delete(availableLayers)

    vk.EnumerateInstanceLayerProperties(&layerCount, raw_data(availableLayers))

    for req in requiredLayers {
        layerFound: bool
        for &avail in availableLayers {
            name := cstring(&avail.layerName[0])
            if req == name {
                layerFound = true
                break
            }
        }
        if !layerFound {
            return false
        }
    }

    return true
}

Queue_Family :: enum {
    Graphics, Present,
}

Queue_Family_Set :: [Queue_Family]Maybe(u32)

familyComplete :: proc(set: Queue_Family_Set) -> bool {
    for i in set {
        if i == nil do return false
    }
    return true
}

findFamilies :: proc(dev: vk.PhysicalDevice, surf: vk.SurfaceKHR) -> (set: Queue_Family_Set) {
    familyCount: u32
    vk.GetPhysicalDeviceQueueFamilyProperties(dev, &familyCount, nil)
    families := make([]vk.QueueFamilyProperties, familyCount)
    defer delete(families)
    vk.GetPhysicalDeviceQueueFamilyProperties(dev, &familyCount, raw_data(families))

    res: vk.Result

    for fam, i in families {
        if .GRAPHICS in fam.queueFlags {
            set[.Graphics] = u32(i)
        }
        presentSupport: b32
        res = vk.GetPhysicalDeviceSurfaceSupportKHR(dev, u32(i), surf, &presentSupport)
        log.assertf(res == .SUCCESS, "VK QueueFamilySets: Failed to check for Surface Support on [{}]: {}", i, res)
        if presentSupport {
            set[.Present] = u32(i)
        }

        if familyComplete(set) {
            break
        }
    }
    return
}

check_device_ext :: proc(dev: vk.PhysicalDevice) -> bool {
    extensionCount: u32
    vk.EnumerateDeviceExtensionProperties(dev, nil, &extensionCount, nil)
    extensions := make([]vk.ExtensionProperties, extensionCount, context.temp_allocator)
    vk.EnumerateDeviceExtensionProperties(dev, nil, &extensionCount, &extensions[0])

    required := make(map[cstring]int)
    required[vk.KHR_SWAPCHAIN_EXTENSION_NAME] = 0
    
    defer delete(required)

    for &ext in extensions {
        delete_key(&required, cstring(&ext.extensionName[0]))
    }

    return len(required) == 0
}

