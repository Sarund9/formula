package vulkandevice



import dev "../device"


load_device :: proc(api: ^dev.API) {
    
    api.inititialize = initialize
    api.shutdown = shutdown

    api.present = canvas_present

    // api.begin_frame = begin_frame
    // api.end_frame = end_frame

    _canvas_api(api)
}
