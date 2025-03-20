package graphics_device


import "formula:host"


API :: struct {
    inititialize: proc(opt: Opt, mainWindow: host.Window),
    shutdown: proc(),

    begin_frame, end_frame: proc(),
}

Opt :: struct {
    deviceTypePreference: Device_Preference,
    forceDeviceType: bool,
}

Device_Preference :: enum {
    Discrete,
    Integrated,
    Software,
    Virtual,
}
