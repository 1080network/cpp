#!/bin/bash
# Update the protos the SDK is built from, to a release of https://github.com/1080network/proto.
#
# Usage: scripts/update-from-proto.sh <version> <path to a checkout of the proto repository>
#   <version>  release tag: vX.Y.Z or vX.Y.Z-preN
#
# Unlike the other SDKs, nothing is generated here: C++ generated code only compiles against the exact protobuf version
# that produced it, so this repository ships the protos and CMake generates the code against the client's own protobuf
# and gRPC at build time.
set -euo pipefail

VERSION=${1:?usage: $0 <version> <proto checkout>}
PROTO=${2:?usage: $0 <version> <proto checkout>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-pre[0-9]+)?$ ]]; then
    echo "version '$VERSION' must look like v1.2.3 or v1.2.3-pre0" >&2
    exit 1
fi
git -C "$PROTO" rev-parse --verify --quiet "refs/tags/$VERSION" >/dev/null || {
    echo "tag $VERSION not found in $PROTO (run: git -C $PROTO fetch --tags)" >&2
    exit 1
}

echo "Copying the $VERSION protos from $PROTO"
rm -rf "$ROOT/protos" && mkdir -p "$ROOT/protos"
# Exactly what the SDK compiles: the role APIs, the shared messages, and the validate annotations they import
git -C "$PROTO" archive "$VERSION" mica/issuer mica/acceptor mica/member mica/common micashared validate | tar -x -C "$ROOT/protos"
echo "$(git -C "$PROTO" rev-parse "$VERSION^{commit}")" > "$ROOT/protos/.proto_commit"

sed -i.bak -E "s/set\(MICA_SDK_PROTO_VERSION \"[^\"]*\"/set(MICA_SDK_PROTO_VERSION \"$VERSION\"/" "$ROOT/CMakeLists.txt" && rm "$ROOT/CMakeLists.txt.bak"

# Build and test against whatever protobuf and gRPC are installed
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT
cmake -S "$ROOT" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD" --parallel
ctest --test-dir "$BUILD" --output-on-failure
echo "Done ($VERSION)."
