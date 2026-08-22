#!/usr/bin/env bats

setup() {
    ROOT="${BATS_TEST_DIRNAME}/.."
}

@test "get-version.sh returns manifest version as valid semver" {
    version=$("$ROOT/scripts/get-version.sh")
    [ -n "$version" ]
    echo "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "Dockerfile contains no literal ENV VERSION (manifest is the source of truth)" {
    ! grep -q "ENV VERSION" "$ROOT/Dockerfile"
}

@test "Dockerfile copies every source dir referenced by wlanstart.sh" {
    grep -q "COPY lib/ /bin/lib/" "$ROOT/Dockerfile"
    for f in "$ROOT"/lib/*.sh; do
        [ -f "$f" ]
    done
}
