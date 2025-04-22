package main


import "core:log"
import "core:os"

import "host"
import gfx "graphics"




main :: proc() {

    context.logger = log.create_console_logger(
        opt = { .Terminal_Color, .Level }
    )

    gradientCS, ok := os.read_entire_file("shaders/gradient.spv")
    assert(ok, "Shader Not Found!")
    defer delete(gradientCS)

    host.initialize()
    defer host.shutdown()

    win := host.create_window({
        title = "Formula",
        width = 1080,
        height = 720,
    })
    defer host.destroy_window(win)

    gfx.initialize(win, {})
    defer gfx.shutdown()

    canvas := gfx.create_canvas(gfx.Canvas_Desc {
        width = 1080,
        height = 720,
    })
    defer gfx.destroy_canvas(canvas)

    gradient, sok := gfx.load_shader(gradientCS)
    assert(sok, "Shader module could not be loaded!")
    defer gfx.unload_shader(gradient)

    program := gfx.create_program(gfx.Program_Desc {
        shader = { gradient, .Compute, "main" },
        bindings = {
            0 = gfx.bindset(
                { 0, .ImageStorage },

            )
        }
    })
    defer gfx.destroy_program(program)

    quit: bool
    for !quit {
        host.process()
        for event in host.events() {
            using host
            #partial switch e in event {
            case Event_App:
                switch e {
                case .Quit: quit = true
                }
            }
        }

        using gfx
        cmd := begin(canvas)
        cmd->use(program)
        cmd->write(0, 0, canvas)
        cmd->update()
        cmd->dispatch(canvas.width, canvas.height, 1)

        end(canvas)

        present(canvas, win)
        // gfx.begin_frame()

        
        // gfx.end_frame()
    }
}
