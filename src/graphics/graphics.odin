package graphics


import dev "device"
import "formula:host"

import "vulkan"


API :: dev.API

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
Binding_Desc  :: dev.Binding_Desc
Binding_Type  :: dev.Binding_Type


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

begin_pass :: proc(canvas: ^Canvas, pass: Pass) {
    global.api.begin_pass(canvas, pass)
}

end_pass :: proc(canvas: ^Canvas, pass: Pass) {
    global.api.end_pass(canvas, pass)
}

present :: proc(canvas: ^Canvas, window: host.Window) {
    global.api.present(canvas, window)
}

load_shader :: proc(code: []byte) -> (Shader_Module, bool) {
    return global.api.shader.load(code)
}

destroy_shader :: proc(mod: Shader_Module) {
    global.api.shader.unload(mod)
}

create_program :: proc(desc: Program_Desc) -> ^Program {
    return global.api.program.create(desc)
}

