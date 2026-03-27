# Native Memory Inspector

A "human-centric" memory exploration tool built for the **Dart & Flutter GSoC 2026** project: *Inspect Native Memory in Dart DevTools.*
This prototype demonstrates how raw memory addresses can be visualized and interpreted dynamically, bridging the gap between low-level pointers and developer-friendly debugging.

##Key Features
* Dynamic Type Casting: Interpret raw bytes as `Int32`, `Double`, and more on the fly.
* Memory Safety: Implements manual allocation and explicit freeing of native memory via `dart:ffi`.
* Hex-Dump Visualization: A reactive, color-coded grid that highlights active data vs. null padding.
* Human Interpretation: Automatically explains byte-level data in plain English to assist with debugging complex pointers.

##Tech Stack
* Flutter: High-performance UI rendering.
* Dart FFI (`dart:ffi`):** Direct interaction with system memory.
* ffi/pkg: For native memory management (`malloc`/`free`).

## Core Concept: The "Human" UI
In standard debuggers, a Pointer is just a hex address (e.g., `0x7b40`). This tool turns that address into a visual representation of RAM:



1.  Selection: The user enters a value and chooses a data type.
2.  Injection: The app allocates native memory and stores the value.
3.  Visualization: The UI peeks at the allocated bytes and displays them in a structured hex grid.
4.  Endianness: Demonstrates how data is arranged in Little Endian format, common in modern architecture.


This prototype serves as the foundation for my proposal to integrate this view into Dart DevTools.
* VM Service Integration: Fetching memory regions from a running Dart process.
* Safe Dereferencing: Implementing "Safe Peek" logic to prevent Segmentation Faults.
* Struct Support: Visualizing complex C-style structs with proper padding.

