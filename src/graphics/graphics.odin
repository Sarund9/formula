package graphics


import dev "device"
import "formula:host"

import "vulkan"


API :: dev.API

Opt :: dev.Opt

Canvas :: dev.Canvas
Canvas_Desc :: dev.Canvas_Desc
Pass :: dev.Pass


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

present :: proc(canvas: ^Canvas, window: host.Window) {
    global.api.present(canvas, window)
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
