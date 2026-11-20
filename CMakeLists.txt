cmake_minimum_required(VERSION 3.21)
project(mica_sdk VERSION 2.0.0 DESCRIPTION "Client library for the Mica network" LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The version of the proto release this SDK was built from (updated by scripts/update-from-proto.sh)
set(MICA_SDK_PROTO_VERSION "v2.0.0-pre0" CACHE STRING "Proto release the SDK was built from")

option(MICA_SDK_BUILD_TESTS "Build the tests" ${PROJECT_IS_TOP_LEVEL})
option(MICA_SDK_BUILD_EXAMPLES "Build the examples" ${PROJECT_IS_TOP_LEVEL})

# The generated code is compiled against YOUR protobuf and gRPC: C++ generated code only builds against the
# protobuf version that produced it, so this SDK ships the protos and generates the code at build time.
find_package(Protobuf CONFIG REQUIRED)
find_package(gRPC CONFIG REQUIRED)

set(MICA_PROTO_DIR ${CMAKE_CURRENT_SOURCE_DIR}/protos)
set(MICA_GEN_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
file(MAKE_DIRECTORY ${MICA_GEN_DIR})

# mica_proto_library(<name> <proto dirs relative to protos/>...)
function(mica_proto_library name)
  set(protos "")
  foreach(dir IN LISTS ARGN)
    file(GLOB_RECURSE found CONFIGURE_DEPENDS ${MICA_PROTO_DIR}/${dir}/*.proto)
    list(APPEND protos ${found})
  endforeach()
  add_library(${name} ${protos})
  target_link_libraries(${name} PUBLIC protobuf::libprotobuf gRPC::grpc++)
  target_include_directories(${name} PUBLIC $<BUILD_INTERFACE:${MICA_GEN_DIR}>)
  protobuf_generate(TARGET ${name} LANGUAGE cpp IMPORT_DIRS ${MICA_PROTO_DIR} PROTOC_OUT_DIR ${MICA_GEN_DIR})
  protobuf_generate(TARGET ${name} LANGUAGE grpc IMPORT_DIRS ${MICA_PROTO_DIR} PROTOC_OUT_DIR ${MICA_GEN_DIR}
    GENERATE_EXTENSIONS .grpc.pb.h .grpc.pb.cc
    PLUGIN "protoc-gen-grpc=$<TARGET_FILE:gRPC::grpc_cpp_plugin>")
  set_target_properties(${name} PROPERTIES POSITION_INDEPENDENT_CODE ON)
endfunction()

# Shared by every role: the messages, the member services (Ping) and the validate annotations they import
mica_proto_library(mica_common validate micashared mica/common mica/member)
target_include_directories(mica_common PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
add_library(Mica::common ALIAS mica_common)

# One library per role, so a member builds only the roles it plays
mica_proto_library(mica_issuer mica/issuer)
target_link_libraries(mica_issuer PUBLIC mica_common)
add_library(Mica::issuer ALIAS mica_issuer)

mica_proto_library(mica_acceptor mica/acceptor)
target_link_libraries(mica_acceptor PUBLIC mica_common)
add_library(Mica::acceptor ALIAS mica_acceptor)

if(MICA_SDK_BUILD_EXAMPLES)
  add_executable(mica_ping examples/ping.cc)
  target_link_libraries(mica_ping PRIVATE Mica::common)
endif()

if(MICA_SDK_BUILD_TESTS)
  enable_testing()
  add_executable(mica_mtls_test tests/mtls_test.cc)
  target_link_libraries(mica_mtls_test PRIVATE Mica::common Mica::issuer Mica::acceptor)
  add_test(NAME make_certs COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/tests/make-certs.sh ${CMAKE_CURRENT_BINARY_DIR}/certs)
  set_tests_properties(make_certs PROPERTIES FIXTURES_SETUP certs)
  add_test(NAME mtls COMMAND mica_mtls_test ${CMAKE_CURRENT_BINARY_DIR}/certs)
  set_tests_properties(mtls PROPERTIES FIXTURES_REQUIRED certs)
endif()
