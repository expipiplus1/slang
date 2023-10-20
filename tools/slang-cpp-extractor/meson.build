# The cpp extractor is a tool that scans C++ header files to extract
# reflection like information, and generate files to handle
# RTTI fast/simply
cpp_extractor = executable('slang-cpp-extractor',
  sources : [
    'cpp-extractor-main.cpp',
    'diagnostics.cpp',
    'file-util.cpp',
    'identifier-lookup.cpp',
    'macro-writer.cpp',
    'node-tree.cpp',
    'node.cpp',
    'options.cpp',
    'parser.cpp',
    'unit-test.cpp',
  ],
  link_with : [ core_native, compiler_core_native ],
  cpp_args : [ '-Wno-unused-but-set-variable', '-Wno-unused-function', '-Wno-unused-parameter', '-Wno-implicit-fallthrough' ],
  native : true,
)
