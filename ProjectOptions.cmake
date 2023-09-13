include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(Ctemplate_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(Ctemplate_setup_options)
  option(Ctemplate_ENABLE_HARDENING "Enable hardening" ON)
  option(Ctemplate_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    Ctemplate_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    Ctemplate_ENABLE_HARDENING
    OFF)

  Ctemplate_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR Ctemplate_PACKAGING_MAINTAINER_MODE)
    option(Ctemplate_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(Ctemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(Ctemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Ctemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(Ctemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Ctemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(Ctemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Ctemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Ctemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Ctemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(Ctemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(Ctemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Ctemplate_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(Ctemplate_ENABLE_IPO "Enable IPO/LTO" ON)
    option(Ctemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(Ctemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Ctemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(Ctemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Ctemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(Ctemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Ctemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Ctemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Ctemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(Ctemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(Ctemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Ctemplate_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      Ctemplate_ENABLE_IPO
      Ctemplate_WARNINGS_AS_ERRORS
      Ctemplate_ENABLE_USER_LINKER
      Ctemplate_ENABLE_SANITIZER_ADDRESS
      Ctemplate_ENABLE_SANITIZER_LEAK
      Ctemplate_ENABLE_SANITIZER_UNDEFINED
      Ctemplate_ENABLE_SANITIZER_THREAD
      Ctemplate_ENABLE_SANITIZER_MEMORY
      Ctemplate_ENABLE_UNITY_BUILD
      Ctemplate_ENABLE_CLANG_TIDY
      Ctemplate_ENABLE_CPPCHECK
      Ctemplate_ENABLE_COVERAGE
      Ctemplate_ENABLE_PCH
      Ctemplate_ENABLE_CACHE)
  endif()

  Ctemplate_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (Ctemplate_ENABLE_SANITIZER_ADDRESS OR Ctemplate_ENABLE_SANITIZER_THREAD OR Ctemplate_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(Ctemplate_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(Ctemplate_global_options)
  if(Ctemplate_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    Ctemplate_enable_ipo()
  endif()

  Ctemplate_supports_sanitizers()

  if(Ctemplate_ENABLE_HARDENING AND Ctemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Ctemplate_ENABLE_SANITIZER_UNDEFINED
       OR Ctemplate_ENABLE_SANITIZER_ADDRESS
       OR Ctemplate_ENABLE_SANITIZER_THREAD
       OR Ctemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${Ctemplate_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${Ctemplate_ENABLE_SANITIZER_UNDEFINED}")
    Ctemplate_enable_hardening(Ctemplate_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(Ctemplate_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(Ctemplate_warnings INTERFACE)
  add_library(Ctemplate_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  Ctemplate_set_project_warnings(
    Ctemplate_warnings
    ${Ctemplate_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(Ctemplate_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(Ctemplate_options)
  endif()

  include(cmake/Sanitizers.cmake)
  Ctemplate_enable_sanitizers(
    Ctemplate_options
    ${Ctemplate_ENABLE_SANITIZER_ADDRESS}
    ${Ctemplate_ENABLE_SANITIZER_LEAK}
    ${Ctemplate_ENABLE_SANITIZER_UNDEFINED}
    ${Ctemplate_ENABLE_SANITIZER_THREAD}
    ${Ctemplate_ENABLE_SANITIZER_MEMORY})

  set_target_properties(Ctemplate_options PROPERTIES UNITY_BUILD ${Ctemplate_ENABLE_UNITY_BUILD})

  if(Ctemplate_ENABLE_PCH)
    target_precompile_headers(
      Ctemplate_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(Ctemplate_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    Ctemplate_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(Ctemplate_ENABLE_CLANG_TIDY)
    Ctemplate_enable_clang_tidy(Ctemplate_options ${Ctemplate_WARNINGS_AS_ERRORS})
  endif()

  if(Ctemplate_ENABLE_CPPCHECK)
    Ctemplate_enable_cppcheck(${Ctemplate_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(Ctemplate_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    Ctemplate_enable_coverage(Ctemplate_options)
  endif()

  if(Ctemplate_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(Ctemplate_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(Ctemplate_ENABLE_HARDENING AND NOT Ctemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Ctemplate_ENABLE_SANITIZER_UNDEFINED
       OR Ctemplate_ENABLE_SANITIZER_ADDRESS
       OR Ctemplate_ENABLE_SANITIZER_THREAD
       OR Ctemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    Ctemplate_enable_hardening(Ctemplate_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
