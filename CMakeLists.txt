cmake_minimum_required(VERSION 3.4)
project(seraph)

add_custom_target(
        COMMAND /Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/swift build
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        SOURCES
        Package.swift
        Sources/main.swift
        Sources/utils.swift
        Sources/socket.swift
        Sources/log.swift
        Sources/json.swift
        Sources/model.swift
        Sources/io.swift
        Sources/enum.swift
        Sources/controller.swift
        Sources/action.swift
        Sources/wsHandler.swift
        Sources/wsProtocol.swift
        Sources/sha1.swift
        Sources/httpProtocol.swift)
