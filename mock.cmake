set(CMOCK_ROOT_DIR ${CMAKE_CURRENT_LIST_DIR})

macro(generate_cmock)

    # Python 3.11
    # GoogleTest 1.11.0

    set(options "")
    set(oneValueArgs TARGET PROXY_DIR)
    set(multivalueArgs MOCKS_DIR TARGET_SOURCES TARGET_INCLUDES TARGET_DEFINES)

    cmake_parse_arguments(MY_CHOICE "${options}" "${oneValueArgs}" "${multivalueArgs}" ${ARGN})

    set(GENERATED_SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/${MY_CHOICE_PROXY_DIR})
    file(REMOVE_RECURSE ${GENERATED_SOURCE_DIR})
    file(MAKE_DIRECTORY ${GENERATED_SOURCE_DIR})

    foreach(dir ${MY_CHOICE_MOCKS_DIR})
        file(GLOB mocks "${dir}/*Mock.h")
        list(APPEND UNIT_TEST_MOCKS ${mocks})
    endforeach()

    #############################
    #     Generate mocks
    #############################
    execute_process(
        COMMAND python3 ${CMOCK_ROOT_DIR}/src/mock.py list --headers ${UNIT_TEST_MOCKS} --output ${GENERATED_SOURCE_DIR}
        OUTPUT_VARIABLE GENERATED_MOCKS
    )

    add_custom_command(
        COMMAND python3 ${CMOCK_ROOT_DIR}/src/mock.py generate --headers ${UNIT_TEST_MOCKS} --output ${GENERATED_SOURCE_DIR}
        OUTPUT ${GENERATED_MOCKS}
        DEPENDS ${UNIT_TEST_MOCKS}
        COMMENT "Generate mocks"
    )

    if(NOT GENERATED_MOCKS)
        message(FATAL_ERROR "No mocks were generate create dummy file")
        file(WRITE ${GENERATED_SOURCE_DIR}/dummy.cpp "")
        set(GENERATED_MOCKS ${GENERATED_SOURCE_DIR}/dummy.cpp)
    endif()

    #############################
    #     Compile mocks
    #############################
    add_library(${MY_CHOICE_TARGET}-mocks OBJECT EXCLUDE_FROM_ALL ${GENERATED_MOCKS})
    target_include_directories(${MY_CHOICE_TARGET}-mocks
        PUBLIC
        $<TARGET_PROPERTY:gmock,INCLUDE_DIRECTORIES>
        ${CMOCK_ROOT_DIR}/include
        ${MY_CHOICE_MOCKS_DIR}
        ${MY_CHOICE_TARGET_INCLUDES}
    )
    target_compile_definitions(${MY_CHOICE_TARGET}-mocks PUBLIC ${MY_CHOICE_TARGET_DEFINES})

    #############################
    #     Compile sources
    #############################
    add_library(${MY_CHOICE_TARGET}-rerouted OBJECT EXCLUDE_FROM_ALL ${MY_CHOICE_TARGET_SOURCES})
    target_include_directories(${MY_CHOICE_TARGET}-rerouted PUBLIC ${MY_CHOICE_TARGET_INCLUDES})
    target_compile_definitions(${MY_CHOICE_TARGET}-rerouted PUBLIC ${MY_CHOICE_TARGET_DEFINES})

    add_custom_target(${MY_CHOICE_TARGET}-reroute
        COMMAND python3 ${CMOCK_ROOT_DIR}/src/mock.py reroute --objects $<TARGET_OBJECTS:${MY_CHOICE_TARGET}-rerouted> --mocks $<TARGET_OBJECTS:${MY_CHOICE_TARGET}-mocks>
        DEPENDS ${MY_CHOICE_TARGET}-rerouted ${MY_CHOICE_TARGET}-mocks
        COMMAND_EXPAND_LISTS
        COMMENT "Reroute objects"
    )

    #############################
    #     Output library
    #############################
    add_library(${MY_CHOICE_TARGET} STATIC)

    target_link_libraries(${MY_CHOICE_TARGET}
        PUBLIC
        ${MY_CHOICE_TARGET}-mocks
        ${MY_CHOICE_TARGET}-rerouted
    )

    add_dependencies(${MY_CHOICE_TARGET} ${MY_CHOICE_TARGET}-reroute)

endmacro()
