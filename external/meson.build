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

miniz = static_library('miniz',
  sources : [
    'miniz/miniz.c',
    'miniz/miniz_tdef.c',
    'miniz/miniz_tinfl.c',
    'miniz/miniz_zip.c',
  ],
  c_args : miniz_defs,
  dependencies : miniz_deps
)

################################################################
# LZ4
################################################################

if host_machine.system() == 'linux' or host_machine.system() == 'darwin'
  lz4_deps = meson.get_compiler('c').find_library('dl')
else
  lz4_deps = []
endif

lz4 = static_library('lz4',
  sources : [ 'lz4/lib/lz4.c' ],
  dependencies : lz4_deps
)
