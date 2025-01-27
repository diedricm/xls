# Copyright 2023 The XLS Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# pytype binary and test

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//xls:xls_internal"],
    features = [
        "layering_check",
        "parse_headers",
    ],
    licenses = ["notice"],  # Apache 2.0
)

cc_binary(
    name = "run_clang_tidy_cached",
    srcs = ["run_clang_tidy_cached.cc"],
    deps = [
        "@com_google_absl//absl/log:check",
        "@com_google_absl//absl/strings",
        "@com_google_absl//absl/strings:str_format",
        "@com_google_absl//absl/synchronization",
        "//xls/common:subprocess",
        "//xls/common:thread",
        "//xls/common/file:filesystem",
        "@com_googlesource_code_re2//:re2",
    ],
)

cc_library(
    name = "tool_timeout",
    srcs = ["tool_timeout.cc"],
    hdrs = ["tool_timeout.h"],
    deps = [
        "@com_google_absl//absl/flags:flag",
        "@com_google_absl//absl/time",
        "//xls/common:timeout_support",
    ],
)

cc_binary(
    name = "tool_timeout_test_main",
    testonly = True,
    srcs = ["tool_timeout_test_main.cc"],
    deps = [
        ":tool_timeout",
        "@com_google_absl//absl/flags:flag",
        "@com_google_absl//absl/log",
        "@com_google_absl//absl/status",
        "@com_google_absl//absl/time",
        "//xls/common:exit_status",
        "//xls/common:init_xls",
    ],
)

py_test(
    name = "tool_timeout_test",
    srcs = ["tool_timeout_test.py"],
    data = [":tool_timeout_test_main"],
    python_version = "PY3",
    srcs_version = "PY3",
    deps = [
        "@com_google_absl_py//absl/testing:absltest",
        "//xls/common:runfiles",
    ],
)

py_binary(
    name = "package_bazel_build",
    srcs = ["package_bazel_build.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    deps = [
        "@com_google_absl_py//absl:app",
        "@com_google_absl_py//absl/flags",
        "@com_google_absl_py//absl/logging",
    ],
)

sh_test(
    name = "package_bazel_build_test",
    srcs = ["package_bazel_build_test.sh"],
    data = glob(["package_bazel_build_testdata/**"]) + [
        ":package_bazel_build",
    ],
)

py_binary(
    name = "generate_vvp_runner",
    srcs = ["generate_vvp_runner.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    deps = [
        "@com_google_absl_py//absl:app",
    ],
)

cc_library(
    name = "extract_interface",
    srcs = ["extract_interface.cc"],
    hdrs = ["extract_interface.h"],
    deps = [
        "//xls/ir",
        "//xls/ir:channel",
        "//xls/ir:register",
        "//xls/ir:xls_ir_interface_cc_proto",
    ],
)

cc_binary(
    name = "extract_interface_main",
    srcs = ["extract_interface_main.cc"],
    deps = [
        ":extract_interface",
        "@com_google_absl//absl/flags:flag",
        "@com_google_absl//absl/log",
        "@com_google_absl//absl/status",
        "//xls/common:exit_status",
        "//xls/common:init_xls",
        "//xls/common/file:filesystem",
        "//xls/common/status:ret_check",
        "//xls/common/status:status_macros",
        "//xls/ir:xls_ir_interface_cc_proto",
        "//xls/public:ir_parser",
        "@com_google_protobuf//:protobuf",
    ],
)

cc_test(
    name = "extract_interface_test",
    srcs = ["extract_interface_test.cc"],
    deps = [
        ":extract_interface",
        "//xls/common:proto_test_utils",
        "//xls/common:xls_gunit_main",
        "//xls/common/status:matchers",
        "//xls/ir:bits",
        "//xls/ir:function_builder",
        "//xls/ir:ir_test_base",
        "//xls/ir:source_location",
        "@com_google_googletest//:gtest",
    ],
)

cc_binary(
    name = "extract_sample_points_from_ir_main",
    srcs = ["extract_sample_points_from_ir_main.cc"],
    deps = [
        "@com_google_absl//absl/algorithm:container",
        "@com_google_absl//absl/flags:flag",
        "@com_google_absl//absl/functional:any_invocable",
        "@com_google_absl//absl/log",
        "@com_google_absl//absl/status",
        "@com_google_absl//absl/status:statusor",
        "@com_google_absl//absl/strings",
        "@com_google_absl//absl/strings:str_format",
        "//xls/common:exit_status",
        "//xls/common:init_xls",
        "//xls/common/file:filesystem",
        "//xls/common/status:status_macros",
        "//xls/delay_model:delay_estimator",
        "//xls/delay_model:delay_estimators",
        "//xls/delay_model:delay_model_cc_proto",
        "//xls/delay_model:sample_point_extraction_utils",
        "//xls/ir:ir_parser",
        "@com_google_protobuf//:protobuf",
    ],
)

py_test(
    name = "extract_sample_points_from_ir_main_test",
    srcs = ["extract_sample_points_from_ir_main_test.py"],
    data = [":extract_sample_points_from_ir_main"],
    python_version = "PY3",
    srcs_version = "PY3",
    deps = [
        "@com_google_absl_py//absl/testing:absltest",
        "//xls/common:gfile",
        "//xls/common:runfiles",
        "//xls/common:test_base",
        "//xls/delay_model:delay_model_py_pb2",
        "@com_google_protobuf//:protobuf_python",
    ],
)

cc_library(
    name = "extract_segment",
    srcs = ["extract_segment.cc"],
    hdrs = ["extract_segment.h"],
    deps = [
        "@com_google_absl//absl/algorithm:container",
        "@com_google_absl//absl/container:flat_hash_map",
        "@com_google_absl//absl/status",
        "@com_google_absl//absl/status:statusor",
        "@com_google_absl//absl/strings:str_format",
        "@com_google_absl//absl/types:span",
        "//xls/common/status:ret_check",
        "//xls/common/status:status_macros",
        "//xls/ir",
        "//xls/ir:bits",
        "//xls/ir:function_builder",
        "//xls/ir:type",
        "//xls/passes:node_dependency_analysis",
    ],
)

cc_binary(
    name = "extract_segment_main",
    srcs = ["extract_segment_main.cc"],
    deps = [
        ":extract_segment",
        "@com_google_absl//absl/flags:flag",
        "@com_google_absl//absl/log",
        "@com_google_absl//absl/status",
        "@com_google_absl//absl/status:statusor",
        "@com_google_absl//absl/strings",
        "//xls/common:exit_status",
        "//xls/common:init_xls",
        "//xls/common/file:filesystem",
        "//xls/common/status:ret_check",
        "//xls/common/status:status_macros",
        "//xls/ir",
        "//xls/public:ir_parser",
    ],
)

py_test(
    name = "extract_segment_main_test",
    srcs = ["extract_segment_main_test.py"],
    data = [":extract_segment_main"],
    python_version = "PY3",
    srcs_version = "PY3",
    deps = [
        "@com_google_absl_py//absl/testing:absltest",
        "//xls/common:runfiles",
    ],
)

cc_test(
    name = "extract_segment_test",
    srcs = ["extract_segment_test.cc"],
    deps = [
        ":extract_segment",
        "//xls/common:xls_gunit_main",
        "//xls/common/status:matchers",
        "//xls/ir:bits",
        "//xls/ir:function_builder",
        "//xls/ir:ir_matcher",
        "//xls/ir:ir_test_base",
        "@com_google_googletest//:gtest",
    ],
)

cc_library(
    name = "remove_identifiers",
    srcs = ["remove_identifiers.cc"],
    hdrs = ["remove_identifiers.h"],
    deps = [
        "@com_google_absl//absl/container:flat_hash_map",
        "@com_google_absl//absl/status:statusor",
        "@com_google_absl//absl/strings:str_format",
        "//xls/common/status:status_macros",
        "//xls/ir",
        "//xls/ir:channel",
        "//xls/ir:op",
        "//xls/ir:register",
        "//xls/ir:source_location",
    ],
)

cc_test(
    name = "remove_identifiers_test",
    srcs = ["remove_identifiers_test.cc"],
    deps = [
        ":remove_identifiers",
        "@com_google_absl//absl/algorithm:container",
        "//xls/common:xls_gunit_main",
        "//xls/common/status:matchers",
        "//xls/ir",
        "//xls/ir:bits",
        "//xls/ir:function_builder",
        "//xls/ir:ir_test_base",
        "//xls/ir:register",
        "//xls/ir:source_location",
        "//xls/ir:value",
        "@com_google_googletest//:gtest",
    ],
)

cc_binary(
    name = "remove_identifiers_main",
    srcs = ["remove_identifiers_main.cc"],
    deps = [
        ":remove_identifiers",
        "@com_google_absl//absl/flags:flag",
        "@com_google_absl//absl/log",
        "@com_google_absl//absl/status",
        "@com_google_absl//absl/strings:str_format",
        "//xls/common:exit_status",
        "//xls/common:init_xls",
        "//xls/common/file:filesystem",
        "//xls/common/status:status_macros",
        "//xls/ir",
        "//xls/ir:ir_parser",
    ],
)

cc_binary(
    name = "ir_stats_main",
    srcs = ["ir_stats_main.cc"],
    deps = [
        "@com_google_absl//absl/flags:flag",
        "@com_google_absl//absl/log:check",
        "@com_google_absl//absl/status",
        "//xls/common:exit_status",
        "//xls/common:init_xls",
        "//xls/common/file:filesystem",
        "//xls/common/status:status_macros",
        "//xls/ir:ir_parser",
    ],
)

cc_binary(
    name = "extract_stage_main",
    srcs = ["extract_stage_main.cc"],
    deps = [
        "@com_google_absl//absl/flags:flag",
        "@com_google_absl//absl/log:check",
        "@com_google_absl//absl/status",
        "//xls/common:exit_status",
        "//xls/common:init_xls",
        "//xls/common/file:filesystem",
        "//xls/common/status:status_macros",
        "//xls/ir",
        "//xls/ir:ir_parser",
        "//xls/scheduling:extract_stage",
        "//xls/scheduling:pipeline_schedule",
        "//xls/scheduling:pipeline_schedule_cc_proto",
    ],
)

py_binary(
    name = "dump_llvm_artifacts",
    srcs = ["dump_llvm_artifacts_main.py"],
    data = [
        "//xls/jit:aot_compiler_main",
        "//xls/jit:aot_main_wrapper_main",
        "@llvm-project//clang",
        "@llvm-project//llvm:llvm-link",
    ],
    main = "dump_llvm_artifacts_main.py",
    visibility = ["//xls:xls_internal"],
    deps = [
        "@com_google_absl_py//absl:app",
        "@com_google_absl_py//absl/flags",
        "//xls/common:runfiles",
        "//xls/jit:aot_entrypoint_py_pb2",
    ],
)

py_test(
    name = "dump_llvm_artifacts_main_test",
    srcs = ["dump_llvm_artifacts_main_test.py"],
    data = [
        ":dump_llvm_artifacts",
        "@llvm-project//llvm:lli",
    ],
    deps = [
        "@com_google_absl_py//absl/testing:absltest",
        "//xls/common:runfiles",
    ],
)
