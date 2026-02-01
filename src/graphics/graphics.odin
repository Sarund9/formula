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
G: struct {
    api: API,

}


initialize :: proc(initial_window: host.Window, opt: Opt) {

    vulkan.load_device(&G.api)

    G.api.inititialize(opt, initial_window)
}

shutdown :: proc() {

    G.api.shutdown()
}

create_canvas :: proc(desc: Canvas_Desc) -> ^Canvas {
    // TODO: Validate desc (eg width/height > 0)
    return G.api.canvas.create(desc)
}

destroy_canvas :: proc(canvas: ^Canvas) {
    G.api.canvas.dispose(canvas)
    free(canvas)
}

begin :: proc(canvas: ^Canvas) -> Cmd {
    return G.api.canvas.begin(canvas)
}

end :: proc(canvas: ^Canvas) {
    G.api.canvas.end(canvas)
}

present :: proc(canvas: ^Canvas, window: host.Window) {
    G.api.present(canvas, window)
}

collect :: proc() {
    G.api.collect()
}

load_shader :: proc(code: []byte) -> (Shader_Module, bool) {
    return G.api.shader.load(code)
}

unload_shader :: proc(mod: Shader_Module) {
    G.api.shader.unload(mod)
}

destroy_shader :: proc(mod: Shader_Module) {
    G.api.shader.unload(mod)
}

create_program :: proc(desc: Program_Desc) -> ^Program {
    return G.api.program.create(desc)
}

destroy_program :: proc(program: ^Program) {
    G.api.program.dispose(program)
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
