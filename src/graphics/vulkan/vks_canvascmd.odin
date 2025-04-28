//#+private
package vulkandevice


import "base:runtime"
import "core:log"
import "core:slice"

import "formula:host"
import dev "../device"
import vma "formula:vendor/odin-vma"
import vk "vendor:vulkan"






_canvas_cmd_api :: proc() {
    using cmd := &global.canvas_cmd

    // Compute Programs
    use      = canvas_cmd_use
    dispatch = canvas_cmd_dispatch

    write  = canvas_cmd_write
    update = canvas_cmd_update
    push   = canvas_cmd_push
}

Bind_Writer :: struct {
    valid: bool,

    bindPoint: vk.PipelineBindPoint,
    layout: vk.PipelineLayout,

    writes: [dynamic]vk.WriteDescriptorSet,
    buffers: [dynamic]vk.DescriptorBufferInfo,
    images: [dynamic]vk.DescriptorImageInfo,

    // write: vk.WriteDescriptorSet,
    // extra: struct #raw_union {
    //     buffer: vk.DescriptorBufferInfo,
    //     image: vk.DescriptorImageInfo,
    // },
}

@(private="file")
write_binding :: proc(
    tobind: ^Bind_Writer,
    slot: u32,
    binding: dev.Binding,
) {
    current := len(tobind.writes)

    append(&tobind.writes, vk.WriteDescriptorSet {
        sType = .WRITE_DESCRIPTOR_SET,
        dstSet = 0,
        dstBinding = slot,
    })

    write := &tobind.writes[current]

    switch bind in binding {
    case ^dev.Canvas:
        canvas := transmute(^Canvas_Vulkan) bind
        append(&tobind.images, vk.DescriptorImageInfo {
            // TODO: Using the current layout may not make sense
            // 
            imageLayout = canvas.image.currentLayout,
            imageView = canvas.image.imageView,
        })
        
        write.descriptorType = .STORAGE_IMAGE
        write.descriptorCount = 1
        write.pImageInfo = slice.last_ptr(tobind.images[:])
    case:
        panic("Null Binding!")
    }


}

canvas_cmd_use :: proc(_cmd: ^dev.Cmd, _program: ^dev.Program) {
    using this := transmute(^Canvas_Vulkan) _cmd.ptr

    assert(commandState.active, "Cmd: canvas not active")

    program := transmute(^Program_Vulkan) _program

    vk.CmdBindPipeline(cmd, .COMPUTE, program.pipeline)

    commandState.bound = program

    // For this program to be used, must await the Canvas
    post(&program.lock, renderFence)
    // TODO: Better sync System
    

    // if writer.valid {
    //     writer.valid = false
    //     delete(set.writes)
    //     delete(set.buffers)
    //     delete(set.images)
    // }
}

canvas_cmd_write :: proc(
    _cmd: ^dev.Cmd,

    set: u32, slot: u32,
    binding: dev.Binding,
) {
    assert(set < 4, "Bind: set index is invalid")
    using this := transmute(^Canvas_Vulkan) _cmd.ptr
    // using global

    writer := &commandState.bind_writers[set]

    dset: vk.DescriptorSet

    switch b in commandState.bound {
    case ^Program_Vulkan:
        writer.bindPoint = .COMPUTE
        writer.layout = b.layout
    case:
        log.error(
            "Cannot write Binding! Nothing bound to Canvas!",
        )
        return
    }

    // Initialize the Writer
    if !writer.valid {
        writer.valid = true
        writer.writes = make([dynamic]vk.WriteDescriptorSet)
        writer.buffers = make([dynamic]vk.DescriptorBufferInfo)
        writer.images = make([dynamic]vk.DescriptorImageInfo)
    }

    write_binding(writer, slot, binding)
}

canvas_cmd_update :: proc(
    _cmd: ^dev.Cmd,
) {
    using this := transmute(^Canvas_Vulkan) _cmd.ptr
    using global

    for &set, idx in commandState.bind_writers {
        if !set.valid do continue

        // assert(vk.CmdPushDescriptorSetKHR != nil)

        vk.CmdPushDescriptorSetKHR(
            cmd, set.bindPoint, set.layout,
            u32(idx), u32(len(set.writes)), &set.writes[0],
        )

        // assert(false)

        // Delete the Set
        set.valid = false
        delete(set.writes)
        delete(set.buffers)
        delete(set.images)

    }

    // bindings

    // vk.CmdPushDescriptorSetKHR(
    //     cmd, .COMPUTE, 0, 0, 
    // )
    
}

canvas_cmd_push :: proc(
    _cmd: ^dev.Cmd,

    data: rawptr,
) {
    using this := transmute(^Canvas_Vulkan) _cmd.ptr

    layout: vk.PipelineLayout
    flags: vk.ShaderStageFlags
    push_size: u32
    switch b in commandState.bound {
    case ^Program_Vulkan:
        layout = b.layout
        push_size = b.pushUniformSize
        flags = { .COMPUTE }
    case:
        log.error(
            "Cannot write Binding! Nothing bound to Canvas!",
        )
        return
    }

    vk.CmdPushConstants(cmd, layout, flags, 0, push_size, data)
}

canvas_cmd_dispatch :: proc(
    _cmd: ^dev.Cmd,

    x, y, z: u32,
) {
    using this := transmute(^Canvas_Vulkan) _cmd.ptr
    using global

    vk.CmdDispatch(cmd, x, y, z)
}
