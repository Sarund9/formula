//#+private
package host


import "base:runtime"
import "core:fmt"
import "core:unicode/utf16"
import "core:log"

import win "core:sys/windows"
foreign import user32 "system:User32.lib"

import cm "formula:common"
import vk "vendor:vulkan"

@(default_calling_convention="system")
foreign user32 {

    GetWindowLongPtrA :: proc(hWnd: win.HWND, nIndex: win.INT) -> win.LONG_PTR ---

    SetWindowLongPtrA :: proc(hWnd: win.HWND, nIndex: win.INT, ptr: win.LONG_PTR) ---
}


System_State :: struct {
    instance: win.HMODULE,
    classname: []u16,
    
    vk_dll: win.HMODULE,
}

_initialize :: proc() {
    using global

    // log.info("Initializing")

    // Initialize
    {
        CLASS_NAME :: "FormulaWindowClass"

        instance = win.GetModuleHandleW(nil)

        classname = win.utf8_to_utf16(CLASS_NAME, context.allocator)
    }

    // Register Class
    {
        class := win.WNDCLASSEXW {
            cbSize = size_of(win.WNDCLASSEXW),
            style = win.CS_SAVEBITS,
            lpfnWndProc = _windowProc,
            hInstance = nil,
            lpszClassName = raw_data(classname),
            // hIcon = win.LoadIconW(nil,
            //     transmute(win.wstring) win.IDI_WINLOGO),
            // TODO: Cursors, proper Icons
            cbWndExtra = size_of([]u16) + 4,
        }

        win.RegisterClassExW(&class)
    }

}

_shutdown :: proc() {
    using global

    win.UnregisterClassW(raw_data(classname), nil)

    delete(classname)
    
    if vk_dll != nil {
        win.FreeLibrary(vk_dll)
    }
}

Backing_Window :: struct {
    // NOTE: This should not exceed 40 bytes.
    title: []u16, // 16

}

_create_window :: proc(desc: Window_Desc) -> Window {
    using global
    style := (win.WS_OVERLAPPEDWINDOW)

    windowtitle := win.utf8_to_utf16(desc.title, context.allocator)

    handle := win.CreateWindowW(
        raw_data(classname),     // class
        raw_data(windowtitle),   // title
        style,                   // window style
        win.CW_USEDEFAULT,       // X
        win.CW_USEDEFAULT,       // Y
        i32(desc.width), i32(desc.height), // width, height
        nil, nil, nil,           // parent, menu, instance
        nil,
    )

    bytes := transmute([2]uintptr) windowtitle

    SetWindowLongPtrA(handle, 0, cast(win.LONG_PTR) bytes[0])
    SetWindowLongPtrA(handle, size_of(uintptr), cast(win.LONG_PTR) bytes[1])

    win.ShowWindow(handle, win.SW_SHOW)

    return Window(handle)
}

_windowProc :: proc "system" (
    hWnd: win.HWND, message: win.UINT,
    wparam: win.WPARAM, lparam: win.LPARAM,
) -> win.LRESULT {
    using win
    switch message {
    case WM_KEYDOWN:
        if wparam == VK_F11 {
            // setfullscreen(state, !state.isFullscreen)
        }
        // data := transmute(KeyDownData) i32(lparam)

        // context = runtime.default_context()
        // fmt.println("DATA:", data)

        // if !data.prevKeyState {
        //     push_event(KeyPressed {
        //         key = CodeMap[wparam] or_else .Unknown,
        //     })
        // } else {
        //     push_event(KeyRepeat {
        //         key = CodeMap[wparam] or_else .Unknown,
        //     })
        // }


    case WM_KEYUP:

        // push_event(KeyReleased {
        //     key = CodeMap[wparam] or_else .Unknown,
        // })
    case WM_CLOSE:
        DestroyWindow(hWnd)
    case WM_SIZE:
        // using _state
        // switch wparam {
        // case SIZE_RESTORED:
        //     if .Minimized in flags {
        //         flags -= { .Minimized }
        //     } else {
        //         flags -= { .Maximized }
        //     }
        // case SIZE_MAXIMIZED:
        //     flags += { .Maximized }
        // case SIZE_MINIMIZED:
        //     flags += { .Minimized }
        // case: // Resized
        //     resized = _getsize()
        // }
    
    case WM_DESTROY:
        // TODO: Only quit when ALL windows are closed.
        PostQuitMessage(0)
        return 0
    }

    return DefWindowProcW(hWnd, message, wparam, lparam)
}

_destroy_window :: proc(window: Window) {
    handle := win.HWND(window)

    // Delete title stored in extended Memory.
    {
        bytes: [2]int
        bytes.x = GetWindowLongPtrA(handle, 0)
        bytes.y = GetWindowLongPtrA(handle, size_of(uintptr))
        
        title := transmute([]u16) bytes
        
        delete(title)
    }

    win.DestroyWindow(handle)
}

_process :: proc() {
    using global, win
    msg: MSG

    for PeekMessageW(&msg, nil, 0, 0, PM_REMOVE) {
        switch msg.message {
        case WM_QUIT:
            push_event(Event_App.Quit)
            return
        }

        TranslateMessage(&msg)
        DispatchMessageW(&msg)
    }
}

_load_vulkan :: proc () -> rawptr {
    global.vk_dll = win.LoadLibraryW(win.utf8_to_wstring("vulkan-1.dll"));

    return auto_cast win.GetProcAddress(global.vk_dll, "vkGetInstanceProcAddr");
}

_create_vulkan_surface :: proc(
    window: Window,
    instance: vk.Instance, allocatorCallbacks: ^vk.AllocationCallbacks,
) -> (surf: vk.SurfaceKHR, res: vk.Result) {
    handle := win.HWND(window)

    createInfo := vk.Win32SurfaceCreateInfoKHR {
        sType = .WIN32_SURFACE_CREATE_INFO_KHR,
        hwnd = handle,
        hinstance = auto_cast global.instance,
    }
    // surf: vk.SurfaceKHR
    res = vk.CreateWin32SurfaceKHR(instance, &createInfo, allocatorCallbacks, &surf)

    return
}

_window_size :: proc(window: Window) -> cm.Vec2 {
    handle := win.HWND(window)

    rect: win.RECT

    win.GetWindowRect(handle, &rect)

    return {
        f32(rect.right - rect.left),
        f32(rect.bottom - rect.top),
    }
}

_window_is_minimized :: proc(window: Window) -> bool {
    handle := win.HWND(window)

    return auto_cast win.IsIconic(handle)
}
