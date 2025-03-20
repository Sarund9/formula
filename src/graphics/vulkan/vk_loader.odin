package vulkandevice



import dev "../device"


load_device :: proc(api: ^dev.API) {
    
    api.inititialize = initialize
    api.shutdown = shutdown

    api.begin_frame = begin_frame
    api.end_frame = end_frame
}
