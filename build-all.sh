#!/bin/bash

showHelp() {
	echo "Usage: $0 aarch64 [OPTIONS]"
	echo ""
	echo "Options:"
	echo "  --help: Show this message and exit."
	echo "  --clean-workdir: Clean workdir (for a clean compiling)."
	echo "  --clean-cache: Clean cache of downloaded packages."
	echo "  --ci: Clean cache and build files after build of each package (for saving space on CI)"
	echo ""
}

if [ $# -lt 1 ]; then
	showHelp
	exit 0
fi

case $1 in "aarch64")
	export ARCHITECTURE=$1
	;;
	"--help")
	showHelp
	exit 0
	;;
	*)
	printf "Error: Unsupported Architecture \"$1\" Specified.\n\n"
	showHelp
	exit 1
esac

# Set environment
export INIT_DIR="$PWD"
export INIT_PATH="$PATH"
export APP_ROOT_DIR="/data/data/com.termux"
export PREFIX="$APP_ROOT_DIR/files/usr"

export PACKAGES="$(cat packages/index)"
export NDK_URL="https://dl.google.com/android/repository/android-ndk-r26b-linux.zip"
export NDK_FILENAME="${NDK_URL##*/}"
export MINGW_URL="http://techer.pascal.free.fr/Red-Rose_MinGW-w64-Toolchain/Red-Rose-MinGW-w64-Posix-Urct-v12.0.0.r458.g03d8a40f5-Gcc-11.5.0.tar.xz"
export MINGW_FILENAME="${MINGW_URL##*/}"

case $* in *"--clean-cache"*)
	rm -rf cache
esac

case $* in *"--clean-workdir"*)
	rm -rf workdir
esac

case $* in *"--ci"*)
	export CI=1
esac

# Prepare folders
rm -rf logs
mkdir -p {workdir,logs,cache,built-pkgs}

# Download NDK and mingw
setupBuildEnv() {
	if [ ! -d "$INIT_DIR/cache/android-ndk" ]; then
		echo "Downloading NDK..."
		curl --output "cache/$NDK_FILENAME" -#L "$NDK_URL"
		echo "Unpacking NDK..."
		7z x "cache/$NDK_FILENAME" -aoa -o"cache" &> /dev/null
		mv "cache/$(unzip -Z1 "cache/$NDK_FILENAME" | cut -d "/" -f 1 | head -n 1)" "cache/android-ndk"
		rm -f "cache/$NDK_FILENAME"
	fi

	if [ ! -d "$INIT_DIR/cache/mingw" ]; then
		echo "Downloading mingw..."
		curl --output "cache/$MINGW_FILENAME" -#L "$MINGW_URL"
		echo "Unpacking mingw..."
		tar -xf "cache/$MINGW_FILENAME" -C "cache"
		mv "cache/$(tar -tf "cache/$MINGW_FILENAME" | cut -d "/" -f 1 | head -n 1)/$(tar -tf "cache/$MINGW_FILENAME" | cut -d "/" -f 2 | head -n 1)" "cache/mingw"
		rm -f "cache/$MINGW_FILENAME"
	fi

	export PATH=$INIT_PATH:$INIT_DIR/cache/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin:$INIT_DIR/cache/mingw/bin
	export ANDROID_SDK="29"

	export CC=$ARCHITECTURE-linux-android$ANDROID_SDK-clang
	export CXX=$CC++
	export TOOLCHAIN_VERSION="$ARCHITECTURE-linux-android-4.9"
	export TOOLCHAIN_TRIPLE="$ARCHITECTURE-linux-android"

	export PKG_CONFIG_PATH="$PREFIX/share/pkgconfig:$PREFIX/lib/pkgconfig"
	export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
}

buildPackage() {
	local package=$1

	echo ""
	echo "==> Building $package..."

	mkdir -p "$INIT_DIR/workdir/$package/build_dir"
	mkdir -p "$INIT_DIR/workdir/$package/destdir"

	. "$INIT_DIR/packages/$package/build.sh"

	cd "$INIT_DIR/workdir/$package/build_dir"

	if [ -n "$SRC_URL" ]; then
		if [ ! -f "$INIT_DIR/cache/$package" ]; then
			curl -L -o "$INIT_DIR/cache/$package" "$SRC_URL"
		fi
		tar -xf "$INIT_DIR/cache/$package" -C ../
	
		# detect and rename
		EXTRACTED=$(tar -tf "$INIT_DIR/cache/$package" | head -n 1 | cut -d '/' -f1)
		mv ../"$EXTRACTED" ../"$package"
	fi

	SRC_DIR=$(find ../ -maxdepth 1 -type d -name "$package*" | head -n 1)
 
	if [ ! -d "$SRC_DIR" ]; then
		echo "Source folder not found $package"
		exit 1
	fi
	
	cd "$SRC_DIR"
	
	if [ -f "CMakeLists.txt" ]; then
		cmake -DCMAKE_INSTALL_PREFIX=$PREFIX . || exit 1
	elif [ -f "configure" ]; then
		./configure --prefix=$PREFIX $CONFIGURE_ARGS || exit 1
	else
		echo "No CMakeLists.txt, no configure script for $package"
		exit 1
	fi
	
	make -j$(nproc) || exit 1
	make DESTDIR="$INIT_DIR/workdir/$package/destdir" install || exit 1

	# Copy built files to output
	cp -a "$INIT_DIR/workdir/$package/destdir/"* "$PREFIX/"
}

buildAllPackages() {
	for package in $PACKAGES; do
		buildPackage $package
	done
}

# Create archive
archiveOutput() {
	echo ""
	echo "==> Archiving built packages"
	cd "$INIT_DIR/built-pkgs"
	tar -cf "$INIT_DIR/Termux-Packages.tar" .
}

# Prepare prefix
if [ ! -d "$PREFIX" ]; then
	sudo mkdir -p "$PREFIX"
	sudo chown -R $(whoami):$(whoami) "$APP_ROOT_DIR"
	sudo chmod 755 -R "$APP_ROOT_DIR"
fi

# Start
setupBuildEnv
buildAllPackages
archiveOutput

echo ""
echo "✅ All packages built and archived in Termux-Packages.tar"
