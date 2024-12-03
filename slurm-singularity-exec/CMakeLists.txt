cmake_minimum_required(VERSION 3.5 FATAL_ERROR)

project(slurm-singularity-exec LANGUAGES CXX)

include(GNUInstallDirs)

if (NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

option(INSTALL_PLUGSTACK_CONF "Whether to install a plugstack config" OFF)

set(SLURM_SYSCONFDIR /opt/slurm/etc CACHE STRING "Slurm sysconfdir")
set(SLURM_PLUGSTACK_CONF_D ${SLURM_SYSCONFDIR}/plugstack.conf.d
  CACHE STRING "Slurm plugstack conf dir")
set(PLUGIN_DEFAULT_ARG "" CACHE STRING "Plugin default= arg")
set(PLUGIN_BIND_ARG ${SLURM_SYSCONFDIR},/var/spool/slurmd,/var/run/munge
  CACHE STRING "Plugin bind= arg")
set(PLUGIN_EXTRA_ARGS "" CACHE STRING "Plugin args= arg")

#find_path(SLURM_INCLUDE_DIR
#  NAMES spank.h
#  PATH_SUFFIXES slurm
#  REQUIRED)

set (SLURM_INCLUDE_DIR /opt/slurm/include)

set(target ${PROJECT_NAME})
add_library(${target} SHARED main.cpp)
set_target_properties(${target} PROPERTIES PREFIX "")
target_compile_features(${target} PRIVATE cxx_std_17)
target_include_directories(${target} PRIVATE ${SLURM_INCLUDE_DIR})
target_link_libraries(${target} PRIVATE -static-libstdc++ -static-libgcc)
install(TARGETS ${target} LIBRARY DESTINATION ${CMAKE_INSTALL_LIBEXECDIR})

set(WRAPPER slurm-singularity-wrapper.sh)
install(FILES ${WRAPPER} DESTINATION ${CMAKE_INSTALL_LIBEXECDIR}
  PERMISSIONS
    OWNER_READ OWNER_WRITE OWNER_EXECUTE
    GROUP_READ GROUP_EXECUTE
    WORLD_READ WORLD_EXECUTE)

set(plugstackconf singularity-exec.conf)
configure_file(${plugstackconf}.in ${plugstackconf} @ONLY)

if (INSTALL_PLUGSTACK_CONF)
  install(FILES ${CMAKE_BINARY_DIR}/${plugstackconf} DESTINATION ${SLURM_PLUGSTACK_CONF_D})
endif()
