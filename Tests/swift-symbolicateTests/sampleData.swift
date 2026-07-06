//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// sample json backtrace with random whitespace added to test our resilience
let sampleJsonTrace =
"""
{
    "timestamp": "2025-10-14T15:28:48.334565Z",
    "kind": "crashReport",
    "description": "Bad pointer dereference",
    "faultAddress": "0x000000000deadbee",
    "platform": "macOS 26.0.1 (25A362)",
    "architecture": "arm64",
    "threads": [
        {
            "crashed": true,
            "registers": {
                "x0": "0x0000000000000001",
                "x1": "0x0000000000000000",
                "x2": "0xffffffffffffffe0",
                "x3": "0x0000000102c3c320",
                "x4": "0x0000000102c3c380",
                "x5": "0x0000000000000000",
                "x6": "0x000000000000000a",
                "x7": "0xfffff0003ffff800",
                "x8": "0x000000000deadbee",
                "x9": "0x000000000deadbee",
                "x10": "0x00220c18221b0000",
                "x11": "0x00260c18221b0000",
                "x12": "0x0000000000000013",
                "x13": "0x0000000000000c36",
                "x14": "0x0000000000000060",
                "x15": "0x0000000000000000",
                "x16": "0x000000018622e030",
                "x17": "0x00000001f4208138",
                "x18": "0x0000000000000000",
                "x19": "0x00000001f2924060",
                "x20": "0x00000001f2bce9c8",
                "x21": "0x00000001f2924dd0",
                "x22": "0xfffffffffffffff0",
                "x23": "0x00000001f2bd20e0",
                "x24": "0x0000000000000001",
                "x25": "0x000000016d887310",
                "x26": "0x00000001f2bd20f0",
                "x27": "0x0000000000000000",
                "x28": "0x0000000000000000",
                "fp": "0x000000016d887110",
                "lr": "0x000000010257898c",
                "sp": "0x000000016d887090",
                "pc": "0x0000000102578a1c"
            },
            "frames": [
                {
                    "kind": "programCounter",
                    "address": "0x0000000102578a1c",
                    "symbol": "_main",
                    "offset": 372,
                    "description": "main + 372",
                    "image": "crashMe",
                    "sourceLocation": {
                        "file": "/Users/carlpeto/Desktop/crashMe/crashMe/main.swift",
                        "line": 13,
                        "column": 13
                    }
                },
                {
                    "kind": "returnAddress",
                    "address": "0x0000000185e65d54",
                    "system": true,
                    "symbol": "start",
                    "offset": 7184,
                    "description": "start + 7184",
                    "image": "dyld"
                },
                {
                    "kind": "truncated"
                }
            ]
        }
    ],
    "capturedMemory": {
        "0x00000001f2924dd0": "204092f2010000000000000000000000",
        "0x0000000102c3c380": "00000000000000000000000000000000",
        "0x000000016d887110": "7077886d01000000545de68501000000",
        "0x000000016d887310": "c8e9bcf2010000002f64796c64000000",
        "0x00000001f2bce9c8": "c05292f201000000d071886d01000000",
        "0x000000016d887090": "d070886d01000000e0ab89f301000000",
        "0x0000000102578a1c": "280100f900008052fd7b48a9ff430291",
        "0x00000001f4208138": "30e0228601000000d0be228601000000",
        "0x00000001f2bd20e0": "ff3f0000000000000040000000000000",
        "0x0000000102c3c320": "00000000000000000000000000000000",
        "0x000000018622e030": "e20301aa001c206e210001cae30300aa",
        "0x000000010257898c": "c87d9b5248bda172a8831ff8a8835ff8",
        "0x00000001f2924060": "204092f201000000204092f201000000",
        "0x00000001f2bd20f0": "03020000000000001022bdf201000000"
    },
    "omittedImages": 353,
    "images": [
        {
            "name": "crashMe",
            "buildId": "6fdbb104c032301189bae26d5506e11a",
            "path": "/Users/carlpeto/Library/Developer/Xcode/DerivedData/crashMe-btkscbpsnilvlwehcatfafpcxmpz/Build/Products/Debug/crashMe",
            "baseAddress": "0x0000000102578000",
            "endOfText": "0x000000010257c000"
        },
        {
            "name": "dyld",
            "buildId": "abfd324750ac3c8eb72a83710166e982",
            "path": "/usr/lib/dyld",
            "baseAddress": "0x0000000185e5d000",
            "endOfText": "0x0000000185efbf74"
        }
    ],
    "backtraceTime": 0.351198
}
"""

let unprettifiedUnsymbolicatedJsonTraceForRecognizer = """
{ "timestamp": "2025-10-31T16:02:18.231303Z", "kind": "crashReport", "description": "Bad pointer dereference", "faultAddress": "0x000000000deadbee", "platform": "macOS 26.1 (25B64)", "architecture": "arm64", "threads": [ { "crashed": true, "registers": {"x0": "0x0000000000000001", "x1": "0x0000000000000000", "x2": "0xffffffffffffffe0", "x3": "0x000000010005bce0", "x4": "0x000000010005bd40", "x5": "0x0000000000000001", "x6": "0x000000000000000a", "x7": "0x0000000000000000", "x8": "0x000000000deadbee", "x9": "0x000000000deadbee", "x10": "0x00000000000221b0", "x11": "0x00000000000261b0", "x12": "0x0000000000000013", "x13": "0x0000000000000bd2", "x14": "0x000000000000005e", "x15": "0x0000000000000000", "x16": "0x000000019d58b030", "x17": "0x000000020b50f610", "x18": "0x0000000000000000", "x19": "0x0000000209c34060", "x20": "0x0000000209ee0dc8", "x21": "0x0000000209c34de0", "x22": "0xfffffffffffffff0", "x23": "0x0000000209ee44e0", "x24": "0x0000000000000001", "x25": "0x000000016fdf3280", "x26": "0x0000000209ee44f0", "x27": "0x0000000000000000", "x28": "0x0000000000000000", "fp": "0x000000016fdf3080", "lr": "0x000000010000c98c", "sp": "0x000000016fdf3000", "pc": "0x000000010000ca1c" }, "frames": [ { "kind": "programCounter", "address": "0x000000010000ca1c" }, { "kind": "returnAddress", "address": "0x000000019d1b9d54" }, { "kind": "truncated" } ] } ], "capturedMemory": { "0x000000010005bd40": "00000000000000000000000000000000", "0x000000016fdf3280": "c80dee09020000002f64796c64000000", "0x000000020b50f610": "30b0589d01000000d08e589d01000000", "0x0000000209ee44f0": "03020000000000001046ee0902000000", "0x0000000209ee44e0": "ff3f0000000000000040000000000000", "0x0000000209ee0dc8": "1052c309020000004031df6f01000000", "0x000000010000c98c": "c87d9b5248bda172a8831ff8a8835ff8", "0x000000010005bce0": "00000000000000000000000000000000", "0x000000019d58b030": "e20301aa001c206e210001cae30300aa", "0x000000010000ca1c": "280100f900008052fd7b48a9ff430291", "0x000000016fdf3080": "e036df6f01000000549d1b9d01000000", "0x000000016fdf3000": "4030df6f010000006072ba0a02000000", "0x0000000209c34060": "2040c309020000002040c30902000000", "0x0000000209c34de0": "2040c309020000000000000000000000" }, "omittedImages": 337, "images": [ { "name": "crashMe", "buildId": "6fdbb104c032301189bae26d5506e11a", "path": "/Users/carlpeto/Desktop/crashMe", "baseAddress": "0x000000010000c000", "endOfText": "0x0000000100010000" }, { "name": "dyld", "buildId": "175354de24cb330199ef3ce9f1952bfd", "path": "/usr/lib/dyld", "baseAddress": "0x000000019d1b1000", "endOfText": "0x000000019d24ff64" } ] , "backtraceTime": 0.5057550000000001 }
"""

let loremIpsum = """
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque iaculis, nisl quis ultricies luctus, risus sem suscipit urna, quis commodo purus dui nec magna. Nullam quis sagittis diam. Maecenas auctor est est, eget pulvinar tortor aliquam quis. Nam malesuada tellus sit amet blandit maximus. Mauris mi metus, porttitor sed luctus sit amet, lacinia sit amet nisl. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Duis viverra lectus vel velit gravida, eu consequat nunc finibus. Nunc bibendum sodales ante, quis scelerisque mauris placerat eget. Cras at eleifend leo. Cras in sapien arcu. Sed lectus arcu, sollicitudin non sapien quis, rhoncus vestibulum odio. Etiam ac erat lorem. Fusce convallis tincidunt mi. Nullam vulputate iaculis egestas.
Vivamus turpis ex, rhoncus in tincidunt id, facilisis non nunc. Donec eleifend odio ut nibh rhoncus interdum. Suspendisse id sapien a augue pharetra interdum sed eu lectus. Fusce ac aliquam enim. Donec nec nulla nisi. Donec ut tincidunt ex. Aenean sodales laoreet tempor. Nam at nulla sagittis, rhoncus felis ac, ornare augue. Quisque ullamcorper lacus lectus.
Integer nibh mauris, sodales ac tortor quis, cursus gravida dolor. Etiam vulputate dignissim mi ut semper. Donec dignissim sed lectus sit amet molestie. Proin vitae rutrum magna, vel fringilla tellus. In vitae nunc sed leo ultricies malesuada. Aliquam erat volutpat. Donec odio mauris, vehicula non dolor in, porttitor viverra nisl. Sed ultricies, tellus a egestas bibendum, nulla purus tempus tellus, sit amet interdum risus mauris a risus. Pellentesque quis elit ligula. Aenean finibus vitae ex in gravida.
Pellentesque eros nunc, pretium ac dolor at, vehicula ornare est. Donec ultricies nunc in metus ullamcorper ullamcorper. Donec in ipsum tortor. Curabitur pellentesque urna porttitor lacus vehicula, a feugiat lacus placerat. Nam semper justo nunc, nec egestas libero pulvinar malesuada. Phasellus laoreet ipsum tellus, at laoreet erat euismod id. Sed magna libero, porta ac justo vel, dignissim laoreet quam. Sed porta rhoncus ligula eget gravida. Nulla fermentum, nulla vitae scelerisque viverra, nisi nulla convallis magna, ut laoreet velit quam consectetur nibh. Donec egestas dapibus volutpat. Cras enim risus, ultrices vel justo in, ornare ornare mauris. Aliquam semper in libero vel cursus. Sed eu pretium dolor. Vivamus sollicitudin feugiat felis non pharetra.
Fusce vitae odio a risus lacinia efficitur. Proin porta feugiat tincidunt. Maecenas vel risus vitae tellus dapibus semper id finibus tellus. Pellentesque eu diam magna. Integer sit amet tortor egestas, semper nibh sit amet, facilisis ligula. Duis suscipit enim lorem, quis congue risus auctor ac. In condimentum, lorem vitae iaculis eleifend, massa lectus vestibulum ex, sed finibus leo sapien non leo.
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque iaculis, nisl quis ultricies luctus, risus sem suscipit urna, quis commodo purus dui nec magna. Nullam quis sagittis diam. Maecenas auctor est est, eget pulvinar tortor aliquam quis. Nam malesuada tellus sit amet blandit maximus. Mauris mi metus, porttitor sed luctus sit amet, lacinia sit amet nisl. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Duis viverra lectus vel velit gravida, eu consequat nunc finibus. Nunc bibendum sodales ante, quis scelerisque mauris placerat eget. Cras at eleifend leo. Cras in sapien arcu. Sed lectus arcu, sollicitudin non sapien quis, rhoncus vestibulum odio. Etiam ac erat lorem. Fusce convallis tincidunt mi. Nullam vulputate iaculis egestas.
Vivamus turpis ex, rhoncus in tincidunt id, facilisis non nunc. Donec eleifend odio ut nibh rhoncus interdum. Suspendisse id sapien a augue pharetra interdum sed eu lectus. Fusce ac aliquam enim. Donec nec nulla nisi. Donec ut tincidunt ex. Aenean sodales laoreet tempor. Nam at nulla sagittis, rhoncus felis ac, ornare augue. Quisque ullamcorper lacus lectus.
Integer nibh mauris, sodales ac tortor quis, cursus gravida dolor. Etiam vulputate dignissim mi ut semper. Donec dignissim sed lectus sit amet molestie. Proin vitae rutrum magna, vel fringilla tellus. In vitae nunc sed leo ultricies malesuada. Aliquam erat volutpat. Donec odio mauris, vehicula non dolor in, porttitor viverra nisl. Sed ultricies, tellus a egestas bibendum, nulla purus tempus tellus, sit amet interdum risus mauris a risus. Pellentesque quis elit ligula. Aenean finibus vitae ex in gravida.
Pellentesque eros nunc, pretium ac dolor at, vehicula ornare est. Donec ultricies nunc in metus ullamcorper ullamcorper. Donec in ipsum tortor. Curabitur pellentesque urna porttitor lacus vehicula, a feugiat lacus placerat. Nam semper justo nunc, nec egestas libero pulvinar malesuada. Phasellus laoreet ipsum tellus, at laoreet erat euismod id. Sed magna libero, porta ac justo vel, dignissim laoreet quam. Sed porta rhoncus ligula eget gravida. Nulla fermentum, nulla vitae scelerisque viverra, nisi nulla convallis magna, ut laoreet velit quam consectetur nibh. Donec egestas dapibus volutpat. Cras enim risus, ultrices vel justo in, ornare ornare mauris. Aliquam semper in libero vel cursus. Sed eu pretium dolor. Vivamus sollicitudin feugiat felis non pharetra.
Fusce vitae odio a risus lacinia efficitur. Proin porta feugiat tincidunt. Maecenas vel risus vitae tellus dapibus semper id finibus tellus. Pellentesque eu diam magna. Integer sit amet tortor egestas, semper nibh sit amet, facilisis ligula. Duis suscipit enim lorem, quis congue risus auctor ac. In condimentum, lorem vitae iaculis eleifend, massa lectus vestibulum ex, sed finibus leo sapien non leo.
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque iaculis, nisl quis ultricies luctus, risus sem suscipit urna, quis commodo purus dui nec magna. Nullam quis sagittis diam. Maecenas auctor est est, eget pulvinar tortor aliquam quis. Nam malesuada tellus sit amet blandit maximus. Mauris mi metus, porttitor sed luctus sit amet, lacinia sit amet nisl. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Duis viverra lectus vel velit gravida, eu consequat nunc finibus. Nunc bibendum sodales ante, quis scelerisque mauris placerat eget. Cras at eleifend leo. Cras in sapien arcu. Sed lectus arcu, sollicitudin non sapien quis, rhoncus vestibulum odio. Etiam ac erat lorem. Fusce convallis tincidunt mi. Nullam vulputate iaculis egestas.
Vivamus turpis ex, rhoncus in tincidunt id, facilisis non nunc. Donec eleifend odio ut nibh rhoncus interdum. Suspendisse id sapien a augue pharetra interdum sed eu lectus. Fusce ac aliquam enim. Donec nec nulla nisi. Donec ut tincidunt ex. Aenean sodales laoreet tempor. Nam at nulla sagittis, rhoncus felis ac, ornare augue. Quisque ullamcorper lacus lectus.
Integer nibh mauris, sodales ac tortor quis, cursus gravida dolor. Etiam vulputate dignissim mi ut semper. Donec dignissim sed lectus sit amet molestie. Proin vitae rutrum magna, vel fringilla tellus. In vitae nunc sed leo ultricies malesuada. Aliquam erat volutpat. Donec odio mauris, vehicula non dolor in, porttitor viverra nisl. Sed ultricies, tellus a egestas bibendum, nulla purus tempus tellus, sit amet interdum risus mauris a risus. Pellentesque quis elit ligula. Aenean finibus vitae ex in gravida.
Pellentesque eros nunc, pretium ac dolor at, vehicula ornare est. Donec ultricies nunc in metus ullamcorper ullamcorper. Donec in ipsum tortor. Curabitur pellentesque urna porttitor lacus vehicula, a feugiat lacus placerat. Nam semper justo nunc, nec egestas libero pulvinar malesuada. Phasellus laoreet ipsum tellus, at laoreet erat euismod id. Sed magna libero, porta ac justo vel, dignissim laoreet quam. Sed porta rhoncus ligula eget gravida. Nulla fermentum, nulla vitae scelerisque viverra, nisi nulla convallis magna, ut laoreet velit quam consectetur nibh. Donec egestas dapibus volutpat. Cras enim risus, ultrices vel justo in, ornare ornare mauris. Aliquam semper in libero vel cursus. Sed eu pretium dolor. Vivamus sollicitudin feugiat felis non pharetra.
Fusce vitae odio a risus lacinia efficitur. Proin porta feugiat tincidunt. Maecenas vel risus vitae tellus dapibus semper id finibus tellus. Pellentesque eu diam magna. Integer sit amet tortor egestas, semper nibh sit amet, facilisis ligula. Duis suscipit enim lorem, quis congue risus auctor ac. In condimentum, lorem vitae iaculis eleifend, massa lectus vestibulum ex, sed finibus leo sapien non leo.
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque iaculis, nisl quis ultricies luctus, risus sem suscipit urna, quis commodo purus dui nec magna. Nullam quis sagittis diam. Maecenas auctor est est, eget pulvinar tortor aliquam quis. Nam malesuada tellus sit amet blandit maximus. Mauris mi metus, porttitor sed luctus sit amet, lacinia sit amet nisl. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Duis viverra lectus vel velit gravida, eu consequat nunc finibus. Nunc bibendum sodales ante, quis scelerisque mauris placerat eget. Cras at eleifend leo. Cras in sapien arcu. Sed lectus arcu, sollicitudin non sapien quis, rhoncus vestibulum odio. Etiam ac erat lorem. Fusce convallis tincidunt mi. Nullam vulputate iaculis egestas.
Vivamus turpis ex, rhoncus in tincidunt id, facilisis non nunc. Donec eleifend odio ut nibh rhoncus interdum. Suspendisse id sapien a augue pharetra interdum sed eu lectus. Fusce ac aliquam enim. Donec nec nulla nisi. Donec ut tincidunt ex. Aenean sodales laoreet tempor. Nam at nulla sagittis, rhoncus felis ac, ornare augue. Quisque ullamcorper lacus lectus.
Integer nibh mauris, sodales ac tortor quis, cursus gravida dolor. Etiam vulputate dignissim mi ut semper. Donec dignissim sed lectus sit amet molestie. Proin vitae rutrum magna, vel fringilla tellus. In vitae nunc sed leo ultricies malesuada. Aliquam erat volutpat. Donec odio mauris, vehicula non dolor in, porttitor viverra nisl. Sed ultricies, tellus a egestas bibendum, nulla purus tempus tellus, sit amet interdum risus mauris a risus. Pellentesque quis elit ligula. Aenean finibus vitae ex in gravida.
Pellentesque eros nunc, pretium ac dolor at, vehicula ornare est. Donec ultricies nunc in metus ullamcorper ullamcorper. Donec in ipsum tortor. Curabitur pellentesque urna porttitor lacus vehicula, a feugiat lacus placerat. Nam semper justo nunc, nec egestas libero pulvinar malesuada. Phasellus laoreet ipsum tellus, at laoreet erat euismod id. Sed magna libero, porta ac justo vel, dignissim laoreet quam. Sed porta rhoncus ligula eget gravida. Nulla fermentum, nulla vitae scelerisque viverra, nisi nulla convallis magna, ut laoreet velit quam consectetur nibh. Donec egestas dapibus volutpat. Cras enim risus, ultrices vel justo in, ornare ornare mauris. Aliquam semper in libero vel cursus. Sed eu pretium dolor. Vivamus sollicitudin feugiat felis non pharetra.
Fusce vitae odio a risus lacinia efficitur. Proin porta feugiat tincidunt. Maecenas vel risus vitae tellus dapibus semper id finibus tellus. Pellentesque eu diam magna. Integer sit amet tortor egestas, semper nibh sit amet, facilisis ligula. Duis suscipit enim lorem, quis congue risus auctor ac. In condimentum, lorem vitae iaculis eleifend, massa lectus vestibulum ex, sed finibus leo sapien non leo.
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque iaculis, nisl quis ultricies luctus, risus sem suscipit urna, quis commodo purus dui nec magna. Nullam quis sagittis diam. Maecenas auctor est est, eget pulvinar tortor aliquam quis. Nam malesuada tellus sit amet blandit maximus. Mauris mi metus, porttitor sed luctus sit amet, lacinia sit amet nisl. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Duis viverra lectus vel velit gravida, eu consequat nunc finibus. Nunc bibendum sodales ante, quis scelerisque mauris placerat eget. Cras at eleifend leo. Cras in sapien arcu. Sed lectus arcu, sollicitudin non sapien quis, rhoncus vestibulum odio. Etiam ac erat lorem. Fusce convallis tincidunt mi. Nullam vulputate iaculis egestas.
Vivamus turpis ex, rhoncus in tincidunt id, facilisis non nunc. Donec eleifend odio ut nibh rhoncus interdum. Suspendisse id sapien a augue pharetra interdum sed eu lectus. Fusce ac aliquam enim. Donec nec nulla nisi. Donec ut tincidunt ex. Aenean sodales laoreet tempor. Nam at nulla sagittis, rhoncus felis ac, ornare augue. Quisque ullamcorper lacus lectus.
Integer nibh mauris, sodales ac tortor quis, cursus gravida dolor. Etiam vulputate dignissim mi ut semper. Donec dignissim sed lectus sit amet molestie. Proin vitae rutrum magna, vel fringilla tellus. In vitae nunc sed leo ultricies malesuada. Aliquam erat volutpat. Donec odio mauris, vehicula non dolor in, porttitor viverra nisl. Sed ultricies, tellus a egestas bibendum, nulla purus tempus tellus, sit amet interdum risus mauris a risus. Pellentesque quis elit ligula. Aenean finibus vitae ex in gravida.
Pellentesque eros nunc, pretium ac dolor at, vehicula ornare est. Donec ultricies nunc in metus ullamcorper ullamcorper. Donec in ipsum tortor. Curabitur pellentesque urna porttitor lacus vehicula, a feugiat lacus placerat. Nam semper justo nunc, nec egestas libero pulvinar malesuada. Phasellus laoreet ipsum tellus, at laoreet erat euismod id. Sed magna libero, porta ac justo vel, dignissim laoreet quam. Sed porta rhoncus ligula eget gravida. Nulla fermentum, nulla vitae scelerisque viverra, nisi nulla convallis magna, ut laoreet velit quam consectetur nibh. Donec egestas dapibus volutpat. Cras enim risus, ultrices vel justo in, ornare ornare mauris. Aliquam semper in libero vel cursus. Sed eu pretium dolor. Vivamus sollicitudin feugiat felis non pharetra.
Fusce vitae odio a risus lacinia efficitur. Proin porta feugiat tincidunt. Maecenas vel risus vitae tellus dapibus semper id finibus tellus. Pellentesque eu diam magna. Integer sit amet tortor egestas, semper nibh sit amet, facilisis ligula. Duis suscipit enim lorem, quis congue risus auctor ac. In condimentum, lorem vitae iaculis eleifend, massa lectus vestibulum ex, sed finibus leo sapien non leo.
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Quisque iaculis, nisl quis ultricies luctus, risus sem suscipit urna, quis commodo purus dui nec magna. Nullam quis sagittis diam. Maecenas auctor est est, eget pulvinar tortor aliquam quis. Nam malesuada tellus sit amet blandit maximus. Mauris mi metus, porttitor sed luctus sit amet, lacinia sit amet nisl. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Duis viverra lectus vel velit gravida, eu consequat nunc finibus. Nunc bibendum sodales ante, quis scelerisque mauris placerat eget. Cras at eleifend leo. Cras in sapien arcu. Sed lectus arcu, sollicitudin non sapien quis, rhoncus vestibulum odio. Etiam ac erat lorem. Fusce convallis tincidunt mi. Nullam vulputate iaculis egestas.
Vivamus turpis ex, rhoncus in tincidunt id, facilisis non nunc. Donec eleifend odio ut nibh rhoncus interdum. Suspendisse id sapien a augue pharetra interdum sed eu lectus. Fusce ac aliquam enim. Donec nec nulla nisi. Donec ut tincidunt ex. Aenean sodales laoreet tempor. Nam at nulla sagittis, rhoncus felis ac, ornare augue. Quisque ullamcorper lacus lectus.
Integer nibh mauris, sodales ac tortor quis, cursus gravida dolor. Etiam vulputate dignissim mi ut semper. Donec dignissim sed lectus sit amet molestie. Proin vitae rutrum magna, vel fringilla tellus. In vitae nunc sed leo ultricies malesuada. Aliquam erat volutpat. Donec odio mauris, vehicula non dolor in, porttitor viverra nisl. Sed ultricies, tellus a egestas bibendum, nulla purus tempus tellus, sit amet interdum risus mauris a risus. Pellentesque quis elit ligula. Aenean finibus vitae ex in gravida.
Pellentesque eros nunc, pretium ac dolor at, vehicula ornare est. Donec ultricies nunc in metus ullamcorper ullamcorper. Donec in ipsum tortor. Curabitur pellentesque urna porttitor lacus vehicula, a feugiat lacus placerat. Nam semper justo nunc, nec egestas libero pulvinar malesuada. Phasellus laoreet ipsum tellus, at laoreet erat euismod id. Sed magna libero, porta ac justo vel, dignissim laoreet quam. Sed porta rhoncus ligula eget gravida. Nulla fermentum, nulla vitae scelerisque viverra, nisi nulla convallis magna, ut laoreet velit quam consectetur nibh. Donec egestas dapibus volutpat. Cras enim risus, ultrices vel justo in, ornare ornare mauris. Aliquam semper in libero vel cursus. Sed eu pretium dolor. Vivamus sollicitudin feugiat felis non pharetra.
Fusce vitae odio a risus lacinia efficitur. Proin porta feugiat tincidunt. Maecenas vel risus vitae tellus dapibus semper id finibus tellus. Pellentesque eu diam magna. Integer sit amet tortor egestas, semper nibh sit amet, facilisis ligula. Duis suscipit enim lorem, quis congue risus auctor ac. In condimentum, lorem vitae iaculis eleifend, massa lectus vestibulum ex, sed finibus leo sapien non leo.
"""

let recognizerJsonTest = """
{ "timestamp": "2025-10-28T18:18:19.546951Z", "kind": "crashReport", "" }
"""

let recognizerJsonTest2 = """
{ "timestamps": "2025-10-28T18:18:19.546951Z", "kind": "crashReport", "" }
"""

let recognizerJsonTest3 = """
totally unrelated text that we expect to be passed through
"""

let recognizerJsonEndTest = """
"endOfText": "0x000000019d24ff64" } ] , "backtraceTime": 0.34544 }
"""

let recognizerEdgeCase1 = """
{ "times { "timestamp": "2025-10-28T18:18:19.546951Z", "kind": "crashReport", "" }
"""

let recognizerEdgeCase2 = """
{ "times{ "timestamp": "2025-10-28T18:18:19.546951Z", "kind": "crashReport", "" }
"""


let jsonCrashLogCorruptedWithStartFinish = """
some text before a json formatted crash dump { "timestamp": "2025-10-28T18:18:19.546951Z", "kind": "crashReport", "content": "THIS ISNT A REAL CRASH LOG",  "backtraceTime": 0.34544 } some text
after a json formatted crash dump
"""

let jsonCrashLogCorruptedWithFalseStart = """
some text before a json formatted crash dump { "timestamp": "2025-10-28T18:18:19.546951Z", "content": "THIS ISNT A REAL CRASH LOG",  "backtraceTime": 0.34544 } some text
after a json formatted crash dump
"""

let exampleReconstructableJSON = 
"""
{ "timestamp": "2025-12-10T15:11:59.127552Z", "kind": "crashReport", "description": "Bad pointer dereference", "faultAddress": "0x000000000deadbee", "platform": "macOS 26.1 (25B64)", "architecture": "arm64", "threads": [ { "crashed": true, "registers": {"x0": "0x0000000000000001", "x1": "0x0000000000000000", "x2": "0xfffffffffffffff0", "x3": "0x000000010425cc30", "x4": "0x000000010425cc80", "x5": "0x0000000000000000", "x6": "0x000000000000000a", "x7": "0xfffff0003ffff800", "x8": "0x000000000deadbee", "x9": "0x000000000deadbee", "x10": "0x0000000000000002", "x11": "0x0000010000000000", "x12": "0x00000000fffffffd", "x13": "0x0000000000000000", "x14": "0x0000000000000000", "x15": "0x0000000000000000", "x16": "0x0000000198b27030", "x17": "0x0000000206aab610", "x18": "0x0000000000000000", "x19": "0x00000002051d0060", "x20": "0x000000020547cdc8", "x21": "0x00000002051d0e00", "x22": "0xfffffffffffffff0", "x23": "0x00000002054804e0", "x24": "0x0000000000000001", "x25": "0x000000016d887130", "x26": "0x00000002054804f0", "x27": "0x0000000000000000", "x28": "0x0000000000000000", "fp": "0x000000016d886f30", "lr": "0x000000010257898c", "sp": "0x000000016d886eb0", "pc": "0x0000000102578a1c" }, "frames": [ { "kind": "programCounter", "address": "0x0000000102578a1c" }, { "kind": "returnAddress", "address": "0x0000000198755d54" }, { "kind": "truncated" } ] } ], "capturedMemory": { "0x000000010257898c": "c87d9b5248bda172a8831ff8a8835ff8", "0x0000000102578a1c": "280100f900008052fd7b48a9ff430291", "0x000000010425cc30": "00000000000000000000000000000000", "0x000000010425cc80": "00000000000000000000000000000000", "0x000000016d886eb0": "f06e886d010000006032140602000000", "0x000000016d886f30": "9075886d01000000545d759801000000", "0x000000016d887130": "c8cd4705020000002f64796c64000000", "0x0000000198b27030": "e20301aa001c206e210001cae30300aa", "0x00000002051d0060": "20001d050200000010c05d0201000000", "0x00000002051d0e00": "20001d05020000000000000000000000", "0x000000020547cdc8": "20131d0502000000f06f886d01000000", "0x00000002054804e0": "ff3f0000000000000040000000000000", "0x00000002054804f0": "03020000000000001006480502000000", "0x0000000206aab610": "3070b29801000000d04eb29801000000" }, "omittedImages": 336, "images": [ { "name": "crashMe", "buildId": "6fdbb104c032301189bae26d5506e11a", "path": "/Users/carlpeto/Desktop/crashMe", "baseAddress": "0x0000000102578000", "endOfText": "0x000000010257c000" }, { "name": "dyld", "buildId": "175354de24cb330199ef3ce9f1952bfd", "path": "/usr/lib/dyld", "baseAddress": "0x000000019874d000", "endOfText": "0x00000001987ebf64" } ] , "backtraceTime": 0.306703 }
"""

let unsymbolicatedCrashLog = """
{
    "timestamp": "2025-10-24T13:48:35.217149Z",
    "kind": "crashReport",
    "description": "Bad pointer dereference",
    "faultAddress": "0x000000000deadbee",
    "platform": "macOS 26.1 (25B64)",
    "architecture": "arm64",
    "threads": [
        {
            "crashed": true,
            "registers": {
                "x0": "0x0000000000000001",
                "x1": "0x0000000000000000",
                "x2": "0xfffffffffffffff0",
                "x3": "0x0000000104c2bcb0",
                "x4": "0x0000000104c2bd00",
                "x5": "0x0000000000000001",
                "x6": "0x000000000000000a",
                "x7": "0x0000000000000000",
                "x8": "0x000000000deadbee",
                "x9": "0x000000000deadbee",
                "x10": "0x0000000000004436",
                "x11": "0x0000000000004c36",
                "x12": "0x0000000000000013",
                "x13": "0x0000000000000bcf",
                "x14": "0x000000000000005e",
                "x15": "0x0000000000000000",
                "x16": "0x000000019d58b030",
                "x17": "0x000000020b50f610",
                "x18": "0x0000000000000000",
                "x19": "0x0000000209c34060",
                "x20": "0x0000000209ee0dc8",
                "x21": "0x0000000209c34de0",
                "x22": "0xfffffffffffffff0",
                "x23": "0x0000000209ee44e0",
                "x24": "0x0000000000000001",
                "x25": "0x000000016b8a32b0",
                "x26": "0x0000000209ee44f0",
                "x27": "0x0000000000000000",
                "x28": "0x0000000000000000",
                "fp": "0x000000016b8a30b0",
                "lr": "0x000000010455c98c",
                "sp": "0x000000016b8a3030",
                "pc": "0x000000010455ca1c"
            },
            "frames": [
                {
                    "kind": "programCounter",
                    "address": "0x000000010455ca1c"
                },
                {
                    "kind": "returnAddress",
                    "address": "0x000000019d1b9d54"
                },
                {
                    "kind": "truncated"
                }
            ]
        }
    ],
    "capturedMemory": {
        "0x000000010455c98c": "c87d9b5248bda172a8831ff8a8835ff8",
        "0x0000000209ee44f0": "03020000000000001046ee0902000000",
        "0x000000020b50f610": "30b0589d01000000d08e589d01000000",
        "0x0000000209ee0dc8": "1052c3090200000070318a6b01000000",
        "0x0000000209c34060": "2040c309020000002040c30902000000",
        "0x0000000104c2bd00": "00000000000000000000000000000000",
        "0x000000010455ca1c": "280100f900008052fd7b48a9ff430291",
        "0x000000016b8a3030": "70308a6b010000006072ba0a02000000",
        "0x0000000209ee44e0": "ff3f0000000000000040000000000000",
        "0x000000016b8a30b0": "10378a6b01000000549d1b9d01000000",
        "0x0000000209c34de0": "2040c309020000000000000000000000",
        "0x000000019d58b030": "e20301aa001c206e210001cae30300aa",
        "0x000000016b8a32b0": "c80dee09020000002f64796c64000000",
        "0x0000000104c2bcb0": "00000000000000000000000000000000"
    },
    "omittedImages": 337,
    "images": [
        {
            "name": "crashMe",
            "buildId": "6fdbb104c032301189bae26d5506e11a",
            "path": "/Users/carlpeto/Desktop/crashMe",
            "baseAddress": "0x000000010455c000",
            "endOfText": "0x0000000104560000"
        },
        {
            "name": "dyld",
            "buildId": "175354de24cb330199ef3ce9f1952bfd",
            "path": "/usr/lib/dyld",
            "baseAddress": "0x000000019d1b1000",
            "endOfText": "0x000000019d24ff64"
        }
    ],
    "backtraceTime": 0.323114
}
"""

/* For reference, this is the text form of the symbolicated crash dump for the same executable as the unsymbolicated one here ^^ */

let plainTextCrashLog = """

*** Program crashed: Bad pointer dereference at 0x000000000deadbee ***

Platform: arm64 macOS 26.1 (25B64)

Thread 0 crashed:

  0               0x0000000100a18a1c main + 372 in crashMe at /Users/carlpeto/Desktop/crashMe/crashMe/main.swift:13:13
  1 [ra] [system] 0x000000019d1b9d54 start + 7184 in dyld
...


Registers:

 x0 0x0000000000000001  1
 x1 0x0000000000000000  0
 x2 0xffffffffffffffc0  18446744073709551552
 x3 0x00000001012d3cc0  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 x4 0x00000001012d3d40  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 x5 0x0000000000000000  0
 x6 0x000000000000000a  10
 x7 0xfffff0003ffff800  18446726482597246976
 x8 0x000000000deadbee  233495534
 x9 0x000000000deadbee  233495534
x10 0x000000000000886c  34924
x11 0x000000000000986c  39020
x12 0x0000000000000013  19
x13 0x0000000000000bd0  3024
x14 0x000000000000005e  94
x15 0x0000000000000000  0
x16 0x000000019d58b030  e2 03 01 aa 00 1c 20 6e 21 00 01 ca e3 03 00 aa  â··ª·· n!··Êã··ª
x17 0x000000020b50f610  30 b0 58 9d 01 00 00 00 d0 8e 58 9d 01 00 00 00  0°X·····Ð·X·····
x18 0x0000000000000000  0
x19 0x0000000209c34060  20 40 c3 09 02 00 00 00 20 40 c3 09 02 00 00 00   @Ã····· @Ã·····
x20 0x0000000209ee0dc8  10 52 c3 09 02 00 00 00 50 71 3e 6f 01 00 00 00  ·RÃ·····Pq>o····
x21 0x0000000209c34de0  20 40 c3 09 02 00 00 00 00 00 00 00 00 00 00 00   @Ã·············
x22 0xfffffffffffffff0  18446744073709551600
x23 0x0000000209ee44e0  ff 3f 00 00 00 00 00 00 00 40 00 00 00 00 00 00  ÿ?·······@······
x24 0x0000000000000001  1
x25 0x000000016f3e7290  c8 0d ee 09 02 00 00 00 2f 64 79 6c 64 00 00 00  È·î·····/dyld···
x26 0x0000000209ee44f0  03 02 00 00 00 00 00 00 10 46 ee 09 02 00 00 00  ·········Fî·····
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016f3e7090  f0 76 3e 6f 01 00 00 00 54 9d 1b 9d 01 00 00 00  ðv>o····T·······
 lr 0x0000000100a1898c  c8 7d 9b 52 48 bd a1 72 a8 83 1f f8 a8 83 5f f8  È}·RH½¡r¨··ø¨·_ø
 sp 0x000000016f3e7010  50 70 3e 6f 01 00 00 00 60 72 ba 0a 02 00 00 00  Pp>o····`rº·····
 pc 0x0000000100a18a1c  28 01 00 f9 00 00 80 52 fd 7b 48 a9 ff 43 02 91  (··ù···Rý{H©ÿC··


Images (337 omitted):

0x0000000100a18000–0x0000000100a1c000 6fdbb104c032301189bae26d5506e11a crashMe /Users/carlpeto/Desktop/crashMe
0x000000019d1b1000–0x000000019d24ff64 175354de24cb330199ef3ce9f1952bfd dyld    /usr/lib/dyld

Backtrace took 0.35s


"""

let plainTextCrashLogEnd = """
Preample... Backtrace took 0.35 seconds
"""

let unsymbolicatedPlainCrashLog = """
Hello, World!

*** Signal 11: Backtracing from 0x104ea8a1c... done ***

*** Program crashed: Bad pointer dereference at 0x000000000deadbee ***

Platform: arm64 macOS 26.1 (25B64)

Thread 0 crashed:

0      0x0000000104ea8a1c
1 [ra] 0x000000019d1b9d54
2      ...


Registers:

 x0 0x0000000000000001  1
 x1 0x0000000000000000  0
 x2 0xffffffffffffffe0  18446744073709551584
 x3 0x00000001056240a0  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 x4 0x0000000105624100  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 x5 0x0000000000000000  0
 x6 0x000000000000000a  10
 x7 0xfffff0003ffff800  18446726482597246976
 x8 0x000000000deadbee  233495534
 x9 0x000000000deadbee  233495534
x10 0x000000000000221b  8731
x11 0x000000000000261b  9755
x12 0x0000000000000013  19
x13 0x0000000000000c0e  3086
x14 0x0000000000000060  96
x15 0x0000000000000000  0
x16 0x000000019d58b030  e2 03 01 aa 00 1c 20 6e 21 00 01 ca e3 03 00 aa  â··ª·· n!··Êã··ª
x17 0x000000020b50f610  30 b0 58 9d 01 00 00 00 d0 8e 58 9d 01 00 00 00  0°X·····Ð·X·····
x18 0x0000000000000000  0
x19 0x0000000209c34060  20 40 c3 09 02 00 00 00 20 40 c3 09 02 00 00 00   @Ã····· @Ã·····
x20 0x0000000209ee0dc8  10 52 c3 09 02 00 00 00 30 71 f5 6a 01 00 00 00  ·RÃ·····0qõj····
x21 0x0000000209c34de0  20 40 c3 09 02 00 00 00 00 00 00 00 00 00 00 00   @Ã·············
x22 0xfffffffffffffff0  18446744073709551600
x23 0x0000000209ee44e0  ff 3f 00 00 00 00 00 00 00 40 00 00 00 00 00 00  ÿ?·······@······
x24 0x0000000000000001  1
x25 0x000000016af57270  c8 0d ee 09 02 00 00 00 2f 64 79 6c 64 00 00 00  È·î·····/dyld···
x26 0x0000000209ee44f0  03 02 00 00 00 00 00 00 10 46 ee 09 02 00 00 00  ·········Fî·····
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016af57070  d0 76 f5 6a 01 00 00 00 54 9d 1b 9d 01 00 00 00  Ðvõj····T·······
 lr 0x0000000104ea898c  c8 7d 9b 52 48 bd a1 72 a8 83 1f f8 a8 83 5f f8  È}·RH½¡r¨··ø¨·_ø
 sp 0x000000016af56ff0  30 70 f5 6a 01 00 00 00 60 72 ba 0a 02 00 00 00  0põj····`rº·····
 pc 0x0000000104ea8a1c  28 01 00 f9 00 00 80 52 fd 7b 48 a9 ff 43 02 91  (··ù···Rý{H©ÿC··


Images (337 omitted):

0x0000000104ea8000–0x0000000104eac000 6fdbb104c032301189bae26d5506e11a crashMe /Users/carlpeto/Desktop/crashMe
0x000000019d1b1000–0x000000019d24ff64 175354de24cb330199ef3ce9f1952bfd dyld    /usr/lib/dyld

Backtrace took 0.54s

zsh: segmentation fault  ./crashMe
"""

let unsymbPlain1 = """
*** Program crashed: Bad pointer dereference at 0x000000000deadbee ***

Platform: arm64 macOS 26.1 (25B64)

Thread 0 crashed:

0      0x0000000102c88a1c
1 [ra] 0x000000019d1b9d54
2      ...


Registers:

 x0 0x0000000000000001  1
 x1 0x0000000000000000  0
 x2 0xffffffffffffffe0  18446744073709551584
 x3 0x0000000103563ce0  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 x4 0x0000000103563d40  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ················
 x5 0x0000000000000000  0
 x6 0x000000000000000a  10
 x7 0xfffff0003ffff800  18446726482597246976
 x8 0x000000000deadbee  233495534
 x9 0x000000000deadbee  233495534
x10 0x00000000000221b0  139696
x11 0x00000000000261b0  156080
x12 0x0000000000000013  19
x13 0x0000000000000bd2  3026
x14 0x000000000000005e  94
x15 0x0000000000000000  0
x16 0x000000019d58b030  e2 03 01 aa 00 1c 20 6e 21 00 01 ca e3 03 00 aa  â··ª·· n!··Êã··ª
x17 0x000000020b50f610  30 b0 58 9d 01 00 00 00 d0 8e 58 9d 01 00 00 00  0°X·····Ð·X·····
x18 0x0000000000000000  0
x19 0x0000000209c34060  20 40 c3 09 02 00 00 00 20 40 c3 09 02 00 00 00   @Ã····· @Ã·····
x20 0x0000000209ee0dc8  10 52 c3 09 02 00 00 00 40 71 17 6d 01 00 00 00  ·RÃ·····@q·m····
x21 0x0000000209c34de0  20 40 c3 09 02 00 00 00 00 00 00 00 00 00 00 00   @Ã·············
x22 0xfffffffffffffff0  18446744073709551600
x23 0x0000000209ee44e0  ff 3f 00 00 00 00 00 00 00 40 00 00 00 00 00 00  ÿ?·······@······
x24 0x0000000000000001  1
x25 0x000000016d177280  c8 0d ee 09 02 00 00 00 2f 64 79 6c 64 00 00 00  È·î·····/dyld···
x26 0x0000000209ee44f0  03 02 00 00 00 00 00 00 10 46 ee 09 02 00 00 00  ·········Fî·····
x27 0x0000000000000000  0
x28 0x0000000000000000  0
 fp 0x000000016d177080  e0 76 17 6d 01 00 00 00 54 9d 1b 9d 01 00 00 00  àv·m····T·······
 lr 0x0000000102c8898c  c8 7d 9b 52 48 bd a1 72 a8 83 1f f8 a8 83 5f f8  È}·RH½¡r¨··ø¨·_ø
 sp 0x000000016d177000  40 70 17 6d 01 00 00 00 60 72 ba 0a 02 00 00 00  @p·m····`rº·····
 pc 0x0000000102c88a1c  28 01 00 f9 00 00 80 52 fd 7b 48 a9 ff 43 02 91  (··ù···Rý{H©ÿC··


Images (337 omitted):

0x0000000102c88000–0x0000000102c8c000 6fdbb104c032301189bae26d5506e11a crashMe /Users/carlpeto/Desktop/crashMe
0x000000019d1b1000–0x000000019d24ff64 175354de24cb330199ef3ce9f1952bfd dyld    /usr/lib/dyld

Backtrace took 0.32s
"""
