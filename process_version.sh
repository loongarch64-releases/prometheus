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

build(){
    pushd "${build_root}"
        local promu_bin=~/go/bin/promu
        sed -i 's:prometheus/promu/releases/download/v:loongarch64-releases/promu/releases/download/:g' Makefile.common
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
