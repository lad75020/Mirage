#!/usr/bin/env python3
"""Add the LiteRT Swift sources to the Mirage pbxproj:
- PBXFileReference for each new file
- a new 'LiteRT' PBXGroup under ImageGeneration
- PBXBuildFile + Sources-phase entries for MirageApp (05640FEA...) and
  MirageMacApp (A05AF7B3...) which both compile the feature sources.
"""
import re

PBX = "Mirage.xcodeproj/project.pbxproj"

FILES = [
    ("LiteRTGraph.swift", "7B17E5D0F1D24A6B8C3D9E10", "7B17E5D1F1D24A6B8C3D9E11", "7B17E5D2F1D24A6B8C3D9E12"),
    ("SafetensorsFile.swift", "7B17E5D3F1D24A6B8C3D9E13", "7B17E5D4F1D24A6B8C3D9E14", "7B17E5D5F1D24A6B8C3D9E15"),
    ("QwenTokenizer.swift", "7B17E5D6F1D24A6B8C3D9E16", "7B17E5D7F1D24A6B8C3D9E17", "7B17E5D8F1D24A6B8C3D9E18"),
    ("ZImageLiteRTPipeline.swift", "7B17E5D9F1D24A6B8C3D9E19", "7B17E5DAF1D24A6B8C3D9E1A", "7B17E5DBF1D24A6B8C3D9E1B"),
    ("LiteRTEngineDriver.swift", "7B17E5DCF1D24A6B8C3D9E1C", "7B17E5DDF1D24A6B8C3D9E1D", "7B17E5DEF1D24A6B8C3D9E1E"),
]
GROUP_ID = "7B17E5CFF1D24A6B8C3D9E0F"
IOS_SOURCES = "05640FEA7B03E3C02A854258"
MAC_SOURCES = "A05AF7B3101122BFBD7695D4"

src = open(PBX).read()

# 1. PBXFileReference entries
file_refs = "".join(
    f"\t\t{ref} /* {name} */ = {{isa = PBXFileReference; "
    f"lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n"
    for name, ref, _, _ in FILES
)
anchor = "/* Begin PBXFileReference section */\n"
src = src.replace(anchor, anchor + file_refs, 1)

# 2. PBXBuildFile entries (one per target)
build_files = "".join(
    f"\t\t{ios} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n"
    f"\t\t{mac} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n"
    for name, ref, ios, mac in FILES
)
anchor = "/* Begin PBXBuildFile section */\n"
src = src.replace(anchor, anchor + build_files, 1)

# 3. LiteRT group + attach to ImageGeneration group children
children = "".join(f"\t\t\t\t{ref} /* {name} */,\n" for name, ref, _, _ in FILES)
group = (
    f"\t\t{GROUP_ID} /* LiteRT */ = {{\n"
    f"\t\t\tisa = PBXGroup;\n"
    f"\t\t\tchildren = (\n{children}\t\t\t);\n"
    f"\t\t\tpath = LiteRT;\n"
    f"\t\t\tsourceTree = \"<group>\";\n"
    f"\t\t}};\n"
)
anchor = "/* Begin PBXGroup section */\n"
src = src.replace(anchor, anchor + group, 1)

pattern = re.compile(
    r"([0-9A-F]{24} /\* ImageGeneration \*/ = \{\s*isa = PBXGroup;\s*children = \(\n)", re.S
)
src = pattern.sub(rf"\g<1>\t\t\t\t{GROUP_ID} /* LiteRT */,\n", src, count=1)

# 4. Sources phases
for phase, column in ((IOS_SOURCES, 2), (MAC_SOURCES, 3)):
    entries = "".join(
        f"\t\t\t\t{item[column]} /* {item[0]} in Sources */,\n" for item in FILES
    )
    pattern = re.compile(rf"({phase} /\* Sources \*/ = \{{[^}}]*?files = \(\n)", re.S)
    src = pattern.sub(rf"\g<1>{entries}", src, count=1)

open(PBX, "w").write(src)
print("pbxproj updated")
