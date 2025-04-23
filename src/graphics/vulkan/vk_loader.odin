package vulkandevice



import dev "../device"


load_device :: proc(api: ^dev.API) {
    
    api.inititialize = initialize
    api.shutdown = shutdown

    api.present = canvas_present

    api.collect = collect
    // api.begin_pass = canvas_begin
    // api.end_pass = canvas_end
    // api.begin_frame = begin_frame
    // api.end_frame = end_frame

    _canvas_api(api)
    _shader_api(api)
    _program_api(api)
}
