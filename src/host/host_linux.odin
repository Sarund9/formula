//#+private
package formula_host


import "base:runtime"
import "core:fmt"
import "core:unicode/utf16"
import "core:log"
import vk "vendor:vulkan"

import cm "formula:common"




System_State :: struct {
    
}

_initialize :: proc() {
    

}

_shutdown :: proc() {
    

    
}

Backing_Window :: struct {
    
}

_create_window :: proc(desc: Window_Desc) -> Window {
    

    panic("Not Implemented!")

    // return Window(handle)
}

_destroy_window :: proc(window: Window) {
    
}

_process :: proc() {
    
}

_load_vulkan :: proc () -> rawptr {
    
    panic("Not Implemented!")
}

_create_vulkan_surface :: proc(
    window: Window,
    instance: vk.Instance, allocatorCallbacks: ^vk.AllocationCallbacks,
) -> (surf: vk.SurfaceKHR, res: vk.Result) {
    
    panic("Not Implemented!")

    // return
}

_window_size :: proc(window: Window) -> cm.Vec2 {
    return {}
}

_window_is_minimized :: proc(window: Window) -> bool {
    return false
}
