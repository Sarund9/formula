package formula_wayland_generator


import "core:encoding/xml"
import "core:fmt"
import "core:strconv"
import "core:strings"

import "core:flags"
import "core:io"
import "core:os"

import "core:container/intrusive/list"


print_document :: proc(doc: ^xml.Document, elem: ^xml.Element, indent := 0) {
	if elem.kind == .Comment {
		return
	}

	for _ in 0 ..< indent do fmt.print("  ")

	fmt.print(elem.ident)
	for attr in elem.attribs {
		fmt.printf(" {}={}", attr.key, attr.val)
	}

	fmt.print("\n")

	if len(elem.value) == 0 do return

	for child in elem.value {
		switch value in child {
		case string:
			for _ in 0 ..= indent do fmt.print("  ")
			fmt.print(value)
		case xml.Element_ID:
			print_document(doc, &doc.elements[value], indent + 1)
		}
	}

	fmt.print("\n")
}

/* Marshal XML code into an actually traversable tree.

*/

// Node :: struct {
// 	link:                     list.Node,
// 	children:                 list.List,
// 	ident:                    string,
// 	name, version, value:     string,
// 	type, interface, summary: string,
// 	xvalues:                  [dynamic]xml.Value,
// }

// decode_document :: proc(doc: ^xml.Document) -> ^Node {
// 	nodes := make(map[xml.Element_ID]^Node)

// 	for elem, idx in doc.elements {
// 		// Ignore Comments
// 		if elem.kind == .Comment {
// 			continue
// 		}

// 		node := new(Node)

// 		node.ident = elem.ident

// 		// Hook up to Parent
// 		if parent, exists := nodes[elem.parent]; exists {
// 			list.push_back(&parent.children, &node.link)
// 		}

// 		node.xvalues = elem.value

// 		// Attributes
// 		for attr in elem.attribs {
// 			switch attr.key {
// 			case "name":
// 				node.name = attr.val
// 			case "version":
// 				node.version = attr.val
// 			case "value":
// 				node.value = attr.val
// 			case "type":
// 				node.type = attr.val
// 			case "interface":
// 				node.interface = attr.val
// 			case "summary":
// 				node.summary = attr.val
// 			}
// 		}

// 		nodes[u32(idx)] = node
// 	}

// 	root := nodes[0]
// 	delete(nodes)
// 	return root
// }
