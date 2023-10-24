platform_defs = [ '-DSLANG_PLATFORM_DYNAMIC', '-DSLANG_PLATFORM_DYNAMIC_EXPORT' ]
platform_deps = []

if X11.found()
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
  link_with : [ core ],
  cpp_args : platform_defs,
  dependencies : platform_deps,
)
