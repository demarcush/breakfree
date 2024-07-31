#!/usr/bin/env python3

import json
import sys

# servers file = argv[1], template file = argv[2], dest file = argv[3]
servers = sys.argv[1]
template = sys.argv[2]
dest = sys.argv[3]

with open(servers, "r") as src_file:
    src = json.load(src_file)

with open(template, "r") as template_file:
    dst = json.load(template_file)

servers_tags = src["outbounds"][3]["outbounds"]
del src["outbounds"][3]
del src["outbounds"][2]
del src["outbounds"][1]
del src["outbounds"][0]
servers = src["outbounds"]
dst["outbounds"][2]["outbounds"].extend(servers_tags)
dst["outbounds"][1]["outbounds"].extend(servers_tags)
dst["outbounds"].extend(servers)

with open(dest, "w") as dst_file:
    json.dump(dst, dst_file, sort_keys=True, separators=(',', ':'))
