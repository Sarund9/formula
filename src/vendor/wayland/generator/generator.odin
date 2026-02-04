package formula_wayland_generator

import "core:container/intrusive/list"
import "core:encoding/xml"
import "core:fmt"
import "core:strconv"
import "core:strings"

import "core:flags"
import "core:io"
import "core:os"


OUTPUT_FILE_PUBLIC :: "wayland-interface.odin"
OUTPUT_FILE_PRIVATE :: "wayland-glue.odin"

// Generation state
interfaces: [dynamic]Interface

Interface :: struct {
	name:     string,
	version:  i32,
	requests: [dynamic]Message,
	events:   [dynamic]Message,
	enums:    map[string]Enumerator,
	desc:     Description,
}

Message :: struct {
	name:            string,
	arguments:       [dynamic]Arg,
	opcode:          int,
	desc:            Description,
	// If N is not null, then `arguments[N:N+3]` are a dynamic NewID.
	// This means that the interface & version arguments of proxy_marshal_flags, are not of the
	//  the version of the object, but are rather N and N+1. Also, N will be of type string, but
	//  we will actually be sending a `^Interface`, and using it's `name` field.
	dynamic_bind: Maybe(int),
}

Arg :: struct {
	name, interface, summary: string,
	type:                     Type,
}

Type :: enum {
	Int,
	UInt,
	Fixed,
	String,
	Object,
	New_Id,
	Array,
	FD,
}

Enumerator :: struct {
	name:    string,
	entries: [dynamic]Entry,
	desc:    Description,
}

Entry :: struct {
	name:  string,
	value: i32,
}

Description :: struct {
	summary:  string,
	contents: strings.Builder,
}


main :: proc() {
	Options :: struct {
		// out: string `args:"required"`,
		overflow: [dynamic]string `usage:"Any extra arguments go here."`,
	}
	// Main arguments:
	//  paths

	opt: Options
	flags.parse_or_exit(&opt, os.args, .Odin, context.temp_allocator)

	// interfaces := make([dynamic]Interface)

	for file in opt.overflow {
		process_file(file)
	}

	// Create the Private file
	{
		if !os.is_file(OUTPUT_FILE_PRIVATE) {
			os.write_entire_file(OUTPUT_FILE_PRIVATE, {})
		}

		file, err := os.open(OUTPUT_FILE_PRIVATE, os.O_RDWR | os.O_TRUNC)
		fmt.assertf(err == nil, "Error opening file:", err)
		defer os.close(file)

		wr: io.Writer
		wr = io.to_writer(os.stream_from_handle(file))
		write_private_file(wr)
	}

	{
		if !os.is_file(OUTPUT_FILE_PUBLIC) {
			os.write_entire_file(OUTPUT_FILE_PUBLIC, {})
		}

		file, err := os.open(OUTPUT_FILE_PUBLIC, os.O_RDWR | os.O_TRUNC)
		fmt.assertf(err == nil, "Error opening file:", err)
		defer os.close(file)

		wr: io.Writer
		wr = io.to_writer(os.stream_from_handle(file))
		write_public_file(wr)
	}

}

print_interfaces :: proc() {

	for interface in interfaces {
		fmt.printf("interface {} v{} {{", interface.name, interface.version)
		if len(interface.events) == 0 && len(interface.requests) == 0 {
			fmt.print("}\n")
			continue
		}
		fmt.print("\n")
		defer fmt.print("}\n")

		if len(interface.requests) > 0 {
			fmt.print("\n")
		}

		for request in interface.requests {
			fmt.printf("  {}(", request.name)
			defer fmt.print(")\n")
			for arg, idx in request.arguments {
				fmt.printf("{}: {}", arg.name, arg.type)
				if arg.interface != "" {
					fmt.printf("[{}]", arg.interface)
				}
				if idx == len(request.arguments) - 1 {break}

				fmt.print(", ")
			}
		}

		if len(interface.events) > 0 {
			fmt.print("\n")
		}

		for event in interface.events {
			fmt.printf("  {} {{ ", event.name)
			defer fmt.print(" }\n")
			for arg, idx in event.arguments {
				fmt.printf("{}: {}", arg.name, arg.type)
				if arg.interface != "" {
					fmt.printf("[{}]", arg.interface)
				}
				if idx == len(event.arguments) - 1 {break}

				fmt.print(", ")
			}
		}

		if len(interface.enums) > 0 {
			fmt.print("\n")
		}

		for name, enumertator in interface.enums {
			fmt.printf("  {} [\n", name)

			defer fmt.print("  ]\n")

			for entry in enumertator.entries {
				fmt.printfln("    {} = {}", entry.name, entry.value)
			}
		}
	}
}

process_file :: proc(file: string) {

	doc, err := xml.load_from_file(file)

	if err != .None {
		fmt.eprintfln("Error reading {}:\n     {}", file, err)
		return
	}
	defer xml.destroy(doc)

	if doc.element_count == 0 {
		fmt.eprintfln("Error reading {}:\n     File has no Elements!", file)
		return
	}

	first := &doc.elements[0]

	// print_document(doc, first)

	for child in first.value {
		#partial switch idx in child {
		case xml.Element_ID:
			child := &doc.elements[idx]
			if child.ident == "interface" {
				// TODO: This function should return an Error.
				interface := process_interface(doc, child)
				append(&interfaces, interface)
			}
		}
	}
}

process_interface :: proc(doc: ^xml.Document, elem: ^xml.Element) -> Interface {
	assert(elem.ident == "interface")
	interface: Interface

	for attr in elem.attribs {
		switch attr.key {
		case "name":
			interface.name = strings.clone(attr.val)
		case "version":
			val, ok := strconv.parse_int(attr.val)
			if ok {
				interface.version = i32(val)
			} else {
				// TODO: Error
				panic("Invalid version Value")
			}
		}
	}

	assert(interface.name != "") // TODO: Proper Error Handling
	assert(interface.version != 0)

	request_code, event_code: int

	for value in elem.value {
		idx := value.(xml.Element_ID) or_continue
		child := &doc.elements[idx]

		// Children of Interface
		switch child.ident {
		case "description":
			interface.desc = process_description(doc, child)
		case "request":
			request := process_message(doc, child)
			request.opcode = request_code
			append(&interface.requests, request)
			request_code += 1
		case "event":
			event := process_message(doc, child)
			event.opcode = event_code
			append(&interface.events, event)
			event_code += 1
		case "enum":
			en := process_enum(doc, child)
			interface.enums[en.name] = en
		}
	}

	return interface
}

process_message :: proc(doc: ^xml.Document, elem: ^xml.Element) -> Message {
	assert(elem.ident == "request" || elem.ident == "event")
	message: Message

	for attr in elem.attribs {
		switch attr.key {
		case "name":
			message.name = strings.clone(attr.val)
		}
	}

	assert(message.name != "") // TODO: Proper Error Handling

	for value in elem.value {
		idx := value.(xml.Element_ID) or_continue
		child := &doc.elements[idx]

		// Children of Request
		switch child.ident {
		case "description":
			message.desc = process_description(doc, child)
		case "arg":
			arg := process_arg(doc, child)

			if arg.type == .New_Id && arg.interface == "" {
				// This expands to 3 arguments
				/*
				This expands to three wire arguments:
					string – interface name
					uint – version
					new_id – object ID
				*/

				fmt.assertf(message.dynamic_bind == nil, "Multiple dynamic bindings for {}", message.name)
				
				message.dynamic_bind = len(message.arguments)

				append(&message.arguments, Arg{
					name = "interface",
					type = .String,
				})
				append(&message.arguments, Arg {
					name = "version",
					type = .UInt,
				})
			}

			append(&message.arguments, arg)
		}
	}

	return message
}

process_arg :: proc(doc: ^xml.Document, elem: ^xml.Element) -> Arg {
	assert(elem.ident == "arg")

	arg: Arg

	for attr in elem.attribs {
		switch attr.key {
		case "name":
			arg.name = strings.clone(attr.val)
		case "type":
			t, ok := parse_type(attr.val)
			if ok {
				arg.type = t
			} else {
				fmt.panicf("Invalid type: {}", attr.val)
			}
		// arg.type = strings.clone(attr.val)
		case "interface":
			arg.interface = strings.clone(attr.val)
		case "summary":
			arg.summary = strings.clone(attr.val)
		}
	}

	// TODO
	assert(arg.name != "")
	// assert(arg.type != "")
	//? Is this Correct?
	if arg.type == .New_Id {
		// assert(arg.interface != "")
	}

	return arg
}

process_enum :: proc(doc: ^xml.Document, elem: ^xml.Element) -> Enumerator {
	assert(elem.ident == "enum")

	enumerator: Enumerator

	for attr in elem.attribs {
		switch attr.key {
		case "name":
			enumerator.name = strings.clone(attr.val)
		}
	}

	assert(enumerator.name != "")

	for value in elem.value {
		idx := value.(xml.Element_ID) or_continue
		child := &doc.elements[idx]

		// Children of Enum
		switch child.ident {
		case "description":
			enumerator.desc = process_description(doc, child)
		case "entry":
			entry := process_entry(doc, child)

			append(&enumerator.entries, entry)
		}
	}


	return enumerator
}

process_entry :: proc(doc: ^xml.Document, elem: ^xml.Element) -> Entry {
	assert(elem.ident == "entry")

	entry: Entry

	for attr in elem.attribs {
		switch attr.key {
		case "name":
			entry.name = strings.clone(attr.val)
		case "value":
			val, ok := strconv.parse_int(attr.val)
			if ok {
				entry.value = i32(val)
			} else {
				// TODO: Error
				panic("Invalid version Value")
			}
		// entry.name = strings.clone(attr.val)
		}
	}


	return entry
}

process_description :: proc(doc: ^xml.Document, elem: ^xml.Element) -> Description {
	assert(elem.ident == "description")

	desc: Description

	for attr in elem.attribs {
		switch attr.key {
		case "summary":
			desc.summary = strings.clone(attr.val)
		}
	}

	for value in elem.value {
		text := value.(string) or_continue

		strings.write_string(&desc.contents, text)
	}

	return desc
}


parse_type :: proc(str: string) -> (type: Type, ok: bool) {
	switch str {
	case "int":
		return .Int, true
	case "uint":
		return .UInt, true
	case "fixed":
		return .Fixed, true
	case "string":
		return .String, true
	case "object":
		return .Object, true
	case "new_id":
		return .New_Id, true
	case "array":
		return .Array, true
	case "fd":
		return .FD, true
	}

	return .Int, false
}

// unmarshal_interface :: proc(elem: xml.Element) -> Interface {

//     interface: Interface
//     for attr in elem.attribs {
//         // fmt.println("Attrib:", attr)
//         switch attr.key {
//         case "name":
//             interface.name = strings.clone(attr.val)
//         case "version":
//             val, ok := strconv.parse_int(attr.val)
//             if ok {
//                 interface.version = i32(val)
//             } else {
//                 // TODO: Error
//             }
//         }
//     }

//     // TODO: Error

//     return interface
// }

// unmarshal_request :: proc(doc: ^xml.Document, elem: xml.Element) {

//     interface := interfaces[elem.parent]

//     request: Request

//     for attr in elem.attribs {
//         switch attr.key {
//         case "name":
//             request.name = strings.clone(attr.val)
//         }
//     }

//     fmt.assertf(request.name != "", "Unnamed request: {}", elem)

//     interface.requests[request.name] = new_clone(request)
// }


// root := decode_document(doc)

// // Print the Hierarchy:
// print :: proc(node: ^Node, indent := 0) {
//     for _ in 0..<indent do fmt.print("  ")


//     fmt.print(node.ident, node.name)
//     if node.version != "" {
//         fmt.printf(" v{}", node.version)
//     }

//     fmt.print("\n")

//     for val in node.xvalues {
//         for _ in 0..=indent do fmt.print("  ")

//         switch v in val {
//         case string:
//             fmt.printfln("\"{}\"", v)
//         case xml.Element_ID:
//             fmt.println("<Element>")
//         }
//     }

//     if node.children.head == nil do return

//     it := list.iterator_head(node.children, Node, "link")

//     for child in list.iterate_next(&it) {
//         print(child, indent + 1)
//     }
// }

// print(root)

// first := doc.elements[0]

// // Find Interfaces
// for elem, idx in doc.elements {
// 	switch elem.ident {
// 	case "interface":
//         // TODO: Make this work like below

//         inter := unmarshal_interface(elem)
//         fmt.assertf(inter.name != "", "Unnamed Interface: {}", elem)

//         interfaces[u32(idx)] = new_clone(inter)
//         // fmt.print("Processed Interface:", inter)
//     case "request":
//         unmarshal_request(doc, elem)


//     case "event":

//     case "arg":

// 	}
// }

// Request :: struct {
// 	name: string,

//     arguments: [dynamic]Arg,
// }

// fmt.println("FIRST:", first.ident)

// i: int
// for elem in doc.elements {
//     i += 1
//     if i >= 40 { break }
//     fmt.println("ELEMENT:", elem.ident)
// }

// name:      string,
// signature: string, // This is a sequence of characters, each is the type of each argument.
// types:     string, // In generated code, this needs to be a ^ to the interface global, which is itself a ^


// wr: io.Writer
// wr = io.to_writer(os.stream_from_handle(os.stdout))

// Package Header

// write_private_file(wr)
// io.write_string(wr, HEADER)

// for interface in interfaces {
// 	// fmt.println("============= INTERFACE =============")
// 	write_interface_impl(wr, interface)
// }
// fmt.println("=====================================")

// print_interfaces()
