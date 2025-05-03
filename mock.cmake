set(CMOCK_ROOT_DIR ${CMAKE_CURRENT_LIST_DIR})

macro(generate_cmock)

    # Python 3.11
    # GoogleTest 1.11.0

    set(options "")
    set(oneValueArgs TARGET PROXY_DIR)
    set(multivalueArgs MOCKS_DIR)

    cmake_parse_arguments(MY_CHOICE "${options}" "${oneValueArgs}" "${multivalueArgs}" ${ARGN})

    set(GENERATED_SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/${MY_CHOICE_PROXY_DIR})
    file(REMOVE_RECURSE ${GENERATED_SOURCE_DIR})
    file(MAKE_DIRECTORY ${GENERATED_SOURCE_DIR})

    foreach(dir ${MY_CHOICE_MOCKS_DIR})
        file(GLOB mocks CONFIGURE_DEPENDS "${dir}/*Mock.h")
        list(APPEND UNIT_TEST_MOCKS ${mocks})
    endforeach()

    #############################
    #     Generate mocks
    #############################

    if (UNIT_TEST_MOCKS)
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
    endif()

    if(NOT GENERATED_MOCKS)
        message(STATUS "No mocks were generate create dummy file")
        file(WRITE ${GENERATED_SOURCE_DIR}/dummy.cpp "")
        set(GENERATED_MOCKS ${GENERATED_SOURCE_DIR}/dummy.cpp)
    endif()

    #############################
    #     Compile mocks
    #############################

    add_library(${MY_CHOICE_TARGET} OBJECT EXCLUDE_FROM_ALL ${GENERATED_MOCKS})
    target_include_directories(${MY_CHOICE_TARGET}
        PUBLIC
        $<TARGET_PROPERTY:gmock,INCLUDE_DIRECTORIES>
        ${CMOCK_ROOT_DIR}/include
        ${MY_CHOICE_MOCKS_DIR}
    )

endmacro()

macro(reroute_target)

    set(options "")
    set(oneValueArgs TARGET CMOCK_TARGET)
    set(multivalueArgs "")

    cmake_parse_arguments(MY_CHOICE "${options}" "${oneValueArgs}" "${multivalueArgs}" ${ARGN})

    #############################
    #     Compile rerouted target
    #############################
    add_library(${MY_CHOICE_TARGET}-rerouted STATIC EXCLUDE_FROM_ALL $<TARGET_OBJECTS:${MY_CHOICE_TARGET}>)
    target_include_directories(${MY_CHOICE_TARGET}-rerouted
        PUBLIC
        $<TARGET_PROPERTY:${MY_CHOICE_TARGET},INCLUDE_DIRECTORIES>
    )
    target_compile_definitions(${MY_CHOICE_TARGET}-rerouted
        PUBLIC
        $<TARGET_PROPERTY:${MY_CHOICE_TARGET},COMPILE_DEFINITIONS>
    )
    target_link_libraries(${MY_CHOICE_TARGET}-rerouted
        PRIVATE
        $<TARGET_PROPERTY:${MY_CHOICE_TARGET},LINK_LIBRARIES>
    )
    add_custom_command(
        TARGET ${MY_CHOICE_TARGET}-rerouted
        PRE_BUILD
        COMMAND python3 ${CMOCK_ROOT_DIR}/src/mock.py reroute --objects $<TARGET_OBJECTS:${MY_CHOICE_TARGET}> --mocks $<TARGET_OBJECTS:${MY_CHOICE_CMOCK_TARGET}>
        COMMAND_EXPAND_LISTS
        COMMENT "Reroute objects for ${MY_CHOICE_TARGET}"
    )

endmacro()
