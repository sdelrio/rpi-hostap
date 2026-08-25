#!/usr/bin/env bats

setup() {
    ROOT="${BATS_TEST_DIRNAME}/.."
}

@test "--version prints WLANSTART_VERSION when set" {
    version=$("$ROOT/wlanstart.sh" --version)
    [ -n "$version" ]
    echo "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "-V prints the same version as --version" {
    v_long=$("$ROOT/wlanstart.sh" --version)
    v_short=$("$ROOT/wlanstart.sh" -V)
    [ "$v_long" = "$v_short" ]
}

@test "--version matches scripts/get-version.sh output" {
    v_flag=$("$ROOT/wlanstart.sh" --version)
    v_script=$("$ROOT/scripts/get-version.sh")
    [ "$v_flag" = "$v_script" ]
}

@test "Dockerfile declares VERSION build arg and WLANSTART_VERSION env" {
    grep -q 'ARG VERSION=dev' "$ROOT/Dockerfile"
    grep -q 'ENV WLANSTART_VERSION=${VERSION}' "$ROOT/Dockerfile"
}

@test "publish workflow passes VERSION build-arg to docker build" {
    grep -q 'build-args:' "$ROOT/.github/workflows/publish.yml"
    grep -q 'VERSION=${{ steps.version.outputs.VERSION }}' "$ROOT/.github/workflows/publish.yml"
}
