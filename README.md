# Formula

An Odin-native Framework abstracting modern graphics APIs and windowing.



### Usage

Mark the `src` folder as a the `formula` Collection.

```odin
package main

import cm "formula:common"
import gfx "formula:graphics"
import "formula:host"


main :: proc() {
    host.initialize()
    defer host.shutdown()

    win := host.create_window({
        title = "Hello Formula!",
        width = 1080,
        height = 720,
    })
    defer host.destroy_window(win)

    gfx.initialize(win, {})
    defer gfx.shutdown()

    quit: bool
    for !quit {
        host.process() // Process (poll) events
        // Handle events by iterator
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

```

