################################################################
# Miniz
################################################################

if host_machine.system() == 'linux'
  miniz_defs = [
    '-D_LARGEFILE64_SOURCE'
  ]
else
  miniz_defs = []
endif

if host_machine.system() == 'linux' or host_machine.system() == 'darwin'
  miniz_deps = meson.get_compiler('c').find_library('dl')
else
  miniz_deps = []
endif

miniz_source = [
  'miniz/miniz.c',
  'miniz/miniz_tdef.c',
  'miniz/miniz_tinfl.c',
  'miniz/miniz_zip.c',
]
miniz = static_library('miniz',
  sources : miniz_source,
  c_args : miniz_defs,
  dependencies : miniz_deps,
)
miniz_native = static_library('miniz-native',
  sources : miniz_source,
  c_args : miniz_defs,
  dependencies : miniz_deps,
  native : true,
)

################################################################
# LZ4
################################################################

if host_machine.system() == 'linux' or host_machine.system() == 'darwin'
  lz4_deps = meson.get_compiler('c').find_library('dl')
else
  lz4_deps = []
endif

lz4_source = [ 'lz4/lib/lz4.c' ]
lz4 = static_library('lz4',
  sources : lz4_source,
  dependencies : lz4_deps,
)
lz4_native = static_library('lz4-native',
  sources : lz4_source,
  dependencies : lz4_deps,
  native : true,
)
