package graphics


import dev "device"
import "formula:host"

import "vulkan"


API :: dev.API
Cmd :: dev.Cmd

Opt :: dev.Opt
Device_Preference :: dev.Device_Preference

Canvas      :: dev.Canvas
Canvas_Desc :: dev.Canvas_Desc
Pass        :: dev.Pass

Shader_Module :: dev.Shader_Module
Shader_Stage  :: dev.Shader_Stage
Program       :: dev.Program
Program_Desc  :: dev.Program_Desc
Shader_Desc   :: dev.Shader_Desc

Binding       :: dev.Binding
Binding_Desc  :: dev.Binding_Desc
Binding_Type  :: dev.Binding_Type

Push_Uniform_Desc :: dev.Push_Uniform_Desc


@private
global: struct {
    api: API,

}


initialize :: proc(initial_window: host.Window, opt: Opt) {
    using global

    vulkan.load_device(&api)

    api.inititialize(opt, initial_window)
}

shutdown :: proc() {
    using global

    api.shutdown()
}

create_canvas :: proc(desc: Canvas_Desc) -> ^Canvas {
    // TODO: Validate desc (eg width/height > 0)
    return global.api.canvas.create(desc)
}

destroy_canvas :: proc(canvas: ^Canvas) {
    global.api.canvas.dispose(canvas)
    free(canvas)
}

begin :: proc(canvas: ^Canvas) -> Cmd {
    using global
    return api.canvas.begin(canvas)
}

end :: proc(canvas: ^Canvas) {
    using global
    api.canvas.end(canvas)
}

present :: proc(canvas: ^Canvas, window: host.Window) {
    global.api.present(canvas, window)
}

collect :: proc() {
    global.api.collect()
}

load_shader :: proc(code: []byte) -> (Shader_Module, bool) {
    return global.api.shader.load(code)
}

unload_shader :: proc(mod: Shader_Module) {
    global.api.shader.unload(mod)
}

destroy_shader :: proc(mod: Shader_Module) {
    global.api.shader.unload(mod)
}

create_program :: proc(desc: Program_Desc) -> ^Program {
    return global.api.program.create(desc)
}

destroy_program :: proc(program: ^Program) {
    global.api.program.dispose(program)
    free(program)
}

bindset :: proc(
    binds: ..Binding_Desc, allocator := context.temp_allocator,
) -> []Binding_Desc {
    data := make([]Binding_Desc, len(binds), allocator)
    copy_slice(data, binds)
    return data
}

pushdata :: proc($T: typeid) -> Push_Uniform_Desc {
    return {
        size = size_of(T),
    }
}
