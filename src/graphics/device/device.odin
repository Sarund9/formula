package graphics_device


import "formula:host"


API :: struct {
    inititialize: proc(opt: Opt, mainWindow: host.Window),
    shutdown: proc(),

    // begin_pass, end_pass: proc(canvas: ^Canvas, pass: Pass),

    present: proc(^Canvas, host.Window),

    collect: proc(),

    canvas: struct {
        create: proc(desc: Canvas_Desc) -> ^Canvas,
        dispose: proc(^Canvas),

        begin: proc(^Canvas) -> Cmd,
        end: proc(^Canvas),

        // bind: proc(
        //     ptr: ^Canvas,

        //     set, slot: u32,
        //     binding: Binding,
        // ),

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

Cmd :: struct {
    using _vtable: ^ICommand,
    ptr: rawptr,
}

ICommand :: struct {
    use: proc(self: ^Cmd, program: ^Program),
    write: proc(self: ^Cmd, set, slot: u32, binding: Binding),
    update: proc(self: ^Cmd),
    push: proc(self: ^Cmd, data: rawptr),
    dispatch: proc(self: ^Cmd, x, y, z: u32),
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
    using size: struct {
        width, height: u32,
    },
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
    push_uniforms: Push_Uniform_Desc,
}

Shader_Desc :: struct {
    module: Shader_Module,
    stage: Shader_Stage,
    entrypoint: cstring,
}

Binding :: union {
    ^Canvas, // Bind the drawing image as IMAGE_STORAGE
}

Binding_Desc :: struct {
    binding: u32,
    type: Binding_Type,
}

Binding_Type :: enum {
    ImageStorage,
}

Push_Uniform_Desc :: struct {
    size: u32,
}
