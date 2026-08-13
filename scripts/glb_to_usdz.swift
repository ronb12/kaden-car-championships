#!/usr/bin/env swift
import Foundation
import ModelIO
import SceneKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("Usage: glb_to_usdz.swift <input.glb> <output.usdz>")
    exit(1)
}

let inputURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])

guard MDLAsset.canImportFileExtension(inputURL.pathExtension) else {
    print("Error: ModelIO cannot import .\(inputURL.pathExtension)")
    exit(1)
}

let asset = MDLAsset(url: inputURL)
asset.loadTextures()

guard MDLAsset.canExportFileExtension("usdz") else {
    print("Error: ModelIO cannot export .usdz")
    exit(1)
}

do {
    try asset.export(to: outputURL)
    print("✓ Exported: \(outputURL.lastPathComponent)")
} catch {
    print("Error: \(error)")
    exit(1)
}
