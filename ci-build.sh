#!/bin/bash

# AppVeyor and Drone Continuous Integration for MSYS2
# Author: Renato Silva <br.renatosilva@gmail.com>
# Author: Qian Hong <fracting@gmail.com>

# Configure
cd "$(dirname "$0")"
source 'ci-library.sh'
deploy_enabled && mkdir artifacts
git_config user.email 'ci@msys2.org'
git_config user.name  'MSYS2 Continuous Integration'
git remote add upstream 'https://github.com/Alexpux/MSYS2-packages'
git fetch --quiet upstream

# Detect
list_commits  || failure 'Could not detect added commits'
list_packages || failure 'Could not detect changed files'
message 'Processing changes' "${commits[@]}"
test -z "${packages}" && success 'No changes in package recipes'
define_build_order || failure 'Could not determine build order'

# Build
message 'Building packages' "${packages[@]}"
execute 'Upgrading the system' pacman --noconfirm --noprogressbar --sync --refresh --refresh --sysupgrade
for package in "${packages[@]}"; do
    execute 'Building binary' makepkg --noconfirm --noprogressbar --skippgpcheck --nocheck --syncdeps --rmdeps --cleanbuild
    execute 'Building source' makepkg --noconfirm --noprogressbar --skippgpcheck --allsource
    yes|execute 'Installing' pacman --noprogressbar --upgrade *.pkg.tar.xz
    deploy_enabled && mv "${package}"/*.pkg.tar.xz artifacts
    deploy_enabled && mv "${package}"/*.src.tar.gz artifacts
    unset package
done

# Deploy
deploy_enabled && cd artifacts || success 'All packages built successfully'
execute 'Generating pacman repository' create_pacman_repository "${PACMAN_REPOSITORY_NAME:-ci-build}"
execute 'Generating build references'  create_build_references  "${PACMAN_REPOSITORY_NAME:-ci-build}"
execute 'SHA-256 checksums' sha256sum *
success 'All artifacts built successfully'
