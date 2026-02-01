package formula_host


import "base:runtime"
import deq "core:container/queue"

import cm "formula:common"
import vk "vendor:vulkan"


Window :: distinct rawptr

@private
global: struct {
    using _system: System_State,
    eventQueue: deq.Queue(Event),
    _context: runtime.Context,
}

initialize :: proc() {
    global._context = context

    _initialize()
}

shutdown :: proc() {

    _shutdown()
}

Window_Desc :: struct {
    title: string,
    width, height: int,
}

create_window :: proc(desc: Window_Desc) -> Window {
    return _create_window(desc)
}

destroy_window :: proc(window: Window) {
    _destroy_window(window)
}

process :: proc() {
    _process()
}

@private
push_event :: proc "contextless" (e: Event) {
    context = runtime.default_context()
    deq.push(&global.eventQueue, e)
}

events :: proc() -> (e: Event, ok: bool) {
    return deq.pop_front_safe(&global.eventQueue)
}

load_vulkan :: #force_inline proc() -> rawptr {
    return _load_vulkan()
}

create_vulkan_surface :: proc(
    window: Window,
    instance: vk.Instance,
    allocatorCallbacks: ^vk.AllocationCallbacks,
) -> (surf: vk.SurfaceKHR, res: vk.Result) {
    return _create_vulkan_surface(window, instance, allocatorCallbacks)
}

window_size :: proc(window: Window) -> cm.Vec2 {
    return _window_size(window)
}

window_is_minimized :: proc(window: Window) -> bool {
    return _window_is_minimized(window)
}
