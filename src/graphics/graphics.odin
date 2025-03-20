package graphics


import dev "device"
import "formula:host"

import "vulkan"


API :: dev.API

Opt :: dev.Opt


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

begin_frame :: proc() {
    using global
    api.begin_frame()
}

end_frame :: proc() {
    using global
    api.end_frame()
}
