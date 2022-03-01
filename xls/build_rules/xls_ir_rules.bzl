# Copyright 2021 The XLS Authors
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
"""This module contains IR-related build rules for XLS."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(
    "//xls/build_rules:xls_dslx_rules.bzl",
    "get_files_from_dslx_library_as_input",
    "xls_dslx_library_as_input_attrs",
)
load(
    "//xls/build_rules:xls_common_rules.bzl",
    "append_cmd_line_args_to",
    "append_default_to_args",
    "args_to_string",
    "get_output_filename_value",
    "is_args_valid",
)
load("//xls/build_rules:xls_config_rules.bzl", "CONFIG")
load(
    "//xls/build_rules:xls_providers.bzl",
    "ConvIRInfo",
    "DslxInfo",
    "DslxModuleInfo",
    "OptIRInfo",
)
load(
    "//xls/build_rules:xls_toolchains.bzl",
    "get_xls_toolchain_info",
    "xls_toolchain_attr",
)

_DEFAULT_IR_EVAL_TEST_ARGS = {
    "random_inputs": "100",
    "optimize_ir": "true",
}

_DEFAULT_BENCHMARK_IR_ARGS = {}

_IR_FILE_EXTENSION = ".ir"

_OPT_IR_FILE_EXTENSION = ".opt.ir"

def append_xls_dslx_ir_generated_files(args, basename):
    """Returns a dictionary of arguments appended with filenames generated by the 'xls_dslx_ir' rule.

    Args:
      args: A dictionary of arguments.
      basename: The file basename.

    Returns:
      Returns a dictionary of arguments appended with filenames generated by the 'xls_dslx_ir' rule.
    """
    args.setdefault("ir_file", basename + _IR_FILE_EXTENSION)
    return args

def get_xls_dslx_ir_generated_files(args):
    """Returns a list of filenames generated by the 'xls_dslx_ir' rule found in 'args'.

    Args:
      args: A dictionary of arguments.

    Returns:
      Returns a list of files generated by the 'xls_dslx_ir' rule found in 'args'.
    """
    return [args.get("ir_file")]

def append_xls_ir_opt_ir_generated_files(args, basename):
    """Returns a dictionary of arguments appended with filenames generated by the 'xls_ir_opt_ir' rule.

    Args:
      args: A dictionary of arguments.
      basename: The file basename.

    Returns:
      Returns a dictionary of arguments appended with filenames generated by the 'xls_ir_opt_ir' rule.
    """
    args.setdefault("opt_ir_file", basename + _OPT_IR_FILE_EXTENSION)
    return args

def get_xls_ir_opt_ir_generated_files(args):
    """Returns a list of filenames generated by the 'xls_ir_opt_ir' rule found in 'args'.

    Args:
      args: A dictionary of arguments.

    Returns:
      Returns a list of files generated by the 'xls_ir_opt_ir' rule found in 'args'.
    """
    return [args.get("opt_ir_file")]

def _convert_to_ir(ctx, src, dep_src_list):
    """Converts a DSLX source file to an IR file.

    Creates an action in the context to convert a DSLX source file to an
    IR file.

    Args:
      ctx: The current rule's context object.
      src: The source file.
      dep_src_list: A list of source file dependencies.
    Returns:
      A File referencing the IR file.
    """
    ir_converter_tool = get_xls_toolchain_info(ctx).ir_converter_tool
    IR_CONV_FLAGS = (
        "dslx_path",
        "emit_fail_as_assert",
    )

    ir_conv_args = dict(ctx.attr.ir_conv_args)
    ir_conv_args["dslx_path"] = (
        ir_conv_args.get("dslx_path", "") + ":${PWD}:" +
        ctx.genfiles_dir.path + ":" + ctx.bin_dir.path
    )

    is_args_valid(ir_conv_args, IR_CONV_FLAGS)

    # TODO(vmirian) 2022-02-19 When entry is a mandatory attr,
    # remove if statement.
    if ctx.attr.dslx_top:
        ir_conv_args["entry"] = ctx.attr.dslx_top
    my_args = args_to_string(ir_conv_args)

    required_files = [src] + dep_src_list
    required_files += get_xls_toolchain_info(ctx).dslx_std_lib_list

    ir_filename = get_output_filename_value(
        ctx,
        "ir_file",
        ctx.attr.name + _IR_FILE_EXTENSION,
    )
    ir_file = ctx.actions.declare_file(ir_filename)

    ctx.actions.run_shell(
        outputs = [ir_file],
        # The IR converter executable is a tool needed by the action.
        tools = [ir_converter_tool],
        # The files required for converting the DSLX source file.
        inputs = required_files + [ir_converter_tool],
        command = "{} {} {} > {}".format(
            ir_converter_tool.path,
            my_args,
            src.path,
            ir_file.path,
        ),
        mnemonic = "ConvertDSLX",
        progress_message = "Converting DSLX file: %s" % (src.path),
    )
    return ir_file

def _optimize_ir(ctx, src):
    """Optimizes an IR file.

    Creates an action in the context to optimize an IR file.

    Args:
      ctx: The current rule's context object.
      src: The source file.

    Returns:
      A File referencing the optimized IR file.
    """
    opt_ir_tool = get_xls_toolchain_info(ctx).opt_ir_tool
    opt_ir_args = dict(ctx.attr.opt_ir_args)
    IR_OPT_FLAGS = (
        # TODO(vmirian) 2022-02-19 When top is a mandatory attr, remove item
        # below.
        "entry",
        "ir_dump_path",
        "run_only_passes",
        "skip_passes",
        "opt_level",
        "convert_array_index_to_select",
    )

    is_args_valid(opt_ir_args, IR_OPT_FLAGS)

    if ctx.attr.top:
        opt_ir_args.setdefault("entry", ctx.attr.top)
    my_args = args_to_string(opt_ir_args)

    opt_ir_filename = get_output_filename_value(
        ctx,
        "opt_ir_file",
        ctx.attr.name + _OPT_IR_FILE_EXTENSION,
    )
    opt_ir_file = ctx.actions.declare_file(opt_ir_filename)
    ctx.actions.run_shell(
        outputs = [opt_ir_file],
        # The IR optimization executable is a tool needed by the action.
        tools = [opt_ir_tool],
        # The files required for optimizing the IR file.
        inputs = [src, opt_ir_tool],
        command = "{} {} {} > {}".format(
            opt_ir_tool.path,
            src.path,
            my_args,
            opt_ir_file.path,
        ),
        mnemonic = "OptimizeIR",
        progress_message = "Optimizing IR file: %s" % (src.path),
    )
    return opt_ir_file

def get_ir_equivalence_test_cmd(
        ctx,
        src_0,
        src_1,
        append_cmd_line_args = True):
    """
    Returns the runfiles and command that executes in the ir_equivalence_test rule.

    Args:
      ctx: The current rule's context object.
      src_0: A file for the test.
      src_1: A file for the test.
      append_cmd_line_args: Flag controlling appending the command-line
        arguments invoking the command generated by this function. When set to
        True, the command-line arguments invoking the command are appended.
        Otherwise, the command-line arguments are not appended.

    Returns:
      A tuple with two elements. The first element is a list of runfiles to
      execute the command. The second element is the command.
    """
    ir_equivalence_tool = get_xls_toolchain_info(ctx).ir_equivalence_tool
    IR_EQUIVALENCE_FLAGS = (
        # TODO(vmirian) 2022-02-19 When top is a mandatory attr, remove item
        # below.
        # Overrides global entry attribute.
        "function",
        "timeout",
    )

    ir_equivalence_args = dict(ctx.attr.ir_equivalence_args)
    is_args_valid(ir_equivalence_args, IR_EQUIVALENCE_FLAGS)
    if ctx.attr.top:
        ir_equivalence_args.setdefault("function", ctx.attr.top)
    my_args = args_to_string(ir_equivalence_args)

    cmd = "{} {} {} {}\n".format(
        ir_equivalence_tool.short_path,
        src_0.short_path,
        src_1.short_path,
        my_args,
    )

    # Append command-line arguments.
    if append_cmd_line_args:
        cmd = append_cmd_line_args_to(cmd)

    # The required runfiles are the source files and the IR equivalence tool
    # executable.
    runfiles = [src_0, src_1, ir_equivalence_tool]
    return runfiles, cmd

def get_eval_ir_test_cmd(ctx, src, append_cmd_line_args = True):
    """Returns the runfiles and command that executes in the xls_eval_ir_test rule.

    Args:
      ctx: The current rule's context object.
      src: The file to test.
      append_cmd_line_args: Flag controlling appending the command-line
        arguments invoking the command generated by this function. When set to
        True, the command-line arguments invoking the command are appended.
        Otherwise, the command-line arguments are not appended.

    Returns:
      A tuple with two elements. The first element is a list of runfiles to
      execute the command. The second element is the command.
    """
    ir_eval_tool = get_xls_toolchain_info(ctx).ir_eval_tool
    IR_EVAL_FLAGS = (
        # TODO(vmirian) 2022-02-19 When top is a mandatory attr, remove item
        # below.
        # Overrides global entry attribute.
        "entry",
        "input",
        "input_file",
        "random_inputs",
        "expected",
        "expected_file",
        "optimize_ir",
        "eval_after_each_pass",
        "use_llvm_jit",
        "test_llvm_jit",
        "llvm_opt_level",
        "test_only_inject_jit_result",
    )

    ir_eval_args = append_default_to_args(
        ctx.attr.ir_eval_args,
        _DEFAULT_IR_EVAL_TEST_ARGS,
    )

    runfiles = []

    is_args_valid(ir_eval_args, IR_EVAL_FLAGS)
    if ctx.attr.input_validator:
        validator_info = ctx.attr.input_validator[DslxInfo]
        src_files = validator_info.target_dslx_source_files
        if not src_files or len(src_files) != 1:
            fail(
                "The input validator library must have a single DSLX src file.",
            )
        dslx_source_file = src_files[0]
        ir_eval_args["input_validator_path"] = dslx_source_file.short_path
        runfiles.append(dslx_source_file)
        runfiles = runfiles + validator_info.dslx_source_files.to_list()
    elif ctx.attr.input_validator_expr:
        ir_eval_args["input_validator_expr"] = "\"" + ctx.attr.input_validator_expr + "\""
    if ctx.attr.top:
        ir_eval_args.setdefault("entry", ctx.attr.top)
    my_args = args_to_string(ir_eval_args)

    cmd = "{} {} {}".format(
        ir_eval_tool.short_path,
        src.short_path,
        my_args,
    )

    # Append command-line arguments.
    if append_cmd_line_args:
        cmd = append_cmd_line_args_to(cmd)

    # The required runfiles are the source file and the IR interpreter tool
    # executable.
    runfiles = runfiles + [src, ir_eval_tool]
    return runfiles, cmd

def get_benchmark_ir_cmd(ctx, src, append_cmd_line_args = True):
    """Returns the runfiles and command that executes in the xls_benchmark_ir rule.

    Args:
      ctx: The current rule's context object.
      src: The file to benchmark.
      append_cmd_line_args: Flag controlling appending the command-line
        arguments invoking the command generated by this function. When set to
        True, the command-line arguments invoking the command are appended.
        Otherwise, the command-line arguments are not appended.

    Returns:
      A tuple with two elements. The first element is a list of runfiles to
      execute the command. The second element is the command.
    """
    benchmark_ir_tool = get_xls_toolchain_info(ctx).benchmark_ir_tool
    BENCHMARK_IR_FLAGS = (
        "clock_period_ps",
        "pipeline_stages",
        "clock_margin_percent",
        "show_known_bits",
        # TODO(vmirian) 2022-02-19 When top is a mandatory attr, remove item
        # below.
        # Overrides global entry attribute.
        "entry",
        "delay_model",
        "convert_array_index_to_select",
    )

    benchmark_ir_args = append_default_to_args(
        ctx.attr.benchmark_ir_args,
        _DEFAULT_BENCHMARK_IR_ARGS,
    )

    is_args_valid(benchmark_ir_args, BENCHMARK_IR_FLAGS)
    if ctx.attr.top:
        benchmark_ir_args.setdefault("entry", ctx.attr.top)
    my_args = args_to_string(benchmark_ir_args)

    cmd = "{} {} {}".format(
        benchmark_ir_tool.short_path,
        src.short_path,
        my_args,
    )

    # Append command-line arguments.
    if append_cmd_line_args:
        cmd = append_cmd_line_args_to(cmd)

    # The required runfiles are the source files and the IR benchmark tool
    # executable.
    runfiles = [src, benchmark_ir_tool]
    return runfiles, cmd

def get_mangled_ir_symbol(module_name, function_name, parametric_values = None):
    """Returns the mangled IR symbol for the module/function combination.

    "Mangling" is the process of turning nicely namedspaced symbols into
    "grosser" (mangled) flat (non hierarchical) symbol, e.g. that lives on a
    package after IR conversion. To retrieve/execute functions that have been IR
    converted, we use their mangled names to refer to them in the IR namespace.

    Args:
      module_name: The DSLX module name that the function is within.
      function_name: The DSLX function name within the module.
      parametric_values: Any parametric values used for instantiation (e.g. for
        a parametric entry point that is known to be instantiated in the IR
        converted module). This is generally for more advanced use cases like
        internals testing.

    Returns:
      The "mangled" symbol string.
    """
    parametric_values_str = ""

    if parametric_values:
        parametric_values_str = "__" + "_".join(
            [
                str(v)
                for v in parametric_values
            ],
        )
    return "__" + module_name + "__" + function_name + parametric_values_str

xls_ir_top_attrs = {
    "top": attr.string(
        doc = "The (*mangled*) name of the entry point. See " +
              "get_mangled_ir_symbol.",
    ),
}

xls_ir_common_attrs = {
    "src": attr.label(
        doc = "The IR source file for the rule. A single source file must be " +
              "provided. The file must have a '.ir' extension.",
        mandatory = True,
        allow_single_file = [_IR_FILE_EXTENSION],
    ),
}

xls_dslx_ir_attrs = dicts.add(
    xls_dslx_library_as_input_attrs,
    {
        "dslx_top": attr.string(
            doc = "Defines the 'entry' argument of the" +
                  "//xls/dslx/ir_converter_main.cc application.",
            # TODO(vmirian) 2002-02-19 Update when entry is mandatory.
            #            mandatory = True,
        ),
        "ir_conv_args": attr.string_dict(
            doc = "Arguments of the IR conversion tool. For details on the " +
                  "arguments, refer to the ir_converter_main application at " +
                  "//xls/dslx/ir_converter_main.cc. Note the " +
                  "'entry' argument is not assigned using this attribute.",
        ),
        "ir_file": attr.output(
            doc = "Filename of the generated IR. If not specified, the " +
                  "target name of the bazel rule followed by an " +
                  _IR_FILE_EXTENSION + " extension is used.",
        ),
    },
)

def xls_dslx_ir_impl(ctx):
    """The implementation of the 'xls_dslx_ir' rule.

    Converts a DSLX source file to an IR file.

    Args:
      ctx: The current rule's context object.

    Returns:
      DslxModuleInfo provider
      ConvIRInfo provider
      DefaultInfo provider
    """
    src = None
    dep_src_list = []
    srcs = ctx.files.srcs
    deps = ctx.attr.deps

    srcs, dep_src_list = get_files_from_dslx_library_as_input(ctx)

    if srcs and len(srcs) != 1:
        fail("A single source file must be specified.")

    src = srcs[0]

    ir_file = _convert_to_ir(ctx, src, dep_src_list)

    dslx_module_info = DslxModuleInfo(
        dslx_source_files = dep_src_list,
        dslx_source_module_file = src,
    )
    return [
        dslx_module_info,
        ConvIRInfo(
            conv_ir_file = ir_file,
        ),
        DefaultInfo(files = depset([ir_file])),
    ]

xls_dslx_ir = rule(
    doc = """
        A build rule that converts a DSLX source file to an IR file.

Examples:

1. A simple IR conversion.

    ```
    # Assume a xls_dslx_library target bc_dslx is present.
    xls_dslx_ir(
        name = "d_ir",
        srcs = ["d.x"],
        deps = [":bc_dslx"],
    )
    ```

1. An IR conversion with an entry defined.

    ```
    # Assume a xls_dslx_library target bc_dslx is present.
    xls_dslx_ir(
        name = "d_ir",
        srcs = ["d.x"],
        deps = [":bc_dslx"],
        dslx_top = "d",
    )
    ```
    """,
    implementation = xls_dslx_ir_impl,
    attrs = dicts.add(
        xls_dslx_ir_attrs,
        CONFIG["xls_outs_attrs"],
        xls_toolchain_attr,
    ),
)

def xls_ir_opt_ir_impl(ctx, src):
    """The implementation of the 'xls_ir_opt_ir' rule.

    Optimizes an IR file.

    Args:
      ctx: The current rule's context object.
      src: The source file.

    Returns:
      OptIRInfo provider
      DefaultInfo provider
    """

    opt_ir_file = _optimize_ir(ctx, src)
    return [
        OptIRInfo(
            input_ir_file = src,
            opt_ir_file = opt_ir_file,
            opt_ir_args = ctx.attr.opt_ir_args,
        ),
        DefaultInfo(files = depset([opt_ir_file])),
    ]

xls_ir_opt_ir_attrs = dicts.add(
    xls_ir_top_attrs,
    {
        "opt_ir_args": attr.string_dict(
            doc = "Arguments of the IR optimizer tool. For details on the" +
                  "arguments, refer to the opt_main application at" +
                  "//xls/tools/opt_main.cc. The 'entry' " +
                  "argument is not assigned using this attribute.",
        ),
        "opt_ir_file": attr.output(
            doc = "Filename of the generated optimized IR. If not specified, " +
                  "the target name of the bazel rule followed by an " +
                  _OPT_IR_FILE_EXTENSION + " extension is used.",
        ),
    },
)

def _xls_ir_opt_ir_impl_wrapper(ctx):
    """The implementation of the 'xls_ir_opt_ir' rule.

    Wrapper for xls_ir_opt_ir_impl. See: xls_ir_opt_ir_impl.

    Args:
      ctx: The current rule's context object.
    Returns:
      See: xls_ir_opt_ir_impl.
    """
    return xls_ir_opt_ir_impl(ctx, ctx.file.src)

xls_ir_opt_ir = rule(
    doc = """A build rule that optimizes an IR file.

Examples:

1. Optimizing an IR file with an entry defined.

    ```
    xls_ir_opt_ir(
        name = "a_opt_ir",
        src = "a.ir",
        opt_ir_args = {
            "entry" : "a",
        },
    )
    ```

1. A target as the source.

    ```
    xls_dslx_ir(
        name = "a_ir",
        srcs = ["a.x"],
    )

    xls_ir_opt_ir(
        name = "a_opt_ir",
        src = ":a_ir",
    )
    ```
    """,
    implementation = _xls_ir_opt_ir_impl_wrapper,
    attrs = dicts.add(
        xls_ir_common_attrs,
        xls_ir_opt_ir_attrs,
        CONFIG["xls_outs_attrs"],
        xls_toolchain_attr,
    ),
)

def _xls_ir_equivalence_test_impl(ctx):
    """The implementation of the 'xls_ir_equivalence_test' rule.

    Executes the equivalence tool on two IR files.

    Args:
      ctx: The current rule's context object.

    Returns:
      DefaultInfo provider
    """
    ir_file_a = ctx.file.src_0
    ir_file_b = ctx.file.src_1

    runfiles, cmd = get_ir_equivalence_test_cmd(ctx, ir_file_a, ir_file_b)
    executable_file = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = executable_file,
        content = "\n".join([
            "#!/bin/bash",
            "set -e",
            cmd,
            "exit 0",
        ]),
        is_executable = True,
    )

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(files = runfiles),
            files = depset([executable_file]),
            executable = executable_file,
        ),
    ]

_two_ir_files_attrs = {
    "src_0": attr.label(
        doc = "An IR source file for the rule. A single source file must be " +
              "provided. The file must have a '.ir' extension.",
        mandatory = True,
        allow_single_file = [_IR_FILE_EXTENSION],
    ),
    "src_1": attr.label(
        doc = "An IR source file for the rule. A single source file must be " +
              "provided. The file must have a '.ir' extension.",
        mandatory = True,
        allow_single_file = [_IR_FILE_EXTENSION],
    ),
}

xls_ir_equivalence_test_attrs = {
    "ir_equivalence_args": attr.string_dict(
        doc = "Arguments of the IR equivalence tool. For details on the " +
              "arguments, refer to the check_ir_equivalence_main application " +
              "at //xls/tools/check_ir_equivalence_main.cc. " +
              "The 'function' argument is not assigned using this attribute.",
    ),
}

xls_ir_equivalence_test = rule(
    doc = """Executes the equivalence tool on two IR files.

Examples:

1. A file as the source.

    ```
    xls_ir_equivalence_test(
        name = "ab_ir_equivalence_test",
        src_0 = "a.ir",
        src_1 = "b.ir",
    )
    ```

1. A target as the source.

    ```
    xls_dslx_ir(
        name = "b_ir",
        srcs = ["b.x"],
    )

    xls_ir_equivalence_test(
        name = "ab_ir_equivalence_test",
        src_0 = "a.ir",
        src_1 = ":b_ir",
    )
    ```
    """,
    implementation = _xls_ir_equivalence_test_impl,
    attrs = dicts.add(
        _two_ir_files_attrs,
        xls_ir_equivalence_test_attrs,
        xls_ir_top_attrs,
        xls_toolchain_attr,
    ),
    test = True,
)

def _xls_eval_ir_test_impl(ctx):
    """The implementation of the 'xls_eval_ir_test' rule.

    Executes the IR Interpreter on an IR file.

    Args:
      ctx: The current rule's context object.
    Returns:
      DefaultInfo provider
    """
    if ctx.attr.input_validator and ctx.attr.input_validator_expr:
        fail(msg = "Only one of \"input_validator\" or \"input_validator_expr\" " +
                   "may be specified for a single \"xls_eval_ir_test\" rule.")
    src = ctx.file.src

    runfiles, cmd = get_eval_ir_test_cmd(ctx, src)
    executable_file = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = executable_file,
        content = "\n".join([
            "#!/bin/bash",
            "set -e",
            cmd,
            "exit 0",
        ]),
        is_executable = True,
    )

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(files = runfiles),
            files = depset([executable_file]),
            executable = executable_file,
        ),
    ]

xls_eval_ir_test_attrs = {
    "input_validator": attr.label(
        doc = "The DSLX library defining the input validator for this test. " +
              "Mutually exclusive with \"input_validator_expr\".",
        providers = [DslxInfo],
        allow_files = True,
    ),
    "input_validator_expr": attr.string(
        doc = "The expression to validate an input for the test function. " +
              "Mutually exclusive with \"input_validator\".",
    ),
    "ir_eval_args": attr.string_dict(
        doc = "Arguments of the IR interpreter. For details on the " +
              "arguments, refer to the eval_ir_main application at " +
              "//xls/tools/eval_ir_main.cc." +
              "The 'entry' argument is not assigned using this attribute.",
        default = _DEFAULT_IR_EVAL_TEST_ARGS,
    ),
}

xls_eval_ir_test = rule(
    doc = """Executes the IR interpreter on an IR file.

Examples:

1. A file as the source.

    ```
    xls_eval_ir_test(
        name = "a_eval_ir_test",
        src = "a.ir",
    )
    ```

1. An xls_ir_opt_ir target as the source.

    ```
    xls_ir_opt_ir(
        name = "a_opt_ir",
        src = "a.ir",
    )


    xls_eval_ir_test(
        name = "a_eval_ir_test",
        src = ":a_opt_ir",
    )
    ```
    """,
    implementation = _xls_eval_ir_test_impl,
    attrs = dicts.add(
        xls_ir_common_attrs,
        xls_eval_ir_test_attrs,
        xls_ir_top_attrs,
        xls_toolchain_attr,
    ),
    test = True,
)

def _xls_benchmark_ir_impl(ctx):
    """The implementation of the 'xls_benchmark_ir' rule.

    Executes the benchmark tool on an IR file.

    Args:
      ctx: The current rule's context object.
    Returns:
      DefaultInfo provider
    """
    src = ctx.file.src

    runfiles, cmd = get_benchmark_ir_cmd(ctx, src)
    executable_file = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = executable_file,
        content = "\n".join([
            "#!/bin/bash",
            "set -e",
            cmd,
            "exit 0",
        ]),
        is_executable = True,
    )

    return [
        DefaultInfo(
            runfiles = ctx.runfiles(files = runfiles),
            files = depset([executable_file]),
            executable = executable_file,
        ),
    ]

xls_benchmark_ir_attrs = {
    "benchmark_ir_args": attr.string_dict(
        doc = "Arguments of the benchmark IR tool. For details on the " +
              "arguments, refer to the benchmark_main application at " +
              "//xls/tools/benchmark_main.cc.",
    ),
}

xls_benchmark_ir = rule(
    doc = """Executes the benchmark tool on an IR file.

Examples:

1. A file as the source.

    ```
    xls_benchmark_ir(
        name = "a_benchmark",
        src = "a.ir",
    )
    ```

1. An xls_ir_opt_ir target as the source.

    ```
    xls_ir_opt_ir(
        name = "a_opt_ir",
        src = "a.ir",
    )


    xls_benchmark_ir(
        name = "a_benchmark",
        src = ":a_opt_ir",
    )
    ```
    """,
    implementation = _xls_benchmark_ir_impl,
    attrs = dicts.add(
        xls_ir_common_attrs,
        xls_benchmark_ir_attrs,
        xls_ir_top_attrs,
        xls_toolchain_attr,
    ),
    executable = True,
)
