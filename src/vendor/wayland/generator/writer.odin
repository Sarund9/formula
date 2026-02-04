package formula_wayland_generator

import "core:text/regex"
import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:strings"

import "core:io"

// import ref ".."


SPACING :: "    "
LINE_ENDING :: "\n"

@(private = "file")
indent: int

@(private = "file")
signs: struct {
	interface_ids:     map[string]u16,
	next_interface_id: u16, //
	lookup:            map[string]int, // Actual index in the array where the signature exists.
	array:             [dynamic]string, // Array containing singnatures.
}

@(private = "file")
type_names: map[string]string

TYPE_PATTERN :: `\swl_\w+`

@(private = "file")
name_finder: regex.Regular_Expression

// @(private="file")
// get_sign :: proc(sign: string) -> int {
//     index, exists := signs.lookup[sign]

//     // If it does not exist, create it.
//     if !exists {
//         // Start here
//         index = len(signs.array)
//         signs.lookup[sign] = index

//         // Create the Signature..
//         for ch in sign {
//             switch ch {
//             case 'n', 'o': // Object ID and NewID both are of Interface Type
//                 append(&signs.array, "nil")
//             case:
//                 append(&signs.array, "nil")
//             }
//         }
//     }

//     return index
// }

@(private = "file")
begin :: proc(w: io.Writer) {
	for _ in 0 ..< indent {
		io.write_string(w, SPACING)
	}
}

@(private = "file")
end :: proc(w: io.Writer) {
	io.write_string(w, LINE_ENDING)
}

@(private = "file")
field :: proc(w: io.Writer, name, value: string) {
	begin(w)
	io.write_string(w, name)
	io.write_string(w, ` = `)
	io.write_string(w, value)
	io.write_byte(w, ',')
	end(w)
}

/* Implementation Code:

sign_lookup := []^ref.Interface {
	nil,
	&iwl_callback,
	nil,
	&iwl_callback,
	nil,
	&iwl_callback,
	nil,
	&iwl_callback,

}

iwl_callback := ref.Interface {
	"wl_callback",
	1,
	0,
	nil,
	1,
	cast([^]ref.Message)&[]ref.Message {
		// { "done", "u", cast(^^ref.Interface) &[?]^ref.Interface { nil }},
		{"done", "u", &sign_lookup[0]},
	},
}
*/

write_private_file :: proc(w: io.Writer) {
	io.write_string(w, "//#+private\npackage formula_vendor_wayland\n\n")
    indent = 0

	// Precache all Signatures
	for interface in interfaces {

		for request in interface.requests {
			// flat := flat_signature(request.arguments[:])
			// get_sign(flat)
			// sign := call_signature(request.arguments[:])
			// get_sign(sign)
			add_signature(request.arguments[:])
		}
		for event in interface.events {
			// flat := flat_signature(event.arguments[:])
			// get_sign(flat)
			// sign := call_signature(event.arguments[:])
			// get_sign(sign)
			add_signature(event.arguments[:])
		}

		prefix, name: string
		{
			index := strings.index(interface.name, "_")
			if index < 0 {
				prefix, name = "", interface.name
			} else {
				prefix, name = interface.name[:index+1], interface.name[index+1:]
			}
		}

		b := strings.builder_make()
		defer strings.builder_destroy(&b)

		name_ada := strings.to_ada_case(name, context.temp_allocator)

		switch prefix {
		case "", "wl_":
			strings.write_string(&b, name_ada)
			// strings.write_string(&b, name_ada)
		case:
			strings.write_string(&b, strings.to_upper(prefix, context.temp_allocator))
			// strings.write_string(&b, "_")
			strings.write_string(&b, name_ada)
			// fmt.printfln("TYPE: {} -> {}", interface.name, strings.to_string(b))
		}

		// 
		type_names[interface.name] = strings.clone(strings.to_string(b))
		// type_names[interface.name] = strings.to_ada_case(skip_wl_prefix(interface.name))
	}

	add_signature :: proc(args: []Arg) {
		flat := flat_signature(args)

		if flat in signs.lookup {
			return
		}

		index := len(signs.array)
		signs.lookup[flat] = index

		for arg in args {
			if arg.interface == "" {
				append(&signs.array, "")
			} else {
				append(&signs.array, arg.interface)
			}
		}
	}

	// Write the sign_lookup
	/*
    sign_lookup := []^ref.Interface {
        nil,
        &iwl_callback,
    }
    */

	io.write_string(w, fmt.tprintln("// Lookup Size:", len(signs.array)))

	io.write_string(w, "sign_lookup: [")
	io.write_int(w, len(signs.array))
	io.write_string(w, "]^Interface = {\n")
	indent += 1
	for elem in signs.array {
		begin(w)
        if elem == "" {
            io.write_string(w, "nil")
        } else {
            io.write_string(w, "&i")
            io.write_string(w, elem)
        }
        io.write_byte(w, ',')
		end(w)
	}
	indent -= 1
	io.write_string(w, "}\n\n")


	for interface in interfaces {
		// fmt.println("============= INTERFACE =============")
		write_interface_impl(w, interface)
	}
}

write_interface_impl :: proc(w: io.Writer, interface: Interface) {

	{
		io.write_byte(w, 'i')
		io.write_string(w, interface.name)

		io.write_string(w, " := Interface {\n")
		indent += 1

		// Name
		begin(w)
		io.write_string(w, "name = ")
		io.write_quoted_string(w, interface.name)
		io.write_string(w, ",")
		end(w)

		// Version
		begin(w)
		io.write_string(w, "version = ")
		io.write_int(w, int(interface.version))
		io.write_byte(w, ',')
		end(w)

		// Requests
		{
			begin(w)
			io.write_string(w, "method_count = ")
			io.write_int(w, len(interface.requests))
			io.write_byte(w, ',')
			end(w)

			begin(w)
			if len(interface.requests) > 0 {
				io.write_string(w, "methods = &i")
				io.write_string(w, interface.name)
				io.write_string(w, "_methods[0]")
				io.write_byte(w, ',')
			} else {
				io.write_string(w, "methods = nil,")
			}
			end(w)
		}
		// Events
		{
			begin(w)
			io.write_string(w, "event_count = ")
			io.write_int(w, len(interface.events))
			io.write_byte(w, ',')
			end(w)

			begin(w)
			if len(interface.events) > 0 {
				io.write_string(w, "events = &i")
				io.write_string(w, interface.name)
				io.write_string(w, "_events[0]")
				io.write_byte(w, ',')
			} else {
				io.write_string(w, "events = nil,")
			}
			end(w)
		}
		// write_message_field(w, interface, interface.requests[:])
		// write_message_field(w, interface, interface.events[:])

		// Events
		indent -= 1
		io.write_string(w, "}\n\n")
	}

	if len(interface.requests) > 0 {
		write_message_list(w, interface, false, interface.requests[:])
	}
	if len(interface.events) > 0 {
		write_message_list(w, interface, true, interface.events[:])
	}

	write_message_list :: proc(w: io.Writer, interface: Interface, is_events: bool, messages: []Message) {
		io.write_string(w, "i")
		io.write_string(w, interface.name)
		if !is_events {
			io.write_string(w, "_methods")
		} else {
			io.write_string(w, "_events")
		}
		io.write_string(w, " := [?]Message {\n")
		indent += 1

		for message in messages {
			begin(w)

			// Write acual Message
			io.write_string(w, "{ ")

			io.write_quoted_string(w, message.name)
			io.write_string(w, ", ")

			sign := call_signature(message.arguments[:])
			io.write_quoted_string(w, sign)
			io.write_string(w, ", ")

			flat := flat_signature(message.arguments[:])

			if len(sign) == 0 {
				io.write_string(w, "nil")
			} else {
				flat := flat_signature(message.arguments[:])
				// index := get_sign(sign)
				index, exists := signs.lookup[flat]

				fmt.assertf(exists, "Missing sign ID for {} ", message.name)

				io.write_string(w, "&sign_lookup[")
				io.write_int(w, index)
				io.write_string(w, "]")
			}
			io.write_string(w, " },")

			end(w)
		}


		indent -= 1
		io.write_string(w, "}\n\n")
	}

	write_message_field :: proc(w: io.Writer, interface: Interface, messages: []Message) {
		begin(w)
		io.write_int(w, len(messages))
		io.write_string(w, ", &i")
		io.write_string(w, interface.name)
		io.write_string(w, "_methods")

		if len(messages) == 0 {
			io.write_string(w, "nil")
		} else {
			io.write_string(w, "cast([^]Message) &[?]Message {")
			end(w)
			indent += 1
			for message in messages {
				begin(w)

				// Write acual Message
				io.write_string(w, "{ ")

				io.write_quoted_string(w, message.name)
				io.write_string(w, ", ")

				sign := call_signature(message.arguments[:])
				io.write_quoted_string(w, sign)
				io.write_string(w, ", ")

				flat := flat_signature(message.arguments[:])

				if len(sign) == 0 {
					io.write_string(w, "nil")
				} else {
					flat := flat_signature(message.arguments[:])
					// index := get_sign(sign)
					index, exists := signs.lookup[flat]

					fmt.assertf(exists, "Missing sign ID for {} ", message.name)

					io.write_string(w, "&sign_lookup[")
					io.write_int(w, index)
					io.write_string(w, "]")
				}
				io.write_string(w, " },")

				end(w)
			}
			indent -= 1

			begin(w)
			io.write_byte(w, '}')
		}
		io.write_byte(w, ',')
		end(w)
	}

	/*
	CURRENT:
	iwl_registry := Interface {
		"wl_registry", 1,
		1, cast([^]Message) &[?]Message {
			{ "bind", "un", &sign_lookup[5] },
		},
		2, cast([^]Message) &[?]Message {
			{ "global", "usu", &sign_lookup[2] },
			{ "global_remove", "u", &sign_lookup[0] },
		},
	}
	NEW:
	iwl_registry := Interface {
		"wl_registry", 1,
		1, &iwl_registry_methods[0],
		2, cast([^]Message) &[?]Message {
			{ "global", "usu", &sign_lookup[2] },
			{ "global_remove", "u", &sign_lookup[0] },
		},
	}
	iwl_registry_methods := [?]Message {
		{ "bind", "un", &sign_lookup[5] },
	}
	*/

}

write_public_file :: proc(w: io.Writer) {
	io.write_string(w, "package formula_vendor_wayland\n\n")
    indent = 0

	err: regex.Error
	name_finder, err = regex.create(`\swl_\w+`, { .Unicode })
	fmt.assertf(err == nil, "Regex Error: {}", err)

	// listener_objects := make([dynamic]string)
	// defer delete(listener_objects)

	for interface in interfaces {
		if interface.name == "" {
			continue
		}

		// Exeption for wl_display
		if interface.name != "wl_display" {
			write_interface_type(w, interface)
		}

		write_generic_procedures(w, interface)

		// Write listener type
		if len(interface.events) > 0 {
			write_listener(w, interface)
		}

		// TODO: enums


		// Write Requests
		for request in interface.requests {
            write_request_procedure(w, interface, request)
        }

		io.write_string(w, "\n")
	}

	// Procedure Grups
	indent += 1

	// Get Set Version
	{
		io.write_string(w, "get_user_data :: proc {\n")
		for interface in interfaces {
			begin(w)
			io.write_string(w, skip_wl_prefix(interface.name))
			io.write_string(w, "_get_user_data,")
			end(w)
		}
		io.write_string(w, "}\n\n")

		io.write_string(w, "set_user_data :: proc {\n")
		for interface in interfaces {
			begin(w)
			io.write_string(w, skip_wl_prefix(interface.name))
			io.write_string(w, "_set_user_data,")
			end(w)
		}
		io.write_string(w, "}\n\n")

		io.write_string(w, "get_version :: proc {\n")
		for interface in interfaces {
			begin(w)
			io.write_string(w, skip_wl_prefix(interface.name))
			io.write_string(w, "_get_version,")
			end(w)
		}
		io.write_string(w, "}\n\n")
	}

	// add_listener
	{
		io.write_string(w, "add_listener :: proc {\n")
		
		for interface in interfaces {
			if len(interface.events) == 0 {
				continue
			}

			begin(w)
			io.write_string(w, skip_wl_prefix(interface.name))
			io.write_string(w, "_add_listener,")
			end(w)
		}

		io.write_string(w, "}\n\n")
	}

	indent -= 1
}

write_interface_type :: proc(w: io.Writer, interface: Interface) {
	object_name := skip_wl_prefix(interface.name)
	type_name := interface_name(interface.name)

	write_interface_description(w, interface)

	io.write_string(w, type_name)
	io.write_string(w, " :: struct {}\n\n")
}

write_generic_procedures :: proc(w: io.Writer, interface: Interface) {

	object_name := skip_wl_prefix(interface.name)
	type_name := interface_name(interface.name)

	// Proxy Procedures
	// get_user_data: (object) -> ptr
	// set_user_data: (object, ptr)
	// version: (object) -> u32

	// Get User Data
	io.write_string(w, object_name)
	io.write_string(w, `_get_user_data :: proc "contextless" (`)
	io.write_string(w, object_name)
	io.write_string(w, ": ^")
	io.write_string(w, type_name)
	io.write_string(w, ") -> rawptr {\n")
	indent += 1
	begin(w)
	io.write_string(w, "return proxy_get_user_data(auto_cast ")
	io.write_string(w, object_name)
	io.write_string(w, ")")
	end(w)
	indent -= 1
	io.write_string(w, "}\n\n")

	// Set User Data
	io.write_string(w, object_name)
	io.write_string(w, `_set_user_data :: proc "contextless" (`)
	io.write_string(w, object_name)
	io.write_string(w, ": ^")
	io.write_string(w, type_name)
	io.write_string(w, ", user_data: rawptr")
	io.write_string(w, ") {\n")
	indent += 1
	begin(w)
	io.write_string(w, "proxy_set_user_data(auto_cast ")
	io.write_string(w, object_name)
	io.write_string(w, ", user_data)")
	end(w)
	indent -= 1
	io.write_string(w, "}\n\n")

	// Get Version
	io.write_string(w, object_name)
	io.write_string(w, `_get_version :: proc "contextless" (`)
	io.write_string(w, object_name)
	io.write_string(w, ": ^")
	io.write_string(w, type_name)
	io.write_string(w, ") -> u32 {\n")
	indent += 1
	begin(w)
	io.write_string(w, "return proxy_get_version(auto_cast ")
	io.write_string(w, object_name)
	io.write_string(w, ")")
	end(w)
	indent -= 1
	io.write_string(w, "}\n\n")
}

write_listener :: proc(w: io.Writer, interface: Interface) {

	write_event_listener_description(w, interface)

	assert(interface.name != "")

	// object_name: string
	object_name := skip_wl_prefix(interface.name)
	type_name := interface_name(interface.name)

	io.write_string(w, type_name)

	io.write_string(w, "_Listener :: struct {")
	indent += 1

	// Padding
	total_padding := 4
	for event in interface.events {
		minimum := len(event.name) + 2
		if minimum > total_padding {
			total_padding = minimum
		}
	}

	// Fields
	for event in interface.events {
		// TODO: Descriptions..

		io.write_string(w, "\n")

		// Procedure Signature:
		//  data
		//  object
		//  .. arguments
		write_event_procedure_description(w, interface, event)

		// Actual Field
		begin(w)

		io.write_string(w, event.name)
		io.write_byte(w, ':')
		pad := max(total_padding - len(event.name), 0)
		for _ in 0..<pad {
			io.write_byte(w, ' ')
		}

		io.write_string(w, "proc \"c\" (")

		// Userdata
		io.write_string(w, "data: rawptr, ")

		// Listened Object
		io.write_string(w, object_name)
		io.write_string(w, ": ^")
		io.write_string(w, type_name)

		// Arguments
		for arg in event.arguments {
			io.write_string(w, ", ")

			write_argument_field(w, arg)
		}

		io.write_string(w, "),")
		end(w)
	}

	indent -= 1

	io.write_string(w, "}\n\n")


	// Add Listener Function

	// proc(^object, ^listener, ^user_data)

	io.write_string(w, object_name)
	io.write_string(w, "_add_listener :: proc(")
	io.write_string(w, object_name)
	io.write_string(w, ": ^")
	io.write_string(w, type_name)
	io.write_string(w, ", listener: ^")
	io.write_string(w, type_name)
	io.write_string(w, "_Listener, user_data: rawptr")
	io.write_string(w, ") -> i32 {\n")

	indent += 1
	begin(w)
	io.write_string(w, "return proxy_add_listener(auto_cast ")
	io.write_string(w, object_name)
	io.write_string(w, ", auto_cast listener, user_data)")
	end(w)
	indent -= 1

	io.write_string(w, "}\n\n")
}

write_request_procedure :: proc(w: io.Writer, interface: Interface, request: Message) {
	object_name := skip_wl_prefix(interface.name)

	write_message_procedure_description(w, interface, request)

	// Procedure Name
	io.write_string(w, object_name)
	io.write_string(w, "_")
    io.write_string(w, request.name)

    io.write_string(w, " :: proc(")

	// Add first argument: object type
	io.write_string(w, object_name)
	io.write_string(w, ": ^")
	io.write_string(w, type_names[interface.name])
	
	// Get Result Type
    indent += 1
	result: Maybe(Arg)

	dynamic_arg := request.dynamic_bind.? or_else -1

	// Input Parameters
    for arg, idx in request.arguments {
        if arg.type == .New_Id {
			fmt.assertf(result == nil, "Double return type not Supported, {}::{}", interface.name, request.name)
			result = arg
            // append(&results, idx)
			continue
        }
		io.write_string(w, ", ")

		if dynamic_arg > -1 {
			if idx == dynamic_arg {
				io.write_string(w, "interface: ^Interface")
				continue
			}
			if idx == dynamic_arg + 2 {
				
			}
		}

		write_argument_field(w, arg)
    }

    io.write_string(w, ")")

	// Return Types.
	return_var: string
	if arg, ok := result.?; ok {
		io.write_string(w, " -> (")
		// fmt.assertf(arg.interface != "", "NewID no Interface? {}::{}", object_name, request.name)
		if arg.interface == "" {
			io.write_string(w, "object: rawptr")
			return_var = "object"
		} else {
			return_var = skip_wl_prefix(arg.interface)
			io.write_string(w, return_var)
			io.write_string(w, ": ^")
			io.write_string(w, interface_name(arg.interface))
		}

		io.write_byte(w, ')')
	}

    io.write_string(w, " {\n")

	begin(w)

	if arg, ok := result.?; ok {
		io.write_string(w, return_var)
		io.write_string(w, " = auto_cast ")
	}
	// Proxy Call
	io.write_string(w, "proxy_marshal_flags(")

	// Call Arguments
	{
		// Proxy Object
		io.write_string(w, "auto_cast ")
		io.write_string(w, object_name)
		io.write_string(w, ", ")

		// Opcode
		io.write_int(w, request.opcode)
		io.write_string(w, ", ")

		// Interface
		if dynamic_arg < 0 {
			io.write_string(w, "&i")
			io.write_string(w, interface.name)
		} else {
			io.write_string(w, "interface")
		}
		io.write_string(w, ", ")

		// Version, Flags
		if dynamic_arg < 0 {
			io.write_string(w, "proxy_get_version(auto_cast ")
			io.write_string(w, object_name)
			io.write_byte(w, ')')
		} else {
			io.write_string(w, "version")
		}
		
		io.write_string(w, ", 0") // Flags

		// Arguments
		for arg, idx in request.arguments {
			if arg.type == .New_Id {
				io.write_string(w, ", nil")
				continue
			}


			io.write_string(w, ", ")

			io.write_string(w, arg.name)

			// This is the string argument, that must be replaced with interface.name
			if idx == dynamic_arg {
				io.write_string(w, ".name")
			}
		}

		/*
		void* registry_bind(Registry* registry, u32 name, Interface* interface, u32 version)
		{
			id: *Proxy

			id = proxy_marshal_flags((struct wl_proxy *) registry,
					WL_REGISTRY_BIND, interface, version, 0, name, interface->name, version, NULL);

			return (void *) id;
		}

		*/
	}

	io.write_string(w, ")")

    end(w)

	// Return Statement
	begin(w)
	io.write_string(w, "return")
	end(w)

    io.write_string(w, "}\n\n")

    indent -= 1

	// switch len(results) {
	// case 0:
	// case 1:
		
	// case:
	// 	fmt.panicf("Multiple results not implemented {}::{}", interface.name, request.name)
	// }
}

write_argument_field :: proc(w: io.Writer, arg: Arg) {
	io.write_string(w, arg.name)
	io.write_string(w, ": ")
	
	switch arg.type {
	case .Int:
		io.write_string(w, "i32")
	case .UInt:
		io.write_string(w, "u32")
	case .Fixed:
		io.write_string(w, "Fixed")
	case .String:
		io.write_string(w, "cstring")
	case .Object, .New_Id:
		if arg.interface == "" {
			io.write_string(w, "rawptr")
		} else {
			io.write_byte(w, '^')
			name := interface_name(arg.interface)
			io.write_string(w, name)
		}
		// append(&results, idx)
		// fmt.assertf(idx < 0, "Duplicate IDX on procedure: {}", request.name)
		// result = idx
	case .Array:
		// TODO: How does array work ?
		io.write_string(w, "[]rawptr")
	case .FD:
		io.write_string(w, "rawptr")
	}
}

/*  #### Fixes - wl_fixes

	*Writes a Description comment*
	
    Writes a Description text as a logn comment
*/
write_interface_description :: proc(w: io.Writer, interface: Interface) {
	io.write_string(w, "/* \n")
	io.write_string(w, "Summary: *")
	io.write_string(w, interface.desc.summary)
	io.write_string(w, "*\n")

	io.write_string(w, "___")

	write_description_contents(w, interface.desc)

	// io.write_string(w, strings.to_string(desc.contents))
	io.write_string(w, "\n*/\n")
}

write_event_listener_description :: proc(w: io.Writer, interface: Interface) {
	io.write_string(w, "// Event listener of ")
	io.write_string(w, type_names[interface.name])
	io.write_string(w, "\n")
}

write_event_procedure_description :: proc(w: io.Writer, interface: Interface, event: Message) {
	io.write_string(w, "    /* Summary: *")
	io.write_string(w, event.desc.summary)
	io.write_string(w, "*\n")

	io.write_string(w, "    ___") // Horizontal Divider

	write_description_contents(w, event.desc, "    ")

	io.write_string(w, "*/\n")
}

write_message_procedure_description :: proc(w: io.Writer, interface: Interface, message: Message) {
	io.write_string(w, "/* \n")
	io.write_string(w, "Summary: *")
	io.write_string(w, message.desc.summary)
	io.write_string(w, "*\n\n")

	object_name := skip_wl_prefix(interface.name)
	type_name := type_names[interface.name]

	io.write_string(w, "Inputs:\n")
	io.write_string(w, "- ")
	io.write_string(w, object_name)
	io.write_string(w, ": A pointer to the ")
	io.write_string(w, type_name)
	io.write_string(w, "\n")

	return_arg := -1
	for arg, idx in message.arguments {
		if arg.type == .New_Id {
			return_arg = idx
			continue
		}
		io.write_string(w, "- ")
		io.write_string(w, arg.name)
		io.write_string(w, ": ")
		io.write_string(w, arg.summary)
		io.write_string(w, "\n")
	}

	if return_arg > -1 {
		io.write_string(w, "\n")
		io.write_string(w, "Returns: ")
		arg := message.arguments[return_arg]
		// io.write_string(w, "- ")
		// io.write_string(w, arg.name)
		// io.write_string(w, ": ")
		io.write_string(w, arg.summary)
		io.write_string(w, "\n")
	}
	io.write_string(w, "___")

	write_description_contents(w, message.desc)

	io.write_string(w, "\n*/\n")
}

write_description_contents :: proc(w: io.Writer, desc: Description, line_prefix := "") {
	contents := strings.to_string(desc.contents)

	// Use a regex: wl_

	names_to_replace := make(map[string]int)
	defer delete(names_to_replace)

	{
		it, err := regex.create_iterator(contents, TYPE_PATTERN)
		fmt.assertf(err == nil, "Regex Error:", err)

		defer regex.destroy_iterator(it)

		for capture, idx in regex.match_iterator(&it) {
			// fmt.println("REPLACE:", capture.groups)
			for g in capture.groups {
				name := g[1:]
				if name in type_names && name not_in names_to_replace {
					names_to_replace[name] = 0
					// fmt.println("Will replace", name, "->", type_names[name])
				}
			}
		}

	}
	
	for line in strings.split_iterator(&contents, "\n") {
		processed := strings.clone(line)
		defer delete(processed)

		// Replace
		for name, _ in names_to_replace {
			type_name := type_names[name]

			prev := processed
			was_allocation: bool
			processed, was_allocation = strings.replace_all(processed, name, type_name, )
			if was_allocation {
				// Then processed replaced prev, and prev must be deleted
				delete(prev)
			}
		}

		trimmed := strings.trim(processed, " \t\n\r")

		io.write_string(w, "\n")
		io.write_string(w, line_prefix)
		io.write_string(w, trimmed)
	}
}

skip_wl_prefix :: proc(wl_name: string) -> string {

	if len(wl_name) < 4 {
		return wl_name
	}

	if wl_name[:3] == "wl_" {
		return wl_name[3:]
	}

	return wl_name

	// index := -1
	// for ch, idx in wl_name {
	// 	if ch == '_' {
	// 		index = idx
	// 		break
	// 	}
	// }

	// if index < 0 {
	// 	return wl_name
	// }

	// if index >= len(wl_name) - 2 {
	// 	return wl_name
	// }

	// return wl_name[index+1:]
}

skip_any_prefix :: proc(name: string) -> string {
	index := -1
	for ch, idx in name {
		if ch == '_' {
			index = idx
			break
		}
	}

	if index < 0 {
		return name
	}

	if index >= len(name) - 2 {
		return name
	}

	return name[index+1:]
}

interface_name :: proc(wl_name: string) -> string {
	return type_names[wl_name]
}

call_signature :: proc(args: []Arg, allocator := context.temp_allocator) -> string {
	b := strings.builder_make(context.temp_allocator)

	for arg in args {
		c: byte
		switch arg.type {
		case .Int:
			c = 'i'
		case .UInt:
			c = 'u'
		case .Fixed:
			c = 'f'
		case .String:
			c = 's'
		case .Object:
			c = 'o'
		case .New_Id:
			c = 'n'
		case .Array:
			c = 'a'
		case .FD:
			c = 'h'
		}
		strings.write_byte(&b, c)
		// strings.write_string(b, )
	}

	return strings.to_string(b)
}

@(private = "file")
flat_signature :: proc(args: []Arg, allocator := context.temp_allocator) -> string {
	sign := make([dynamic]byte)
	defer delete(sign)

	for arg in args {
		if arg.interface == "" {
			append(&sign, 0)
			append(&sign, 0)
		} else {
			id, exists := signs.interface_ids[arg.interface]
			if !exists {
				id = signs.next_interface_id
				signs.interface_ids[arg.interface] = signs.next_interface_id
				assert(
					signs.next_interface_id < max(u16),
					"Ran out of IDs for Wayland Interfaces!",
				)
				signs.next_interface_id += 1
			}

			bytes := transmute([2]byte)id
			append(&sign, bytes.x)
			append(&sign, bytes.y)
		}
	}

	return string(slice.clone(sign[:], allocator))
}


// switch len(results) {
// case 0:
// case 1:
// 	io.write_string(w, " -> (")
// 	idx := results[0]
// 	arg := request.arguments[idx]
// 	// fmt.assertf(arg.interface != "", "NewID no Interface? {}::{}", object_name, request.name)
// 	if arg.interface == "" {
// 		io.write_string(w, "object: rawptr")
// 		return_var = "object"
// 	} else {
// 		return_var = skip_wl_prefix(arg.interface)
// 		io.write_string(w, return_var)
// 		io.write_string(w, ": ^")
// 		io.write_string(w, interface_name(arg.interface))
// 	}

// 	io.write_byte(w, ')')
// case: // More
// 	fmt.panicf("Multiple results not implemented {}::{}", interface.name, request.name)
	
// }

// if len(results) > 0 {
// 	// if len(results) > 1 {
// 	// 	fmt.printf("Function {} returns {}", request.name, len(results))
// 	// }
// 	begin(w)
// 	io.write_string(w, "return nil")
// 	for _ in 0..<len(results)-1 {
// 		io.write_string(w, ", nil")
// 	}
// 	end(w)
// }

// if last_written_object {
// 	last_written_object = false
// 	io.write_string(w, ", ")
// }
// io.write_string(w, arg.name)
// io.write_string(w, ": ")
// switch arg.type {
// case .Int:
//     io.write_string(w, "i32")
// case .UInt:
//     io.write_string(w, "u32")
// case .Fixed:
//     io.write_string(w, "Fixed")
// case .String:
//     io.write_string(w, "string")
// case .Object:
//     // TODO: True Object Type..
//     io.write_string(w, "rawptr")
// case .New_Id:
//     unreachable()
//     // append(&results, idx)
//     // fmt.assertf(idx < 0, "Duplicate IDX on procedure: {}", request.name)
//     // result = idx
// case .Array:
//     // TODO: How does array work ?
//     io.write_string(w, "[]rawptr")
// case .FD:
//     io.write_string(w, "rawptr")
// }
// for idx, count in results {
// 	arg := request.arguments[results[idx]]
// 	// fmt.assertf(arg.interface != "", "NewID no Interface? {}::{}({})", object_name, request.name, idx)

// 	io.write_string(w, arg.name)
// 	io.write_string(w, ": ")
// 	if arg.interface == "" {
// 		io.write_string(w, "rawptr")
// 	} else {
// 		io.write_string(w, "^")
// 		io.write_string(w, interface_name(arg.interface))
// 	}

// 	if count == len(results) - 1 { break }

// 	io.write_string(w, ", ")
// }
// io.write_string(w, "-> (")
// io.write_string(w, ")")

// @(private="file")
// sign_flat :: proc(sign: string, allocator := context.temp_allocator) -> string {

//     data := transmute([]byte) strings.clone(sign)

//     for ch, idx in sign {
//         switch ch {
//         case 'n', 'o':
//         case:
//             data[idx] = ' ' // Space represents Null
//         }
//     }

//     return string(data)
// }

// Interface_Impl :: struct {
//     using interface: Interface,
//     msgs: []Message,
//     create: []^Interface,
// }

// Impl :: struct($T: typeid) {
//     using interface: ref.Interface,
//     msgs: []ref.Message,

//     using _arguments: T,
// }

// // The new Structure to Write.
// iwl_pointer: Impl(struct {
//     create: []^ref.Interface,
// }) = {
//     interface = {
//         "wl_callback", 1,
//         0, nil,
//         1, iwl_pointer.create[0],
//     },
//     msgs = {
//         { "", "", &iwl_pointer.create[0] },
//     },
//     create = {
//         nil,
//         nil,
//     },
// }

// defer io.write_string(w, "\n\n")

// Global Variable
// {
//     io.write_byte(w, 'i')
//     io.write_string(w, interface.name)
//     io.write_string(w, " := &Interface {\n")

//     indent += 1
//     field(w, `name`, fmt.tprintf("\"{}\"", interface.name))
//     field(w, `version`, fmt.tprint(interface.version))

//     indent -= 1

//     io.write_string(w, "}\n\n")
// }

// // Requests
// {
//     io.write_byte(w, 'i')
//     io.write_string(w, interface.name)
//     io.write_string(w, "_requests := []Message {\n")

//     indent += 1
//     for request in interface.requests {
//         begin(w)
//         io.write_byte(w, '{')
//         io.write_quoted_string(w, request.name)
//         io.write_string(w, ", ")

//         sign := call_signature(request.arguments[:])
//         io.write_quoted_string(w, sign)

//         io.write_string(w, ", ")

//         for arg in request.arguments {

//         }

//         io.write_byte(w, '}')
//         end(w)
//     }

//     io.write_string(w, "}\n\n")
// }
// io.write_string(w, "@(private=\"file\")\n")


// if capture, ok := regex.match(, contents); ok {
// 	fmt.println("REPLACE", len(capture.groups), "ELEMS")
// 	for g in capture.groups {
// 		if g in type_names && g not_in names_to_replace {
// 			names_to_replace[g] = 0
// 			fmt.println("Will replace", g, "->", type_names[g])
// 		}
// 	}
// }

// regex.match_iterator()
// name_finder

	
