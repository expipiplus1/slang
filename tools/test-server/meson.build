executable('test-server',
  sources : [
    'test-server-diagnostics.cpp',
    'test-server-main.cpp',
  ],
  include_directories : [ include_directories('../../') ],
  cpp_args : [ '-Wno-unused-variable', '-Wno-unused-parameter', '-Wno-sign-compare' ],
  link_with : [ core, compiler_core, slang ],
)
