#!/bin/bash
set -exuo pipefail

readonly version="$1"

readonly org='prometheus'
readonly proj='prometheus'
readonly arch='loongarch64'
readonly goarch='loong64'
readonly proj_name="${proj}-${version}"

# 映射目录
readonly workspace="/workspace"
readonly dists="${workspace}/dists"
readonly patches="${workspace}/patches"

readonly build="/build"
readonly source_root="${build}/${proj_name}"
readonly build_root="${build}/${proj_name}"
readonly package_root="${dists}/${proj_name}"

mkdir -p "${build}"


# apply_patches()
# {
#     for patch_ in ${patches}/*.patch;
#     do
#         git apply ${patch_}
#     done
# }

fetch_source_code()
{
    rm -rf "${source_root}"
    git clone --branch "v${version}" --depth=1 "https://github.com/${org}/${proj}" "${source_root}"
}

# 上游 rolldown / lightningcss 未发布 loong64 平台包，用 loongarch64-releases 的原生库补齐。
# 两个库都是 napi-rs cdylib，上游加载器只按 <name>.node 查找，因此必须改名后放到对应路径：
#   <rolldown>/dist/shared/rolldown-binding.linux-loong64-gnu.node
#   <lightningcss>/lightningcss.linux-loong64-gnu.node
# 调用前必须已 pnpm install（node_modules 就位），版本取自 lockfile，保证与 JS 侧 ABI 一致。
install_native_bindings(){
    local tmp=$(mktemp -d)
    local rolldown_version=$(grep -m1 -oE 'rolldown@[0-9]+\.[0-9]+\.[0-9]+' web/ui/pnpm-lock.yaml | cut -d@ -f2)
    local lightningcss_version=$(grep -m1 -oE 'lightningcss@[0-9]+\.[0-9]+\.[0-9]+' web/ui/pnpm-lock.yaml | cut -d@ -f2)

    curl -fsSL -o "${tmp}/librolldown_binding.so" \
        "https://github.com/loongarch64-releases/rolldown/releases/download/v${rolldown_version}/librolldown_binding.so"
    install -m 0755 "${tmp}/librolldown_binding.so" \
        "web/ui/node_modules/.pnpm/rolldown@${rolldown_version}/node_modules/rolldown/dist/shared/rolldown-binding.linux-loong64-gnu.node"

    curl -fsSL -o "${tmp}/liblightningcss_node_gnu.so" \
        "https://github.com/loongarch64-releases/lightningcss/releases/download/v${lightningcss_version}/liblightningcss_node_gnu.so"
    install -m 0755 "${tmp}/liblightningcss_node_gnu.so" \
        "web/ui/node_modules/.pnpm/lightningcss@${lightningcss_version}/node_modules/lightningcss/lightningcss.linux-loong64-gnu.node"
}

build(){
    pushd "${build_root}"
        local promu_bin=~/go/bin/promu
        sed -i 's:prometheus/promu/releases/download/v:loongarch64-releases/promu/releases/download/:g' Makefile.common
        # 前端原生库必须在 ui-install 之后、ui-build 之前注入：make build 的 assets 链
        # 是 ui-install → ui-build，中间没有 hook 点，故先单独跑 ui-install。
        make ui-install
        install_native_bindings
        make build PROMU_VERSION=0.18.1 && $promu_bin tarball
    popd
}

package(){
    rm -rf "${package_root}"
    mkdir -p "${package_root}"
    pushd "${package_root}"
        cp ${build_root}/*.tar.gz ./
    popd

}

main()
{
    fetch_source_code
    build
    package
}

main "$@"
