fx_version "cerulean"
lua54 "yes"
games { "rdr3" }
rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."

name "gs_interact"
author "_G[S]cripts"
description "Look-at world interact points with multi-option prompts"
version "1.0.0"
license "PolyForm-Noncommercial-1.0.0"

shared_scripts {
    "config.lua",
}

client_scripts {
    "client/main.lua",
    "client/api.lua",
}
