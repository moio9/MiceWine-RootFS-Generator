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

	# Copy compiled files from built-pkgs
	SOURCE_DIR="workdir/$pkg/destdir-pkg/data/data/com.termux/files/usr"
 
	if [ -d "$SOURCE_DIR" ]; then
		mkdir -p "$PKG_DIR/data/data/com.termux/files/usr"
		cp -a "$SOURCE_DIR/." "$PKG_DIR/data/data/com.termux/files/usr/"
	else
		echo "⚠️ Warning: No compiled files for $pkg"
	fi

	# Build the .deb
	dpkg-deb --build "$PKG_DIR" "$OUT_DIR/${PKG_NAME}.deb"

	# Clean up intermediate dir
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

	cp "cache/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$ARCH-linux-android/libc++_shared.so" "$PKG_DIR/data/data/com.termux/files/usr/lib/"

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

generate_libcxx_shared
