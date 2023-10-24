# The `slangc` command-line application is just a very thin wrapper
# around the Slang dynamic library, so its build is extremely simple.
# One windows `slangc` uses the `core` library for some UTF-16
# to UTF-8 string conversion before calling into `slang.dll`, so
# it also depends on `core`:
executable('slangc',
  sources : [ 'main.cpp' ],
  link_with : [ core, slang ],
  dependencies : [ dependency('threads') ],
)
