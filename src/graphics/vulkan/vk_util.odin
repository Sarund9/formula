//#+private
package vulkandevice


import "base:runtime"
import "core:log"
import deq "core:container/queue"

import vk "vendor:vulkan"


not :: proc(res: vk.Result) -> bool {
    return res != .SUCCESS
}

vkcheck :: proc(res: vk.Result, loc := #caller_location) {
    log.assertf(res == .SUCCESS, "Vulkan Call Failed: {}", res, loc = loc)
}

Action_Queue :: deq.Queue(Action)

Action :: struct {
    data: rawptr,
    procedure: proc(rawptr),
}

exec_queue :: proc(act: ^Action_Queue) {
    for act in deq.pop_front_safe(act) {
        act.procedure(act.data)
    }
}

destroy_queue :: deq.destroy
