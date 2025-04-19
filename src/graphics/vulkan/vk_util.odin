//#+private
package vulkandevice


import "base:runtime"
import "core:log"
import deq "core:container/queue"

import dev "../device"

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

stage_to_flags :: proc(stage: dev.Shader_Stage) -> vk.ShaderStageFlag {
    switch stage {
    case .Compute:  return .COMPUTE
    case .Vertex:   return .VERTEX
    case .Fragment: return .FRAGMENT
    }
    log.panicf("Unreachable: invalid stage {}", stage)
}

binding_type :: proc(type: dev.Binding_Type) -> vk.DescriptorType {
    switch type {
    case:  return .STORAGE_IMAGE
    }
}
