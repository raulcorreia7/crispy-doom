set(CRISPY_DMCP_WINDOWS_IMPORT_LIBRARY "dmcp.lib")
set(CRISPY_DMCP_WINDOWS_RUNTIME_LIBRARY "dmcp.dll")
set(CRISPY_DMCP_LINUX_RUNTIME_LIBRARY "libdmcp.so")
set(CRISPY_DMCP_MACOS_RUNTIME_LIBRARY "libdmcp.dylib")

function(crispy_dmcp_configure)
    if(NOT DMCP_ENABLE)
        return()
    endif()

    set(resolved_dmcp_root "${DMCP_ROOT}")
    if(NOT resolved_dmcp_root AND NOT "$ENV{dmcp_DIR}" STREQUAL "")
        set(resolved_dmcp_root "$ENV{dmcp_DIR}")
    endif()
    if(NOT resolved_dmcp_root)
        message(FATAL_ERROR "DMCP_ENABLE=ON requires DMCP_ROOT to be set")
    endif()

    set(resolved_adapter_dir "${DMCP_ADAPTER_DIR}")
    if(NOT resolved_adapter_dir)
        set(resolved_adapter_dir "${resolved_dmcp_root}/adapters/crispy-doom")
    endif()

    if(NOT EXISTS "${resolved_adapter_dir}/include/engine_hooks.h")
        message(FATAL_ERROR "DMCP adapter not found at ${resolved_adapter_dir}")
    endif()
    if(NOT EXISTS "${resolved_dmcp_root}/include/dmcp/doom/api.h")
        message(FATAL_ERROR "DMCP headers not found at ${resolved_dmcp_root}/include")
    endif()

    set(resolved_build_dir "${DMCP_BUILD_DIR}")
    if(NOT resolved_build_dir AND NOT "$ENV{DMCP_BUILD_DIR}" STREQUAL "")
        set(resolved_build_dir "$ENV{DMCP_BUILD_DIR}")
    endif()
    if(NOT resolved_build_dir)
        set(resolved_build_dir "${resolved_dmcp_root}/build/default")
    endif()

    set(resolved_library_dir "${DMCP_LIBRARY_DIR}")
    if(NOT resolved_library_dir AND NOT "$ENV{DMCP_LIBRARY_DIR}" STREQUAL "")
        set(resolved_library_dir "$ENV{DMCP_LIBRARY_DIR}")
    endif()

    set(DMCP_ROOT "${resolved_dmcp_root}" CACHE PATH "Path to DMCP SDK root directory" FORCE)
    set(DMCP_ADAPTER_DIR "${resolved_adapter_dir}" CACHE PATH
        "Path to DMCP Crispy adapter directory" FORCE)
    set(DMCP_BUILD_DIR "${resolved_build_dir}" CACHE PATH
        "Path to DMCP CMake build directory" FORCE)
    set(DMCP_LIBRARY_DIR "${resolved_library_dir}" CACHE PATH
        "Directory containing built DMCP libraries" FORCE)
    set(DMCP_ROOT "${resolved_dmcp_root}" PARENT_SCOPE)
    set(DMCP_ADAPTER_DIR "${resolved_adapter_dir}" PARENT_SCOPE)
    set(DMCP_BUILD_DIR "${resolved_build_dir}" PARENT_SCOPE)
    set(DMCP_LIBRARY_DIR "${resolved_library_dir}" PARENT_SCOPE)

    add_compile_definitions(DMCP=1)
    message(STATUS "DMCP enabled: adapter at ${resolved_adapter_dir}")
    message(STATUS "DMCP frame capture: ${DMCP_FRAME_CAPTURE}")
    message(STATUS "DMCP build dir: ${resolved_build_dir}")
endfunction()

function(crispy_dmcp_adapter_sources out_var)
    if(NOT DMCP_ENABLE)
        set(${out_var} "" PARENT_SCOPE)
        return()
    endif()

    file(GLOB_RECURSE sources CONFIGURE_DEPENDS
        "${DMCP_ADAPTER_DIR}/src/*.c"
    )
    list(APPEND sources "${DMCP_ROOT}/adapters/common/src/dmcp_hooks.c")
    list(SORT sources)
    set(${out_var} "${sources}" PARENT_SCOPE)
endfunction()

function(crispy_dmcp_apply_to_doom target)
    if(NOT DMCP_ENABLE)
        return()
    endif()

    target_include_directories(${target} PRIVATE
        "${DMCP_ADAPTER_DIR}/include"
        "${DMCP_ROOT}/include"
        "${DMCP_ROOT}/adapters/common/include"
        "${DMCP_BUILD_DIR}/generated/include"
        "${DMCP_BUILD_DIR}"
        "${DMCP_ROOT}/build"
        "${CMAKE_CURRENT_SOURCE_DIR}/.."
        "${CMAKE_CURRENT_SOURCE_DIR}"
        "${CMAKE_CURRENT_BINARY_DIR}/../.."
    )

    if(DMCP_FRAME_CAPTURE)
        target_compile_definitions(${target} PRIVATE DMCP_CRISPY_ENABLE_FRAME_CAPTURE=1)
    else()
        target_compile_definitions(${target} PRIVATE DMCP_CRISPY_ENABLE_FRAME_CAPTURE=0)
    endif()

    crispy_dmcp_adapter_sources(DMCP_ADAPTER_SOURCES)
    target_sources(${target} PRIVATE ${DMCP_ADAPTER_SOURCES})
endfunction()

function(crispy_dmcp_link_libraries out_var)
    set(link_libraries "${${out_var}}")
    if(NOT DMCP_ENABLE)
        set(${out_var} "${link_libraries}" PARENT_SCOPE)
        return()
    endif()

    set(dmcp_library_bases)
    foreach(dmcp_base IN ITEMS
        "${DMCP_LIBRARY_DIR}"
        "${DMCP_BUILD_DIR}"
        "${DMCP_ROOT}/build/default"
        "${DMCP_ROOT}/build/shared"
        "${DMCP_ROOT}/build/integration"
        "${DMCP_ROOT}/build")
        if(NOT "${dmcp_base}" STREQUAL "")
            list(APPEND dmcp_library_bases "${dmcp_base}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES dmcp_library_bases)

    set(dmcp_library_dirs)
    foreach(dmcp_base IN LISTS dmcp_library_bases)
        list(APPEND dmcp_library_dirs
            "${dmcp_base}"
            "${dmcp_base}/Release"
            "${dmcp_base}/RelWithDebInfo"
            "${dmcp_base}/Debug"
            "${dmcp_base}/MinSizeRel")
    endforeach()
    list(REMOVE_DUPLICATES dmcp_library_dirs)

    set(dmcp_link_libraries)
    set(dmcp_expected_libraries)

    foreach(dmcp_library_dir IN LISTS dmcp_library_dirs)
        if(WIN32)
            set(dmcp_single_libraries
                "${dmcp_library_dir}/${CRISPY_DMCP_WINDOWS_IMPORT_LIBRARY}")
            set(dmcp_single_runtime
                "${dmcp_library_dir}/${CRISPY_DMCP_WINDOWS_RUNTIME_LIBRARY}")
        elseif(APPLE)
            set(dmcp_single_libraries
                "${dmcp_library_dir}/${CRISPY_DMCP_MACOS_RUNTIME_LIBRARY}")
        else()
            set(dmcp_single_libraries
                "${dmcp_library_dir}/${CRISPY_DMCP_LINUX_RUNTIME_LIBRARY}")
        endif()

        list(APPEND dmcp_expected_libraries
            ${dmcp_single_libraries}
        )

        foreach(dmcp_single_library IN LISTS dmcp_single_libraries)
            if(EXISTS "${dmcp_single_library}" AND (NOT WIN32 OR EXISTS "${dmcp_single_runtime}"))
                set(dmcp_link_libraries "${dmcp_single_library}")
                if(WIN32)
                    set(dmcp_runtime_library "${dmcp_single_runtime}")
                else()
                    set(dmcp_runtime_library "${dmcp_single_library}")
                endif()
                break()
            endif()
        endforeach()
        if(dmcp_link_libraries)
            break()
        endif()
    endforeach()

    if(NOT dmcp_link_libraries)
        string(REPLACE ";" ", " expected_libraries "${dmcp_expected_libraries}")
        message(FATAL_ERROR
            "single shared DMCP runtime library not found. Expected one of: ${expected_libraries}")
    endif()

    list(APPEND link_libraries ${dmcp_link_libraries})
    set_property(GLOBAL PROPERTY CRISPY_DMCP_RUNTIME_LIBRARY "${dmcp_runtime_library}")
    set(${out_var} "${link_libraries}" PARENT_SCOPE)
endfunction()

function(crispy_dmcp_bundle_runtime target)
    if(NOT DMCP_ENABLE)
        return()
    endif()

    get_property(dmcp_runtime_library GLOBAL PROPERTY CRISPY_DMCP_RUNTIME_LIBRARY)
    if(NOT dmcp_runtime_library)
        message(FATAL_ERROR "DMCP runtime library has not been resolved")
    endif()

    add_custom_command(TARGET ${target} POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${dmcp_runtime_library}"
            "$<TARGET_FILE_DIR:${target}>"
        COMMENT "Copying DMCP runtime next to $<TARGET_FILE_NAME:${target}>")
endfunction()
