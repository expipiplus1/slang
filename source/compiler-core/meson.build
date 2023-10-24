compiler_core_source = [
  'slang-artifact-associated-impl.cpp',
  'slang-artifact-container-util.cpp',
  'slang-artifact-desc-util.cpp',
  'slang-artifact-diagnostic-util.cpp',
  'slang-artifact-handler-impl.cpp',
  'slang-artifact-helper.cpp',
  'slang-artifact-impl.cpp',
  'slang-artifact-representation-impl.cpp',
  'slang-artifact-util.cpp',
  'slang-command-line-args.cpp',
  'slang-core-diagnostics.cpp',
  'slang-diagnostic-sink.cpp',
  'slang-doc-extractor.cpp',
  'slang-downstream-compiler-set.cpp',
  'slang-downstream-compiler-util.cpp',
  'slang-downstream-compiler.cpp',
  'slang-dxc-compiler.cpp',
  'slang-fxc-compiler.cpp',
  'slang-gcc-compiler-util.cpp',
  'slang-glslang-compiler.cpp',
  'slang-include-system.cpp',
  'slang-json-diagnostics.cpp',
  'slang-json-lexer.cpp',
  'slang-json-native.cpp',
  'slang-json-parser.cpp',
  'slang-json-rpc-connection.cpp',
  'slang-json-rpc.cpp',
  'slang-json-source-map-util.cpp',
  'slang-json-value.cpp',
  'slang-language-server-protocol.cpp',
  'slang-lexer.cpp',
  'slang-llvm-compiler.cpp',
  'slang-name-convention-util.cpp',
  'slang-name.cpp',
  'slang-nvrtc-compiler.cpp',
  'slang-perfect-hash.cpp',
  'slang-slice-allocator.cpp',
  'slang-source-embed-util.cpp',
  'slang-source-loc.cpp',
  'slang-source-map.cpp',
  'slang-spirv-core-grammar.cpp',
  'slang-test-server-protocol.cpp',
  'slang-token.cpp',
  'slang-visual-studio-compiler-util.cpp',
]
if host_machine.system() == 'windows'
  compiler_core_source += 'windows/slang-win-visual-studio-util.cpp'
endif

# For the DXC headers
compiler_core_desired_args = [ '-fms-extensions' ]

compiler_core_build_args = []
compiler_core_host_args = []
foreach a : compiler_core_desired_args
  if meson.get_compiler('cpp', native : false).has_argument(a)
    compiler_core_host_args += [a]
  endif
  if meson.get_compiler('cpp', native : true).has_argument(a)
    compiler_core_build_args += [a]
  endif
endforeach

compiler_core = static_library('compiler-core',
  sources : compiler_core_source,
  cpp_args : compiler_core_host_args,
  link_with : core,
)

compiler_core_native = static_library('compiler-core-native',
  sources : compiler_core_source,
  cpp_args : compiler_core_build_args,
  link_with : core_native,
  native : true,
)
