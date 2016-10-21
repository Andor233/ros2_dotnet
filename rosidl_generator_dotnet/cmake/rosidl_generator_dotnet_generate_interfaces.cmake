# Copyright 2016 Esteve Fernandez <esteve@apache.org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

find_package(ament_cmake_export_assemblies REQUIRED)
find_package(rosidl_generator_c REQUIRED)
find_package(rmw_implementation_cmake REQUIRED)
find_package(rmw REQUIRED)

find_package(dotnet_cmake_module REQUIRED)
find_package(DotNETExtra MODULE)

# Get a list of typesupport implementations from valid rmw implementations.
rosidl_generator_dotnet_get_typesupports(_typesupport_impls)

if("${_typesupport_impls} " STREQUAL " ")
  message(WARNING "No valid typesupport for .NET generator. .NET messages will not be generated.")
  return()
endif()

set(_output_path
  "${CMAKE_CURRENT_BINARY_DIR}/rosidl_generator_dotnet/${PROJECT_NAME}")
set(_generated_msg_cs_files "")
set(_generated_msg_c_files "")
#set(_generated_msg_c_common_files "")
set(_generated_msg_c_ts_files "")
set(_generated_msg_h_files "")
set(_generated_srv_files "")

foreach(_idl_file ${rosidl_generate_interfaces_IDL_FILES})
  get_filename_component(_parent_folder "${_idl_file}" DIRECTORY)
  get_filename_component(_parent_folder "${_parent_folder}" NAME)
  get_filename_component(_module_name "${_idl_file}" NAME_WE)
  string_camel_case_to_lower_case_underscore("${_module_name}" _header_name)

  if("${_parent_folder} " STREQUAL "msg ")
    list(APPEND _generated_msg_cs_files
      "${_output_path}/${_parent_folder}/${_module_name}.cs"
    )

    list(APPEND _generated_msg_h_files
      "${_output_path}/${_parent_folder}/rcldotnet_${_header_name}.h"
    )

    foreach(_typesupport_impl ${_typesupport_impls})
      list_append_unique(_generated_msg_c_ts_files
        "${_output_path}/${_parent_folder}/${_module_name}.ep.${_typesupport_impl}.c"
      )
      list(APPEND _type_support_by_generated_msg_c_files "${_typesupport_impl}")
    endforeach()
  elseif("${_parent_folder} " STREQUAL "srv ")
    list(APPEND _generated_srv_files
      "${_output_path}/${_parent_folder}/${_module_name}.cs"
    )
  else()
    message(FATAL_ERROR "Interface file with unknown parent folder: ${_idl_file}")
  endif()
endforeach()

set(_dependency_files "")
set(_dependencies "")
foreach(_pkg_name ${rosidl_generate_interfaces_DEPENDENCY_PACKAGE_NAMES})
  foreach(_idl_file ${${_pkg_name}_INTERFACE_FILES})
    set(_abs_idl_file "${${_pkg_name}_DIR}/../${_idl_file}")
    normalize_path(_abs_idl_file "${_abs_idl_file}")
    list(APPEND _dependency_files "${_abs_idl_file}")
    list(APPEND _dependencies "${_pkg_name}:${_abs_idl_file}")
  endforeach()
endforeach()

set(target_dependencies
  "${rosidl_generator_dotnet_BIN}"
  ${rosidl_generator_dotnet_GENERATOR_FILES}
  "${rosidl_generator_dotnet_TEMPLATE_DIR}/msg_support.entry_point.h.template"
  "${rosidl_generator_dotnet_TEMPLATE_DIR}/msg_support.entry_point.c.template"
  "${rosidl_generator_dotnet_TEMPLATE_DIR}/msg.cs.template"
  "${rosidl_generator_dotnet_TEMPLATE_DIR}/srv.cs.template"
  ${rosidl_generate_interfaces_IDL_FILES}
  ${_dependency_files})
foreach(dep ${target_dependencies})
  if(NOT EXISTS "${dep}")
    message(FATAL_ERROR "Target dependency '${dep}' does not exist")
  endif()
endforeach()

set(generator_arguments_file "${CMAKE_BINARY_DIR}/rosidl_generator_dotnet__arguments.json")
rosidl_write_generator_arguments(
  "${generator_arguments_file}"
  PACKAGE_NAME "${PROJECT_NAME}"
  ROS_INTERFACE_FILES "${rosidl_generate_interfaces_IDL_FILES}"
  ROS_INTERFACE_DEPENDENCIES "${_dependencies}"
  OUTPUT_DIR "${_output_path}"
  TEMPLATE_DIR "${rosidl_generator_dotnet_TEMPLATE_DIR}"
  TARGET_DEPENDENCIES ${target_dependencies}
)

file(MAKE_DIRECTORY "${_output_path}")

set(_generated_extension_files "")
set(_extension_dependencies "")
set(_target_suffix "__dotnet")

set_property(
  SOURCE
  ${_generated_msg_cs_files} ${_generated_msg_h_files} ${_generated_msg_c_ts_files} ${_generated_srv_files}
  PROPERTY GENERATED 1)

add_custom_command(
#  OUTPUT ${_generated_msg_c_common_files} ${_generated_msg_cs_files} ${_generated_msg_c_ts_files} ${_generated_msg_c_files} ${_generated_srv_files}
  OUTPUT ${_generated_msg_cs_files} ${_generated_msg_h_files} ${_generated_msg_c_ts_files} ${_generated_srv_files}
  COMMAND ${PYTHON_EXECUTABLE} ${rosidl_generator_dotnet_BIN}
  --generator-arguments-file "${generator_arguments_file}"
  --typesupport-impl "${_typesupport_impl}"
  --typesupport-impls "${_typesupport_impls}"
  DEPENDS ${target_dependencies}
  COMMENT "Generating C# code for ROS interfaces"
  VERBATIM
)

if(TARGET ${rosidl_generate_interfaces_TARGET}${_target_suffix})
  message(WARNING "Custom target ${rosidl_generate_interfaces_TARGET}${_target_suffix} already exists")
else()
  add_custom_target(
    ${rosidl_generate_interfaces_TARGET}${_target_suffix}
    DEPENDS
    ${_generated_msg_cs_files}
    ${_generated_msg_h_files}
    ${_generated_msg_c_ts_files}
    ${_generated_srv_files}
  )
endif()

foreach(_generated_msg_c_ts_file ${_generated_msg_c_ts_files})
  get_filename_component(_full_folder "${_generated_msg_c_ts_file}" DIRECTORY)
  get_filename_component(_package_folder "${_full_folder}" DIRECTORY)
  get_filename_component(_package_name "${_package_folder}" NAME)
  get_filename_component(_parent_folder "${_full_folder}" NAME)
  get_filename_component(_base_msg_name "${_generated_msg_c_ts_file}" NAME_WE)
  get_filename_component(_full_extension_msg_name "${_generated_msg_c_ts_file}" EXT)

  set(_msg_name "${_base_msg_name}${_full_extension_msg_name}")

  list(FIND _generated_msg_c_ts_files ${_generated_msg_c_ts_file} _file_index)
  list(GET _type_support_by_generated_msg_c_files ${_file_index} _typesupport_impl)
  find_package(${_typesupport_impl} REQUIRED)
  set(_generated_msg_c_common_file "${_full_folder}/${_base_msg_name}.c")

  set(_dotnetext_suffix "__dotnetext")
  set(_library_target "${_package_name}_${_base_msg_name}__${_typesupport_impl}")

  string_camel_case_to_lower_case_underscore("${_module_name}" _header_name)
  set(_generated_msg_h_file "${_full_folder}/rcldotnet_${_header_name}.h")

  add_library(${_library_target} SHARED
    "${_generated_msg_c_ts_file}"
    "${_generated_msg_h_files}"
  )

  set(_destination_dir "${_output_path}/${_parent_folder}")

  set_target_properties(${_library_target} PROPERTIES
    COMPILE_FLAGS "${_extension_compile_flags}"
    LIBRARY_OUTPUT_DIRECTORY "${_destination_dir}"
    RUNTIME_OUTPUT_DIRECTORY "${_destination_dir}"
  )

  set_target_properties(${_library_target} PROPERTIES
    COMPILE_FLAGS "${_extension_compile_flags}"
    LIBRARY_OUTPUT_DIRECTORY_DEBUG "${_destination_dir}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${_destination_dir}"
  )

  set_target_properties(${_library_target} PROPERTIES
    COMPILE_FLAGS "${_extension_compile_flags}"
    LIBRARY_OUTPUT_DIRECTORY_RELEASE "${_destination_dir}"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${_destination_dir}"
  )

  set_target_properties(${_library_target} PROPERTIES
    COMPILE_FLAGS "${_extension_compile_flags}"
    LIBRARY_OUTPUT_DIRECTORY_RELWITHDEBINFO "${_destination_dir}"
    RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${_destination_dir}"
  )

  set_target_properties(${_library_target} PROPERTIES
    COMPILE_FLAGS "${_extension_compile_flags}"
    LIBRARY_OUTPUT_DIRECTORY_MINSIZEREL "${_destination_dir}"
    RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL "${_destination_dir}"
  )

  add_dependencies(
    ${_library_target}
    ${rosidl_generate_interfaces_TARGET}__rosidl_generator_c
    ${rosidl_generate_interfaces_TARGET}${_target_suffix}
  )

  set(_extension_compile_flags "")
  if(NOT WIN32)
    set(_extension_compile_flags "-Wall -Wextra")
  endif()

  target_link_libraries(
    ${_library_target}
    ${PROJECT_NAME}__${_typesupport_impl}
  )

  target_include_directories(${_library_target}
    PUBLIC
    ${CMAKE_CURRENT_BINARY_DIR}/rosidl_generator_c
    ${CMAKE_CURRENT_BINARY_DIR}/rosidl_generator_dotnet
  )

  foreach(_pkg_name ${rosidl_generate_interfaces_DEPENDENCY_PACKAGE_NAMES})
    ament_target_dependencies(
      ${_library_target}
      ${_pkg_name}
    )
  endforeach()

  ament_target_dependencies(${_library_target}
    "rosidl_generator_c"
    "rosidl_generator_dotnet"
    "${_typesupport_impl}"
    "${PROJECT_NAME}__rosidl_generator_c"
  )

  list(APPEND _extension_dependencies ${_library_target})

  add_dependencies(${_library_target}
    ${rosidl_generate_interfaces_TARGET}__${_typesupport_impl}
  )

  if(NOT rosidl_generate_interfaces_SKIP_INSTALL)
    install(TARGETS ${_library_target}
      ARCHIVE DESTINATION lib
      LIBRARY DESTINATION lib
      RUNTIME DESTINATION bin
    )

#    ament_export_libraries(${_library_target})
  endif()

endforeach()

set(_assembly_deps_dll "")
set(_assembly_deps_nuget "")
set(ASSEMBLY_DEPENDENCIES "")

find_package(ros2_dotnet_utils REQUIRED)
foreach(_assembly_dep ${ros2_dotnet_utils_ASSEMBLIES_NUGET})
  list(APPEND _assembly_deps_nuget "${_assembly_dep}")
  get_filename_component(_assembly_filename ${_assembly_dep} NAME_WE)
  set(ASSEMBLY_DEPENDENCIES "${ASSEMBLY_DEPENDENCIES},\"${_assembly_filename}\": \"1.0.0\"")
endforeach()

foreach(_pkg_name ${rosidl_generate_interfaces_DEPENDENCY_PACKAGE_NAMES})
  find_package(${_pkg_name} REQUIRED)
  foreach(_assembly_dep ${${_pkg_name}_ASSEMBLIES_NUGET})
    list(APPEND _assembly_deps_nuget "${_assembly_dep}")
    get_filename_component(_assembly_filename ${_assembly_dep} NAME_WE)
  set(ASSEMBLY_DEPENDENCIES "${ASSEMBLY_DEPENDENCIES},\"${_assembly_filename}\": \"1.0.0\"")
  endforeach()
endforeach()

find_package(ros2_dotnet_utils REQUIRED)
foreach(_assembly_dep ${ros2_dotnet_utils_ASSEMBLIES_DLL})
  list(APPEND _assembly_deps_dll "${_assembly_dep}")
endforeach()

foreach(_pkg_name ${rosidl_generate_interfaces_DEPENDENCY_PACKAGE_NAMES})
  find_package(${_pkg_name} REQUIRED)
  foreach(_assembly_dep ${${_pkg_name}_ASSEMBLIES_DLL})
    list(APPEND _assembly_deps_dll "${_assembly_dep}")
  endforeach()
endforeach()

if(WIN32)
else()
configure_file(
"${rosidl_generator_dotnet_TEMPLATE_DIR}/project.json.dotnet.in"
"${CMAKE_CURRENT_BINARY_DIR}/project.json"
@ONLY
)
endif()

add_assemblies("${PROJECT_NAME}_assemblies"
  "${_generated_msg_cs_files}"
  OUTPUT_NAME
  "${PROJECT_NAME}"
  INCLUDE_ASSEMBLIES_DLL
  ${_assembly_deps_dll}
  INCLUDE_ASSEMBLIES_NUGET
  ${_assembly_deps_nuget}
)

add_dependencies("${PROJECT_NAME}_assemblies" "${rosidl_generate_interfaces_TARGET}${_target_suffix}")


#  OUTPUT_NAME
#  "${PROJECT_NAME}"
#  INCLUDE_ASSEMBLIES
#  "${_assembly_deps}"
#)

get_property(_assemblies_nuget_file TARGET "${PROJECT_NAME}_assemblies" PROPERTY "ASSEMBLIES_NUGET_FILE")
get_property(_assemblies_dll_file TARGET "${PROJECT_NAME}_assemblies" PROPERTY "ASSEMBLIES_DLL_FILE")

if(NOT rosidl_generate_interfaces_SKIP_INSTALL)
  if(NOT _generated_msg_h_files STREQUAL "")
    install(
      FILES ${_generated_msg_h_files}
      DESTINATION "include/${PROJECT_NAME}/msg"
    )
  endif()

  set(_install_assembly_dir "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}")
  if(NOT "${_generated_msg_cs_files} " STREQUAL " ")
    list(GET _generated_msg_cs_files 0 _msg_file)
    get_filename_component(_msg_package_dir "${_msg_file}" DIRECTORY)
    get_filename_component(_msg_package_dir "${_msg_package_dir}" DIRECTORY)

    install_assemblies("${PROJECT_NAME}_assemblies" "share/${PROJECT_NAME}/dotnet")
    ament_export_assemblies_dll("share/${PROJECT_NAME}/dotnet/${PROJECT_NAME}.dll")
    ament_export_assemblies_nuget("share/${PROJECT_NAME}/dotnet/${PROJECT_NAME}.1.0.0.nupkg")
  endif()
endif()
