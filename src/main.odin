package main


import "core:log"

import "host"
import gfx "graphics"




main :: proc() {

    context.logger = log.create_console_logger(
        opt = { .Terminal_Color, .Level }
    )

    host.initialize()
    defer host.shutdown()

    win := host.create_window({
        title = "Hello Glint",
        width = 1080,
        height = 720,
    })
    defer host.destroy_window(win)

    gfx.initialize(win, {})
    defer gfx.shutdown()

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

        gfx.begin_frame()

        
        gfx.end_frame()
    }
}
