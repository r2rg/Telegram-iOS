load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("@build_bazel_rules_apple//apple/internal/resource_rules:apple_metal_library.bzl", "apple_metal_library")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

apple_metal_library(
    name = "LiquidGlassMetalLib",
    srcs = glob(["Resources/**/*.metal"]),
    copts = ["-std=ios-metal2.4"],
)

plist_fragment(
    name = "LiquidGlassMetalBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.LiquidGlassMetal</string>
    <key>CFBundleName</key>
    <string>LiquidGlassMetal</string>
    """
)

apple_resource_bundle(
    name = "LiquidGlassMetalBundle",
    infoplists = [
        ":LiquidGlassMetalBundleInfoPlist",
    ],
    resources = [
        ":LiquidGlassMetalLib",
    ],
)

swift_library(
    name = "LiquidGlassMetal",
    module_name = "LiquidGlassMetal",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":LiquidGlassMetalBundle",
    ],
    deps = [],
    visibility = [
        "//visibility:public",
    ],
)
