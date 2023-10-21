platform_defs = [ '-DSLANG_PLATFORM_DYNAMIC', '-DSLANG_PLATFORM_DYNAMIC_EXPORT' ]
platform_deps = []

if get_option('enable-xlib')
  X11 = dependency('x11', required : true)
  platform_defs += [ '-DSLANG_ENABLE_XLIB' ]
  platform_deps += [ X11 ]
endif

platform = library('platform',
  sources : [
    'gui.cpp',
    'linux/x11-key-code.cpp',
    'linux/x11-window.cpp',
    'model.cpp',
    'placeholder/placeholder-window.cpp',
    'windows/win-window.cpp',
  ],
  include_directories : [
    '../../',
    '../gfx',
    '../../source',
    '../../external',
  ],
  pic : true,
  link_with : [ core ],
  cpp_args : platform_defs,
  dependencies : platform_deps,
)
