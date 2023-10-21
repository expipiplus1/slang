render_test_defs = []
if get_option('enable-cuda')
  render_test_defs += [ '-DRENDER_TEST_CUDA' ]
endif

library('render-test',
  sources : [
    'diagnostics.cpp',
    'options.cpp',
    'png-serialize-util.cpp',
    'render-test-main.cpp',
    'shader-input-layout.cpp',
    'shader-renderer-util.cpp',
    'slang-support.cpp',
  ],
  cpp_args : render_test_defs,
  include_directories : [
    '../../',
    '../../source',
    '../../tools/platform',
  ],
  link_with : [ core, compiler_core, slang, gfx, gfx_util, platform ],
)
