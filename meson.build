project('slang', ['cpp', 'c'],
  version : '2023.4.0',
  default_options : [
    'cpp_std=c++17',
    # corresponds to -Wall -Wextra
    'warning_level=2',
    # link with /MT or /MTd
    'b_vscrt=static_from_buildtype',
    # Build static libraries as position independent
    'b_staticpic=true',
    # Disable asserts in release builds
    'b_ndebug=true',
    # Don't allow undefined symbols when linking
    'b_lundef=true',
    'b_asneeded=false',
  ])

################################################################
# boilerplate
################################################################

fs = import('fs')

################################################################
# Compiler options used for every project
################################################################

# These compiler arguments are passed if the compiler supports them
desired_args = [
  # Disabled warnings:

  '-Wno-switch',
  '-Wno-parentheses',
  '-Wno-unused-local-typedefs',
  '-Wno-class-memaccess',
  '-Wno-assume',
  '-Wno-reorder',
  '-Wno-invalid-offsetof',

  # Enabled warnings:

  # If a function returns an address/reference to a local, we want it to
  # produce an error, because it probably means something very bad.
  '-Werror=return-local-addr',
  # This approximates the default in MSVC
  '-Wnarrowing',

  # Flags:

  # Makes all symbols hidden by default unless explicitly 'exported'
  'fvisibility=hidden',
]

desired_linker_args = [
  '-Wl,--no-as-needed'
]

defines = [
  # For including windows.h in a way that minimized namespace pollution.
  # Although we define these here, we still set them manually in any header
  # files which may be included by another project
  '-DWIN32_LEAN_AND_MEAN',
  '-DVC_EXTRALEAN',
  '-DNOMINMAX',
  '-D_ITERATOR_DEBUG_LEVEL=0'
]

if get_option('enable-dx-on-vk')
  defines += '-DSLANG_CONFIG_DX_ON_VK'
endif

# When compiling the debug configuration, we want to turn optimization off,
# make sure debug symbols are output, and add the same preprocessor definition
# that VS would add by default.
if get_option('debug')
  desired_args += [ '-D_DEBUG' ]
endif

# Project arguments are per language and per toolchain, in our case native and
# host
foreach native : [false, true]
  foreach language : ['c', 'cpp']
    compiler = meson.get_compiler(language, native : native)

    foreach a : desired_args
      if compiler.has_argument(a)
        add_project_arguments(a, language : language, native : native)
      endif
    endforeach

    foreach a : desired_linker_args
      if compiler.has_link_argument(a)
        add_project_link_arguments(a, language : language, native : native)
      endif
    endforeach

    foreach d : defines
      add_project_arguments(d, language : language, native : native)
    endforeach

    # if meson.get_compiler('cpp').get_id() == 'gcc'
    #   add_project_arguments(
    #     '-Wno-class-memaccess',
    #     '-Wno-unused-variable',
    #     '-Wno-unused-parameter',
    #     '-Wno-sign-compare',
    #     '-Wno-unused-function',
    #     '-Wno-unused-value',
    #     '-Wno-unused-but-set-variable',
    #     '-Wno-implicit-fallthrough',
    #     '-Wno-missing-field-initializers',
    #     # If a function returns an address/reference to a local, we want it to produce an error, because
    #     # it probably means something very bad.
    #     '-Werror=return-local-addr',
    #     language : 'cpp',
    #     native : native
    #   )
    # elif meson.get_compiler('cpp').get_id() == 'clang'
    #   add_project_arguments(
    #     '-Wno-assume',
    #     language : 'cpp',
    #     native : native
    #   )
    # endif
  endforeach
endforeach

################################################################
# Dependencies
################################################################

# Aftermath
aftermath_path = 'external/nv-aftermath'
aftermath_include_dir = aftermath_path / 'include'
meson.get_compiler('cpp', native : false).has_header(
  'GFSDK_Aftermath.h',
  args : [ '-I' +  aftermath_include_dir ],
  required : get_option('enable-aftermath'),
)

# NVAPI
nvapi_path = 'external/nvapi'
nvapi_include_dir = nvapi_path
meson.get_compiler('cpp', native : false).has_header(
  'nvapi.h',
  args : [ '-I' + nvapi_include_dir ],
  required : get_option('enable-nvapi'),
)
if get_option('enable-nvapi').enabled() and not host_machine.system() == 'windows'
  error('nvapi is only available on Windows')
endif

# CUDA
meson.get_compiler('cpp', native : false).has_header(
  'cuda.h',
  required : get_option('enable-cuda'),
)

# OptiX
optix_path = get_option('optix-sdk-path')
if optix_path == '' and build_machine.system() == 'windows'
  optix_path = 'C:/ProgramData/NVIDIA Corporation/OptiX SDK 7.0.0/'
endif
optix_include_dir = optix_path / 'include'
meson.get_compiler('cpp', native : false).has_header(
  'optix.h',
  args : optix_path != '' ? [ '-I' + optix_include_dir ] : [],
  required : get_option('enable-optix'),
)

if get_option('enable-optix').enabled() and not get_option('enable-cuda').enabled()
  error('enable-optix requires enable-cuda')
endif

X11 = dependency('x11', required : get_option('enable-xlib'))

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

