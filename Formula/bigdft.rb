class Bigdft < Formula
  desc "Electronic structure calculation based on Daubechies wavelets"
  homepage "http://bigdft.org"
  url "https://gitlab.com/l_sim/bigdft-suite/-/archive/1.9.6/bigdft-suite-1.9.6.tar.gz"
  sha256 "99f670d718ee5d3ea83832d76ff3dce38289fb3a9ee9a3284aa90492f019e44e"

  bottle do
    root_url "https://github.com/BigDFT-group/homebrew-bigdft/releases/download/v1.9.6"
    rebuild 3
    sha256 arm64_sequoia: "4b63af2d92ac9420dd49a94a133fb471a9aeac837d93a8c473798c28a34e7332"
  end

  depends_on "gcc"
  depends_on "open-mpi"
  depends_on "python@3"
  depends_on "libyaml"
  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "cmake" => :build
  depends_on "python-setuptools" => :build

  patch :DATA

  def install
    # Write the homebrew-static.rc configuration file
    (buildpath/"homebrew-static.rc").write <<~PYTHON
      modules = ['bigdft', ]
      skip = ["PyBigDFT", "pyfutile", "PyYAML", "libyaml"]

      def env_configuration():
          gcc, gpp = "clang", "clang++"
          env = {}
          env["FC"] = "mpifort"
          env["CC"] = gcc
          env["CXX"] = gpp
          env["CFLAGS"] = "-O2 -std=c99 -g -Wno-error=implicit-function-declaration"
          env["CXXFLAGS"] = "-O2 -g -std=c++11"
          env["FCFLAGS"] = "-O2 -g -fopenmp -mtune=native"
          env["--with-yaml-path"] = "#{HOMEBREW_PREFIX}"
          env["--with-ext-linalg"] = "-framework Accelerate"
          env["LIBS"] = "-lc++"

          args = " ".join([x + '=' + '"' + y + '"' for x, y in env.items()])
          args += " --enable-static --disable-shared"
          return args

      autogenargs = env_configuration()

      def ntpoly_configuration():
          from os import getcwd, path

          cmake_flags = {}
          cmake_flags["CMAKE_Fortran_FLAGS_RELEASE"] = "-O2 -fopenmp -mtune=native"
          cmake_flags["CMAKE_Fortran_COMPILER"] = "mpifort"
          cmake_flags["CMAKE_PREFIX_PATH"] = path.join(getcwd(), "install")
          cmake_flags["BUILD_SHARED_LIBS"] = "OFF"

          return " ".join(['-D' + x + '="' + y + '"' for x, y in cmake_flags.items()])

      module_cmakeargs.update({
          'ntpoly': ntpoly_configuration(),
      })
    PYTHON

    mkdir "build_homebrew" do
      system "python3", "#{buildpath}/Installer.py", "-y", "autogen"
      system "python3", "#{buildpath}/Installer.py", "build",
             "-f", "#{buildpath}/homebrew-static.rc", "-y"

      bin.install "install/bin/bigdft"
    end
  end

  test do
    system "#{bin}/bigdft", "--version"
  end
end
__END__
--- a/bundler/jhbuild/utils/misc.py
+++ b/bundler/jhbuild/utils/misc.py
@@ -36,7 +36,11 @@ def inpath(filename, path):
 def try_import_module(module_name):
     """Like importlib.import_module() but doesn't raise if the module doesn't exist"""

-    if pkgutil.get_loader(module_name) is None:
+    try:
+        import importlib.util
+        if importlib.util.find_spec(module_name) is None:
+            return
+    except (ImportError, ModuleNotFoundError, ValueError):
         return
     return importlib.import_module(module_name)
