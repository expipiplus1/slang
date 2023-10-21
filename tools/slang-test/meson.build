executable('slang-test',
  sources : [
    'directory-util.cpp',
    'options.cpp',
    'parse-diagnostic-util.cpp',
    'slang-test-main.cpp',
    'slangc-tool.cpp',
    'test-context.cpp',
    'test-reporter.cpp',
  ],
  include_directories : [ '../../' ],
  link_with : [ core, compiler_core, slang, miniz, lz4 ],
  dependencies : dependency('threads'),
)
