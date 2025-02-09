PKG_VER=25.0.0-[JeezDisReez]
PKG_CATEGORY="VulkanDriver"
PKG_PRETTY_NAME="Mesa Android Wrapper"
VK_DRIVER_LIB="libvulkan_wrapper.so"

GIT_URL=https://gitlab.freedesktop.org/Pipetto-crypto/mesa
GIT_COMMIT=bae70519ffa58c8e455a003bc453b60250c3047b
LDFLAGS="-L$PREFIX/lib -landroid-shmem"
MESON_ARGS="-Dgallium-drivers= -Dvulkan-drivers=wrapper -Dglvnd=disabled -Dplatforms=x11 -Dxmlconfig=disabled -Dllvm=disabled -Dopengl=false -Degl=disabled -Dzstd=enabled"
