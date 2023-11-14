#
# Given a list of flags, add those which the C++ compiler supports to the target
#
function(add_supported_cxx_flags target)
    cmake_parse_arguments(ARG "PRIVATE;PUBLIC;INTERFACE" "" "" ${ARGN})
    set(flags ${ARG_UNPARSED_ARGUMENTS})
    if(ARG_PRIVATE)
        set(private PRIVATE)
    endif()
    if(ARG_PUBLIC)
        set(public PUBLIC)
    endif()
    if(ARG_INTERFACE)
        set(interface INTERFACE)
    endif()

    foreach(flag ${flags})
        # remove the `no-` prefix from warnings because gcc doesn't treat it as an
        # error on its own
        string(REGEX REPLACE "\\-Wno\\-(.+)" "-W\\1" flag_to_test "${flag}")
        string(
            REGEX REPLACE
            "[^a-zA-Z0-9]+"
            "_"
            test_name
            "CXXFLAG_${flag_to_test}"
        )
        check_cxx_compiler_flag("${flag_to_test}" ${test_name})
        if(${test_name})
            target_compile_options(${target} ${private} ${public} ${interface} ${flag})
        endif()
    endforeach()
endfunction()

#
# Given a list of linker flags, add those which the compiler supports to the
# target
#
include(CheckLinkerFlag)
function(add_supported_cxx_linker_flags target)
    cmake_parse_arguments(ARG "PRIVATE;PUBLIC;INTERFACE;BEFORE" "" "" ${ARGN})
    set(flags ${ARG_UNPARSED_ARGUMENTS})
    if(ARG_BEFORE)
        set(before BEFORE)
    endif()
    if(ARG_PRIVATE)
        set(private PRIVATE)
    endif()
    if(ARG_PUBLIC)
        set(public PUBLIC)
    endif()
    if(ARG_INTERFACE)
        set(interface INTERFACE)
    endif()

    foreach(flag ${flags})
        string(
            REGEX REPLACE
            "[^a-zA-Z0-9]+"
            "_"
            test_name
            "CXXLINKFLAG_${flag}"
        )
        check_linker_flag(CXX "${flag}" ${test_name})
        if(${test_name})
            target_link_options(
                ${target}
                ${before}
                ${private}
                ${public}
                ${interface}
                ${flag}
            )
        endif()
    endforeach()
endfunction()

#
# Add our default compiler flags to a target
#
# Pass USE_EXTRA_WARNINGS to enable -WExtra or /W3
#
function(set_default_compile_options target)
    cmake_parse_arguments(
        ARG
        "USE_EXTRA_WARNINGS;USE_FEWER_WARNINGS"
        ""
        ""
        ${ARGN}
    )

    set(warning_flags
        # Disabled warnings:
        -Wno-switch
        -Wno-parentheses
        -Wno-unused-local-typedefs
        -Wno-class-memaccess
        -Wno-assume
        -Wno-reorder
        -Wno-invalid-offsetof
        # Enabled warnings: If a function returns an address/reference to a local,
        # we want it to produce an error, because it probably means something very
        # bad.
        -Werror=return-local-addr
        # This approximates the default in MSVC
        -Wnarrowing
    )

    if(ARG_USE_EXTRA_WARNINGS)
        list(APPEND warning_flags -Wall -Wextra /W3)
    elseif(ARG_USE_FEWER_WARNINGS)
        list(
            APPEND
            warning_flags
            /W1
            -Wall
            -Wno-class-memaccess
            -Wno-unused-variable
            -Wno-unused-parameter
            -Wno-sign-compare
            -Wno-unused-function
            -Wno-unused-value
            -Wno-unused-but-set-variable
            -Wno-implicit-fallthrough
            -Wno-missing-field-initializers
            -Wno-strict-aliasing
            -Wno-maybe-uninitialized
        )
    else()
        list(APPEND warning_flags -Wall /W2)
    endif()

    add_supported_cxx_flags(${target} PRIVATE ${warning_flags})

    # Don't assume that symbols will be resolved at runtime
    add_supported_cxx_linker_flags(${target} PRIVATE "-Wl,--no-undefined")

    set_target_properties(
        ${target}
        PROPERTIES # -fvisibility=hidden
            CXX_VISIBILITY_PRESET
            hidden
            # C++ standard
            CXX_STANDARD
            17
            # pic
            POSITION_INDEPENDENT_CODE
            ON
    )

    target_compile_definitions(
        ${target}
        PRIVATE # Add _DEBUG depending on the build configuration
            $<$<CONFIG:Debug>:_DEBUG>
            # For including windows.h in a way that minimized namespace
            # pollution. Although we define these here, we still set them
            # manually in any header files which may be included by another
            # project
            WIN32_LEAN_AND_MEAN
            VC_EXTRALEAN
            NOMINMAX
            # Disable slow stdlib debug functionality for MSVC
            _ITERATOR_DEBUG_LEVEL=0
    )

    #
    # Settings dependent on config options
    #

    if(SLANG_ENABLE_FULL_DEBUG_VALIDATION)
        target_compile_definitions(
            ${target}
            PRIVATE SLANG_ENABLE_FULL_IR_VALIDATION
        )
    endif()

    if(SLANG_ENABLE_DX_ON_VK)
        target_compile_definitions(${target} PRIVATE SLANG_CONFIG_DX_ON_VK)
    endif()

    if(SLANG_ENABLE_XLIB)
        target_compile_definitions(${target} PRIVATE SLANG_ENABLE_XLIB)
    endif()

    if(SLANG_ENABLE_ASAN)
        add_supported_cxx_flags(${target} PRIVATE /fsanitize=address -fsanitize=address)
        add_supported_cxx_linker_flags(
            ${target}
            BEFORE
            PUBLIC
            /INCREMENTAL:NO
            -fsanitize=address
        )
    endif()
endfunction()