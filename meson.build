project('slang', ['cpp', 'c'],
  default_options : [
    'cpp_std=c++17',
    'warning_level=2',
  ])

################################################################
#
################################################################

foreach native : [false, true]
  add_project_arguments(
    '-Wno-switch',
    '-Wno-parentheses',
    '-Wno-unused-local-typedefs',
    '-Wno-reorder',
    '-Wno-invalid-offsetof',
    # Enable some warnings on clang/gcc which are on by default in MSVC
    '-Wnarrowing',
    language : 'cpp',
    native : native
  )
  if meson.get_compiler('cpp').get_id() == 'gcc'
    add_project_arguments(
      '-Wno-class-memaccess',
      '-Wno-unused-variable',
      '-Wno-unused-parameter',
      '-Wno-sign-compare',
      '-Wno-unused-function',
      '-Wno-unused-value',
      '-Wno-unused-but-set-variable',
      '-Wno-implicit-fallthrough',
      '-Wno-missing-field-initializers',
      # If a function returns an address/reference to a local, we want it to produce an error, because
      # it probably means something very bad.
      '-Werror=return-local-addr',
      language : 'cpp',
      native : native
    )
  elif meson.get_compiler('cpp').get_id() == 'clang'
    add_project_arguments(
      '-Wno-assume',
      language : 'cpp',
      native : native
    )
  endif
endforeach

# Most of the other projects have more interesting configuration going
# on, so let's walk through them in order of increasing complexity#.


################################################################
#
################################################################

subdir('external')
subdir('source/core')
subdir('source/compiler-core')
subdir('tools/slang-cpp-extractor')
subdir('tools/slang-embed')
subdir('tools/slang-generate')
subdir('tools/slang-lookup-generator')
subdir('tools/slang-spirv-embed-generator')
subdir('tools/test-process')
subdir('prelude')
subdir('source/slang')
subdir('source/slangc')
subdir('tools/slangd')
subdir('tools/platform')
subdir('tools/gfx')
subdir('tools/gfx-util')
subdir('tools/slang-test')
subdir('tools/unit-test')
subdir('tools/gfx-unit-test')
subdir('tools/slang-unit-test')
subdir('tools/slang-reflection-test')
subdir('tools/render-test')
subdir('tools/test-server')
subdir('tools/slang-profile')

