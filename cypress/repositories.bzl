"""Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies
"""

load("//cypress/private:maybe.bzl", http_archive = "maybe_http_archive")
load("//cypress/private:toolchains_repo.bzl", "PLATFORMS", "toolchains_repo")
load("//cypress/private:versions.bzl", "TOOL_VERSIONS")

# WARNING: any changes in this function may be BREAKING CHANGES for users
# because we'll fetch a dependency which may be different from one that
# they were previously fetching later in their WORKSPACE setup, and now
# ours took precedence. Such breakages are challenging for users, so any
# changes in this function should be marked as BREAKING in the commit message
# and released only in semver majors.
# This is all fixed by bzlmod, so we just tolerate it for now.
def rules_mylang_dependencies():
    # The minimal version of bazel_skylib we require
    http_archive(
        name = "bazel_skylib",
        sha256 = "f7be3474d42aae265405a592bb7da8e171919d74c16f082a5457840f06054728",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.2.1/bazel-skylib-1.2.1.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.2.1/bazel-skylib-1.2.1.tar.gz",
        ],
    )

########
# Remaining content of the file is only used to support toolchains.
########
_DOC = "Fetch external tools needed for cypress toolchain"
_ATTRS = {
    "mylang_version": attr.string(mandatory = True, values = TOOL_VERSIONS.keys()),
    "platform": attr.string(mandatory = True, values = PLATFORMS.keys()),
}

def _mylang_repo_impl(repository_ctx):
    url = "https://github.com/someorg/someproject/releases/download/v{0}/cypress-{1}.zip".format(
        repository_ctx.attr.mylang_version,
        repository_ctx.attr.platform,
    )
    repository_ctx.download_and_extract(
        url = url,
        integrity = TOOL_VERSIONS[repository_ctx.attr.mylang_version][repository_ctx.attr.platform],
    )
    build_content = """#Generated by cypress/repositories.bzl
load("@aspect_rules_cypress//cypress:toolchain.bzl", "mylang_toolchain")
mylang_toolchain(name = "mylang_toolchain", target_tool = select({
        "@bazel_tools//src/conditions:host_windows": "mylang_tool.exe",
        "//conditions:default": "mylang_tool",
    }),
)
"""

    # Base BUILD file for this repository
    repository_ctx.file("BUILD.bazel", build_content)

mylang_repositories = repository_rule(
    _mylang_repo_impl,
    doc = _DOC,
    attrs = _ATTRS,
)

# Wrapper macro around everything above, this is the primary API
def mylang_register_toolchains(name, **kwargs):
    """Convenience macro for users which does typical setup.

    - create a repository for each built-in platform like "mylang_linux_amd64" -
      this repository is lazily fetched when node is needed for that platform.
    - TODO: create a convenience repository for the host platform like "mylang_host"
    - create a repository exposing toolchains for each platform like "mylang_platforms"
    - register a toolchain pointing at each platform
    Users can avoid this macro and do these steps themselves, if they want more control.
    Args:
        name: base name for all created repos, like "mylang1_14"
        **kwargs: passed to each node_repositories call
    """
    for platform in PLATFORMS.keys():
        mylang_repositories(
            name = name + "_" + platform,
            platform = platform,
            **kwargs
        )
        native.register_toolchains("@%s_toolchains//:%s_toolchain" % (name, platform))

    toolchains_repo(
        name = name + "_toolchains",
        user_repository_name = name,
    )
