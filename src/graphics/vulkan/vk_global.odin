//#+private
package vulkandevice


import "base:runtime"
import "core:log"
import deq "core:container/queue"

import "formula:host"
import vma "formula:vendor/odin-vma"
import vk "vendor:vulkan"

import dev "../device"


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

    // Per-Window Swapchains
    windows: map[host.Window]Swapchain,
    // Swapchain Image count MUST BE THE SAME ACROSS SWAPCHAINS
    // swapchainImageCount: u32,

    // Per-Frame State
    // frames: [MAX_FRAMES_IN_FLIGHT]Frame,
    // currentFrame: u32,

    // Drawing Structures

    globalDeletionQueue: Action_Queue,

    canvas_cmd: dev.ICommand,

    collectQueue: Action_Queue,
}

ONE_SECOND :: 1000000000

collect :: proc() {
    using global

    exec_queue(&collectQueue)
}

qcollect :: proc(data: rawptr, procedure: proc(rawptr)) {
    using global

    deq.push(&collectQueue, Action {
        data = data,
        procedure = procedure,
    })
}


