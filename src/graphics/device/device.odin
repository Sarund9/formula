package graphics_device


import "formula:host"


API :: struct {
    inititialize: proc(opt: Opt, mainWindow: host.Window),
    shutdown: proc(),

    begin_pass, end_pass: proc(canvas: ^Canvas, pass: Pass),

    present: proc(^Canvas, host.Window),

    canvas: struct {
        create: proc(desc: Canvas_Desc) -> ^Canvas,
        dispose: proc(^Canvas),
        // present: proc(rawptr, host.Window),
    },

    // Shaders
    shader: struct {
        load: proc(code: []u8) -> (Shader_Module, bool),
        unload: proc(mod: Shader_Module),

        // create: proc(desc: Shader_Desc) -> (^Shader, bool),
        // dispose: proc(^Shader),
    },

    // Compute Shader Pipeline
    program: struct {
        create: proc(desc: Program_Desc) -> ^Program,
        dispose: proc(^Program),
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

Shader_Module :: distinct rawptr

Shader_Stage :: enum {
    Compute,
    Vertex,
    Fragment,
}

Program :: struct {
    
}

Program_Desc :: struct {
    shader: Shader_Desc,
    bindings: [4][]Binding_Desc,
}

Shader_Desc :: struct {
    module: Shader_Module,
    stage: Shader_Stage,
    entrypoint: cstring,
}

Binding_Desc :: struct {
    binding: u32,
    type: Binding_Type,
}

Binding_Type :: enum {
    
}
