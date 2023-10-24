# The `core` project is a static library that has all the basic types
# and routines that get shared across both the Slang compiler/runtime
# and the various tool projects.

core_source = [
  'slang-archive-file-system.cpp',
  'slang-blob.cpp',
  'slang-byte-encode-util.cpp',
  'slang-castable.cpp',
  'slang-char-encode.cpp',
  'slang-char-util.cpp',
  'slang-command-line.cpp',
  'slang-command-options-writer.cpp',
  'slang-command-options.cpp',
  'slang-crypto.cpp',
  'slang-deflate-compression-system.cpp',
  'slang-file-system.cpp',
  'slang-free-list.cpp',
  'slang-hex-dump-util.cpp',
  'slang-http.cpp',
  'slang-implicit-directory-collector.cpp',
  'slang-io.cpp',
  'slang-lz4-compression-system.cpp',
  'slang-memory-arena.cpp',
  'slang-memory-file-system.cpp',
  'slang-name-value.cpp',
  'slang-offset-container.cpp',
  'slang-performance-profiler.cpp',
  'slang-persistent-cache.cpp',
  'slang-platform.cpp',
  'slang-process-util.cpp',
  'slang-random-generator.cpp',
  'slang-render-api-util.cpp',
  'slang-riff-file-system.cpp',
  'slang-riff.cpp',
  'slang-rtti-info.cpp',
  'slang-rtti-util.cpp',
  'slang-semantic-version.cpp',
  'slang-shared-library.cpp',
  'slang-signal.cpp',
  'slang-std-writers.cpp',
  'slang-stream.cpp',
  'slang-string-escape-util.cpp',
  'slang-string-slice-index-map.cpp',
  'slang-string-slice-pool.cpp',
  'slang-string-util.cpp',
  'slang-string.cpp',
  'slang-test-tool-util.cpp',
  'slang-text-io.cpp',
  'slang-token-reader.cpp',
  'slang-type-convert-util.cpp',
  'slang-type-text-util.cpp',
  'slang-uint-set.cpp',
  'slang-writer.cpp',
  'slang-zip-file-system.cpp',
]

if host_machine.system() == 'windows'
  core_source += 'windows/slang-win-process.cpp'
elif host_machine.system() == 'linux'
  core_source += 'unix/slang-unix-process.cpp'
endif


core = static_library('core',
  sources : core_source,
)

core_native = static_library('core-native',
    sources : core_source,
    native : true,
  )

slang_rt_source = core_source
slang_rt = library('slang-rt',
  sources : slang_rt_source,
  link_with : [miniz, lz4],
  cpp_args : ['-DSLANG_RT_DYNAMIC', '-DSLANG_RT_DYNAMIC_EXPORT'],
  dependencies : dependency('threads'),
)
