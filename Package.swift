// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
// Package.swift
import PackageDescription

let package = Package(
    name: "AppCloser",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AppCloser",
            dependencies: []),
    ]
)
