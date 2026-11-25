#!/usr/bin/env python3
"""Generates PalabraDeLaHora.xcodeproj/project.pbxproj.

You only need this if you add/rename files and don't want to do it in Xcode
(or use XcodeGen with project.yml instead). Run from the repo root:
    python3 tools/gen_xcodeproj.py
"""
import hashlib, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP, WIDGET = "PalabraDeLaHora", "PalabraWidgetExtension"

def oid(*parts):
    return hashlib.md5("|".join(parts).encode()).hexdigest()[:24].upper()

def q(v):
    if isinstance(v, list):
        return "(\n" + "".join(f"\t\t\t\t\t{q(x)},\n" for x in v) + "\t\t\t\t)"
    s = str(v)
    if s and re.fullmatch(r"[A-Za-z0-9_./]+", s):
        return s
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

FILETYPES = {
    ".swift": "sourcecode.swift", ".json": "text.json", ".xcassets": "folder.assetcatalog",
    ".plist": "text.plist.xml", ".entitlements": "text.plist.entitlements",
}

groups = {
    "Shared": ["Word.swift", "AppSettings.swift", "WordSchedule.swift", "Speaker.swift",
               "SpeakWordIntent.swift", "SlowSpeech.swift", "Theme.swift", "words.json"],
    "App": ["PalabraApp.swift", "ContentView.swift", "WordCardView.swift", "ReviewView.swift",
            "SettingsView.swift", "NotificationScheduler.swift", "Assets.xcassets", "Info.plist",
            "PalabraDeLaHora.entitlements"],
    "Widget": ["PalabraWidgetBundle.swift", "PalabraWidget.swift", "Assets.xcassets", "Info.plist",
               "PalabraWidgetExtension.entitlements"],
}
for g, files in groups.items():
    for f in files:
        assert (ROOT / g / f).exists(), f"missing {g}/{f}"

fileref = {(g, f): oid("ref", g, f) for g, fs in groups.items() for f in fs}
app_product, widget_product = oid("product", APP), oid("product", WIDGET)

def swift(g): return [f for f in groups[g] if f.endswith(".swift")]

targets = {
    APP: dict(
        sources=[("App", f) for f in swift("App")] + [("Shared", f) for f in swift("Shared")],
        resources=[("App", "Assets.xcassets"), ("Shared", "words.json")],
        product=app_product, product_name=f"{APP}.app", type="com.apple.product-type.application",
    ),
    WIDGET: dict(
        sources=[("Widget", f) for f in swift("Widget")] + [("Shared", f) for f in swift("Shared")],
        resources=[("Widget", "Assets.xcassets"), ("Shared", "words.json")],
        product=widget_product, product_name=f"{WIDGET}.appex", type="com.apple.product-type.app-extension",
    ),
}

o = {}  # id -> (isa, dict) ordered by section
def add(i, isa, **kv): o[i] = (isa, kv)

# File references
for (g, f), i in fileref.items():
    ext = pathlib.Path(f).suffix
    add(i, "PBXFileReference", lastKnownFileType=FILETYPES[ext], path=f, sourceTree="<group>")
add(app_product, "PBXFileReference", explicitFileType="wrapper.application", includeInIndex="0",
    path=f"{APP}.app", sourceTree="BUILT_PRODUCTS_DIR")
add(widget_product, "PBXFileReference", explicitFileType='"wrapper.app-extension"', includeInIndex="0",
    path=f"{WIDGET}.appex", sourceTree="BUILT_PRODUCTS_DIR")

# Groups
main_group, products_group = oid("group", "main"), oid("group", "Products")
for g, fs in groups.items():
    add(oid("group", g), "PBXGroup", children=[fileref[(g, f)] for f in fs], path=g, sourceTree="<group>")
add(products_group, "PBXGroup", children=[app_product, widget_product], name="Products", sourceTree="<group>")
add(main_group, "PBXGroup", children=[oid("group", g) for g in ["App", "Widget", "Shared"]] + [products_group],
    sourceTree="<group>")

# Build files & phases
phases = {}
for t, d in targets.items():
    src_files = []
    for g, f in d["sources"]:
        bf = oid("bf", t, "src", g, f); add(bf, "PBXBuildFile", fileRef=fileref[(g, f)]); src_files.append(bf)
    res_files = []
    for g, f in d["resources"]:
        bf = oid("bf", t, "res", g, f); add(bf, "PBXBuildFile", fileRef=fileref[(g, f)]); res_files.append(bf)
    p_src, p_res, p_fw = oid("phase", t, "src"), oid("phase", t, "res"), oid("phase", t, "fw")
    add(p_src, "PBXSourcesBuildPhase", buildActionMask="2147483647", files=src_files, runOnlyForDeploymentPostprocessing="0")
    add(p_res, "PBXResourcesBuildPhase", buildActionMask="2147483647", files=res_files, runOnlyForDeploymentPostprocessing="0")
    add(p_fw, "PBXFrameworksBuildPhase", buildActionMask="2147483647", files=[], runOnlyForDeploymentPostprocessing="0")
    phases[t] = [p_src, p_fw, p_res]

embed_bf = oid("bf", APP, "embed", WIDGET)
add(embed_bf, "PBXBuildFile", fileRef=widget_product, settings="{ATTRIBUTES = (RemoveHeadersOnCopy, ); }")
embed_phase = oid("phase", APP, "embed")
add(embed_phase, "PBXCopyFilesBuildPhase", buildActionMask="2147483647", dstPath='""', dstSubfolderSpec="13",
    files=[embed_bf], name='"Embed Foundation Extensions"', runOnlyForDeploymentPostprocessing="0")
phases[APP].append(embed_phase)

# Dependency app -> widget
proxy, dep = oid("proxy", WIDGET), oid("dep", WIDGET)
project_id = oid("project")
add(proxy, "PBXContainerItemProxy", containerPortal=project_id, proxyType="1",
    remoteGlobalIDString=oid("target", WIDGET), remoteInfo=WIDGET)
add(dep, "PBXTargetDependency", target=oid("target", WIDGET), targetProxy=proxy)

# Build settings
PROJECT_COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEVELOPMENT_TEAM": "",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    # ⬇︎ Change this one value to your own reverse-DNS prefix. Bundle IDs and the App Group derive from it.
    "PALABRA_BUNDLE_ID": "com.example.palabra",
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "5.0",
}
PROJECT_DEBUG = {**PROJECT_COMMON,
    "DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES", "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0", "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE", "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)", "SWIFT_OPTIMIZATION_LEVEL": "-Onone"}
PROJECT_RELEASE = {**PROJECT_COMMON,
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym", "ENABLE_NS_ASSERTIONS": "NO", "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule", "VALIDATE_PRODUCT": "YES"}

APP_SETTINGS = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_ENTITLEMENTS": "App/PalabraDeLaHora.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_FILE": "App/Info.plist",
    "INFOPLIST_KEY_CFBundleDisplayName": "Palabra",
    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.education",
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "$(PALABRA_BUNDLE_ID)",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "TARGETED_DEVICE_FAMILY": "1",
}
WIDGET_SETTINGS = {
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME": "WidgetBackground",
    "CODE_SIGN_ENTITLEMENTS": "Widget/PalabraWidgetExtension.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_FILE": "Widget/Info.plist",
    "INFOPLIST_KEY_CFBundleDisplayName": "Palabra Widget",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "$(PALABRA_BUNDLE_ID).widget",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SKIP_INSTALL": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "TARGETED_DEVICE_FAMILY": "1",
}

def config_list(owner, debug, release):
    d, r, l = oid("cfg", owner, "Debug"), oid("cfg", owner, "Release"), oid("cfglist", owner)
    add(d, "XCBuildConfiguration", buildSettings=debug, name="Debug")
    add(r, "XCBuildConfiguration", buildSettings=release, name="Release")
    add(l, "XCConfigurationList", buildConfigurations=[d, r], defaultConfigurationIsVisible="0",
        defaultConfigurationName="Release")
    return l

for t, d in targets.items():
    s = APP_SETTINGS if t == APP else WIDGET_SETTINGS
    add(oid("target", t), "PBXNativeTarget",
        buildConfigurationList=config_list(t, s, s),
        buildPhases=phases[t], buildRules=[],
        dependencies=[dep] if t == APP else [],
        name=t, productName=t, productReference=d["product"], productType=q(d["type"]))

add(project_id, "PBXProject",
    attributes=("{\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n\t\t\t\tLastSwiftUpdateCheck = 1600;\n"
                "\t\t\t\tLastUpgradeCheck = 1600;\n\t\t\t\tTargetAttributes = {\n"
                + "".join(f"\t\t\t\t\t{oid('target', t)} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;\n\t\t\t\t\t}};\n" for t in targets)
                + "\t\t\t\t};\n\t\t\t}"),
    buildConfigurationList=config_list("project", PROJECT_DEBUG, PROJECT_RELEASE),
    compatibilityVersion='"Xcode 14.0"', developmentRegion="en", hasScannedForEncodings="0",
    knownRegions=["en", "Base"], mainGroup=main_group, productRefGroup=products_group,
    projectDirPath='""', projectRoot='""', targets=[oid("target", t) for t in targets])

# ---- Serialize
RAW = {"settings", "attributes", "productType", "explicitFileType", "compatibilityVersion",
       "dstPath", "name_raw", "projectDirPath", "projectRoot"}

def val(k, v, indent):
    if isinstance(v, dict):  # buildSettings
        inner = "".join(f"{indent}\t{q(kk)} = {val(kk, vv, indent + chr(9))};\n" for kk, vv in sorted(v.items()))
        return "{\n" + inner + indent + "}"
    if isinstance(v, list):
        if not v: return "(\n" + indent + ")"
        return "(\n" + "".join(f"{indent}\t{x if re.fullmatch(r'[0-9A-F]{24}', str(x)) else q(x)},\n" for x in v) + indent + ")"
    if k in RAW or (k == "name" and str(v).startswith('"')):
        return str(v)
    return q(v)

out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};", "\tobjectVersion = 56;", "\tobjects = {"]
for isa in ["PBXBuildFile", "PBXContainerItemProxy", "PBXCopyFilesBuildPhase", "PBXFileReference",
            "PBXFrameworksBuildPhase", "PBXGroup", "PBXNativeTarget", "PBXProject", "PBXResourcesBuildPhase",
            "PBXSourcesBuildPhase", "PBXTargetDependency", "XCBuildConfiguration", "XCConfigurationList"]:
    items = sorted((i, kv) for i, (t, kv) in o.items() if t == isa)
    if not items: continue
    out.append(f"\n/* Begin {isa} section */")
    for i, kv in items:
        body = "".join(f"\t\t\t{k} = {val(k, v, chr(9)*3)};\n" for k, v in kv.items())
        out.append(f"\t\t{i} = {{\n\t\t\tisa = {isa};\n{body}\t\t}};")
    out.append(f"/* End {isa} section */")
out += ["\t};", f"\trootObject = {project_id};", "}", ""]

dest = ROOT / f"{APP}.xcodeproj" / "project.pbxproj"
dest.parent.mkdir(exist_ok=True)
dest.write_text("\n".join(out))
print("wrote", dest.relative_to(ROOT), f"({len(o)} objects)")
