package graphics_device


import "formula:host"


API :: struct {
    inititialize: proc(opt: Opt, mainWindow: host.Window),
    shutdown: proc(),

    begin_pass, end_pass: proc(canvas: ^Canvas, pass: Pass),

    present: proc(^Canvas, host.Window),

    canvas: struct {
        create: proc(desc: Canvas_Desc) -> ^Canvas,
        dispose: proc(rawptr),
        // present: proc(rawptr, host.Window),
    },
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

Canvas :: struct {
    
}

Canvas_Desc :: struct {
    width, height: u32,
}

Pass :: struct {

}
