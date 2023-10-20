prelude_inputs = [
  'slang-cpp-host-prelude.h',
  'slang-cpp-prelude.h',
  'slang-cuda-prelude.h',
  'slang-hlsl-prelude.h',
  'slang-torch-prelude.h',
]

prelude_source = []
foreach input : prelude_inputs
  prelude_source += custom_target(
    command : [ slang_embed, '@INPUT@', '@OUTPUT@'],
    output : [ '@PLAINNAME@.cpp' ],
    input : input,
  )
endforeach
