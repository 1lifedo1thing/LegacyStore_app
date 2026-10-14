#!/usr/bin/env python3
import os
import re
import sys

sdk = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/theos/sdks/iPhoneOS9.3.sdk")
frameworks = os.path.join(sdk, "System/Library/Frameworks")
cfnetwork_path = os.path.join(frameworks, "CFNetwork.framework/CFNetwork.tbd")
foundation_path = os.path.join(frameworks, "Foundation.framework/Foundation.tbd")
LIST = re.compile(r"(\n    (symbols|objc-classes|objc-ivars):\s*)\[(.*?)\]", re.S)

def lists(text):
    found = {}
    for m in LIST.finditer(text):
        found.setdefault(m.group(2), m)
    return found

def items(match):
    return [s.strip() for s in match.group(3).replace("\n", " ").split(",") if s.strip()]

def render(key, values):
    lines, line = [], ""
    for v in values:
        piece = v + ", "
        if len(line) + len(piece) > 90 and line:
            lines.append(line.rstrip())
            line = ""
        line += piece
    lines.append(line.rstrip(", "))
    indent = "\n" + " " * 24
    return "\n    %s:%s[ %s ]" % (key, " " * (19 - len(key)), indent.join(lines))

def rewrite(text, new_lists):
    found = lists(text)
    for key, match in sorted(found.items(), key=lambda kv: -kv[1].start()):
        if key in new_lists:
            text = text[:match.start()] + render(key, new_lists[key]) + text[match.end():]
    return text

cf_text = open(cfnetwork_path).read()
fd_text = open(foundation_path).read()
cf_lists, fd_lists = lists(cf_text), lists(fd_text)

cf_new, fd_new, moved = {}, {}, 0
for key in ("symbols", "objc-classes", "objc-ivars"):
    cf_items = items(cf_lists[key]) if key in cf_lists else []
    fd_items = items(fd_lists[key]) if key in fd_lists else []
    move = [s for s in cf_items if s.startswith("_NS")]
    moved += len(move)
    cf_new[key] = [s for s in cf_items if not s.startswith("_NS")] or ["_CFNetworkPatchedPlaceholder"]
    fd_new[key] = sorted(set(fd_items) | set(move))

if moved == 0:
    print("already patched")
    sys.exit(0)

open(cfnetwork_path, "w").write(rewrite(cf_text, cf_new))
open(foundation_path, "w").write(rewrite(fd_text, fd_new))
print("moved %d symbols from CFNetwork to Foundation" % moved)
