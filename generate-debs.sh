#!/bin/bash

set -e

ARCH="$1"

if [ -z "$ARCH" ]; then
	echo "Usage: $0 <architecture>"
	echo "Example: $0 aarch64"
	exit 1
fi

OUT_DIR="debs"
mkdir -p "$OUT_DIR"

for pkg in $(cat workdir/index); do
	if [ ! -f "workdir/$pkg/pkg-ver" ]; then
		echo "❌ Skipping $pkg: pkg-ver not found"
		continue
	fi

	PKG_VER_RAW=$(cat "workdir/$pkg/pkg-ver")
	PKG_VER=$(echo "$PKG_VER_RAW" | sed 's/^[^0-9]*//')  # elimină prefixul v sau altceva
	PKG_NAME="$pkg-$PKG_VER-$ARCH"
	PKG_DIR="$OUT_DIR/$PKG_NAME"

	echo "📦 Generating .deb for $pkg..."

	# Create DEBIAN/control folder
	mkdir -p "$PKG_DIR/DEBIAN"

	cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: $pkg
Version: $PKG_VER
Architecture: $ARCH
Maintainer: moio9@termux
Description: Compiled package for Termux
EOF

	SOURCE_DIR=$(find "workdir/$pkg/destdir-pkg" -type d -name usr | head -n 1)

	if [ -d "$SOURCE_DIR" ]; then
		mkdir -p "$PKG_DIR"
		cp -a "$(dirname "$SOURCE_DIR")/." "$PKG_DIR/"
	else
		echo "⚠️ Warning: No compiled files for $pkg"
	fi

	dpkg-deb --build "$PKG_DIR" "$OUT_DIR/${PKG_NAME}.deb"
	rm -rf "$PKG_DIR"
done

echo "✅ All .debs created in: $OUT_DIR/"

# Special libc++_shared package
generate_libcxx_shared() {
    PKG_NAME="libc++-shared"
    PKG_VER="1.0"
    PKG_DIR="$OUT_DIR/${PKG_NAME}-${PKG_VER}-${ARCH}"

    echo "📦 Generating .deb for $PKG_NAME..."

    mkdir -p "$PKG_DIR/DEBIAN"
    mkdir -p "$PKG_DIR/data/data/com.termux/files/usr/lib"

    # Convertim ARCH în triple target real
    case "$ARCH" in
        aarch64) TARGET_TRIPLE="aarch64-linux-android" ;;
        arm)     TARGET_TRIPLE="armv7a-linux-androideabi" ;;
        x86_64)  TARGET_TRIPLE="x86_64-linux-android" ;;
        i686)    TARGET_TRIPLE="i686-linux-android" ;;
        *) echo "Unsupported ARCH: $ARCH" && exit 1 ;;
    esac

    cp "cache/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$TARGET_TRIPLE/libc++_shared.so" \
        "$PKG_DIR/data/data/com.termux/files/usr/lib/"

    cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $PKG_VER
Architecture: $ARCH
Maintainer: moio9@termux
Description: Shared C++ standard library for Android/Termux
EOF

    dpkg-deb --build "$PKG_DIR" "$OUT_DIR/${PKG_NAME}-${PKG_VER}-${ARCH}.deb"
    rm -rf "$PKG_DIR"
}


generate_libcxx_shared "$ARCH"
