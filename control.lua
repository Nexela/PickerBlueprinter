local Player = require('__stdlib__/stdlib/event/player')
local Force = require('__stdlib__/stdlib/event/force')

Player.register_events(true)
Force.register_events(true)

require('scripts/blueprinter')
require('scripts/deconstruction')
require('scripts/bpmirror')
require('scripts/bpupdater')
require('scripts/bpsnap')

remote.add_interface(script.mod_name, require('__stdlib__/stdlib/scripts/interface'))
