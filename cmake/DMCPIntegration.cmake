set(CRISPY_DMCP_WINDOWS_IMPORT_LIBRARY "dmcp.lib")
set(CRISPY_DMCP_WINDOWS_RUNTIME_LIBRARY "dmcp.dll")
set(CRISPY_DMCP_LINUX_RUNTIME_LIBRARY "libdmcp.so")
set(CRISPY_DMCP_MACOS_RUNTIME_LIBRARY "libdmcp.dylib")
set(CRISPY_DMCP_RUNTIME_TARGET "crispy_dmcp_runtime")
set(CRISPY_DMCP_RUNTIME_BUILD_TARGET "crispy_dmcp_runtime_build")

function(crispy_dmcp_configure)
    if(NOT DMCP_ENABLE)
        return()
    endif()

    set(resolved_dmcp_root "${DMCP_ROOT}")
    if(NOT resolved_dmcp_root AND NOT "$ENV{dmcp_DIR}" STREQUAL "")
        set(resolved_dmcp_root "$ENV{dmcp_DIR}")
    endif()
    if(NOT resolved_dmcp_root AND DEFINED CRISPY_DMCP_ROOT)
        set(resolved_dmcp_root "${CRISPY_DMCP_ROOT}")
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
    if(NOT resolved_build_dir AND DEFINED CRISPY_DMCP_BUILD_DIR)
        set(resolved_build_dir "${CRISPY_DMCP_BUILD_DIR}")
    endif()
    if(NOT resolved_build_dir)
        set(resolved_build_dir "${resolved_dmcp_root}/build/default")
    endif()

    set(resolved_library_dir "${DMCP_LIBRARY_DIR}")
    if(NOT resolved_library_dir AND NOT "$ENV{DMCP_LIBRARY_DIR}" STREQUAL "")
        set(resolved_library_dir "$ENV{DMCP_LIBRARY_DIR}")
    endif()
    if(NOT resolved_library_dir)
        set(resolved_library_dir "${resolved_build_dir}")
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

    crispy_dmcp_expected_runtime(dmcp_link_library dmcp_runtime_library)
    crispy_dmcp_declare_runtime("${dmcp_link_library}" "${dmcp_runtime_library}")
    set_property(GLOBAL PROPERTY CRISPY_DMCP_RUNTIME_LIBRARY "${dmcp_runtime_library}")
endfunction()

function(crispy_dmcp_expected_runtime out_link_library out_runtime_library)
    if(WIN32)
        set(link_library "${DMCP_BUILD_DIR}/${CRISPY_DMCP_WINDOWS_IMPORT_LIBRARY}")
        set(runtime_library "${DMCP_BUILD_DIR}/${CRISPY_DMCP_WINDOWS_RUNTIME_LIBRARY}")
    elseif(APPLE)
        set(link_library "${DMCP_BUILD_DIR}/${CRISPY_DMCP_MACOS_RUNTIME_LIBRARY}")
        set(runtime_library "${link_library}")
    else()
        set(link_library "${DMCP_BUILD_DIR}/${CRISPY_DMCP_LINUX_RUNTIME_LIBRARY}")
        set(runtime_library "${link_library}")
    endif()

    set(${out_link_library} "${link_library}" PARENT_SCOPE)
    set(${out_runtime_library} "${runtime_library}" PARENT_SCOPE)
endfunction()

function(crispy_dmcp_declare_runtime link_library runtime_library)
    if(NOT DMCP_ENABLE)
        return()
    endif()
    if(TARGET ${CRISPY_DMCP_RUNTIME_TARGET})
        return()
    endif()

    include(ExternalProject)

    set(dmcp_build_type "${CMAKE_BUILD_TYPE}")
    if(NOT dmcp_build_type)
        set(dmcp_build_type "Release")
    endif()

    ExternalProject_Add(${CRISPY_DMCP_RUNTIME_BUILD_TARGET}
        SOURCE_DIR "${DMCP_ROOT}"
        BINARY_DIR "${DMCP_BUILD_DIR}"
        CMAKE_ARGS
            "-DDMCP_BUILD_SHARED=ON"
            "-DDMCP_BUILD_SINGLE_DLL=ON"
            "-DDMCP_BUILD_EXAMPLES=OFF"
            "-DDMCP_BUILD_ADAPTER_FAKE=OFF"
            "-DDMCP_BUILD_ADAPTER_ZDOOM=OFF"
            "-DDMCP_BUILD_ADAPTER_CRISPY=OFF"
            "-DCPM_SOURCE_CACHE=${DMCP_ROOT}/.cache"
            "-DCMAKE_BUILD_TYPE=${dmcp_build_type}"
            "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=${DMCP_BUILD_DIR}"
            "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=${DMCP_BUILD_DIR}"
            "-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY=${DMCP_BUILD_DIR}"
            "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG=${DMCP_BUILD_DIR}"
            "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG=${DMCP_BUILD_DIR}"
            "-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG=${DMCP_BUILD_DIR}"
            "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE=${DMCP_BUILD_DIR}"
            "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=${DMCP_BUILD_DIR}"
            "-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE=${DMCP_BUILD_DIR}"
            "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELWITHDEBINFO=${DMCP_BUILD_DIR}"
            "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO=${DMCP_BUILD_DIR}"
            "-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELWITHDEBINFO=${DMCP_BUILD_DIR}"
            "-DCMAKE_LIBRARY_OUTPUT_DIRECTORY_MINSIZEREL=${DMCP_BUILD_DIR}"
            "-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL=${DMCP_BUILD_DIR}"
            "-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_MINSIZEREL=${DMCP_BUILD_DIR}"
        BUILD_COMMAND "${CMAKE_COMMAND}" --build "${DMCP_BUILD_DIR}" --config "${dmcp_build_type}" --parallel
        INSTALL_COMMAND ""
        BUILD_BYPRODUCTS "${link_library}" "${runtime_library}"
    )

    if(WIN32)
        add_library(${CRISPY_DMCP_RUNTIME_TARGET} SHARED IMPORTED GLOBAL)
        set_target_properties(${CRISPY_DMCP_RUNTIME_TARGET} PROPERTIES
            IMPORTED_IMPLIB "${link_library}"
            IMPORTED_LOCATION "${runtime_library}")
    else()
        add_library(${CRISPY_DMCP_RUNTIME_TARGET} SHARED IMPORTED GLOBAL)
        set_target_properties(${CRISPY_DMCP_RUNTIME_TARGET} PROPERTIES
            IMPORTED_LOCATION "${link_library}")
    endif()

    add_dependencies(${CRISPY_DMCP_RUNTIME_TARGET} ${CRISPY_DMCP_RUNTIME_BUILD_TARGET})
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

    if(TARGET ${CRISPY_DMCP_RUNTIME_BUILD_TARGET})
        add_dependencies(${target} ${CRISPY_DMCP_RUNTIME_BUILD_TARGET})
    endif()
endfunction()

function(crispy_dmcp_link_libraries out_var)
    set(link_libraries "${${out_var}}")
    if(NOT DMCP_ENABLE)
        set(${out_var} "${link_libraries}" PARENT_SCOPE)
        return()
    endif()

    if(NOT TARGET ${CRISPY_DMCP_RUNTIME_TARGET})
        message(FATAL_ERROR "DMCP runtime target has not been declared")
    endif()

    list(APPEND link_libraries ${CRISPY_DMCP_RUNTIME_TARGET})
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

    if(TARGET ${CRISPY_DMCP_RUNTIME_BUILD_TARGET})
        add_dependencies(${target} ${CRISPY_DMCP_RUNTIME_BUILD_TARGET})
    endif()

    add_custom_command(TARGET ${target} POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${dmcp_runtime_library}"
            "$<TARGET_FILE_DIR:${target}>"
        COMMENT "Copying DMCP runtime next to $<TARGET_FILE_NAME:${target}>")
endfunction()
