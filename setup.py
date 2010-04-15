from distutils.core import setup
from Cython.Distutils import build_ext
from Cython.Distutils.extension import Extension

version = "0.1"

core_ext = Extension(name="pyevent2.core",
                     sources=["pyevent2/core.pyx"],
                     extra_link_args=["-levent"],
                    )

setup(name="pyevent2",
      version=version,
      description="Bindings to libevent 2.x library.",
      keywords="network",
      author="Andrey Popp",
      author_email="8mayday@gmail.com",
      license="BSD",
      packages=["pyevent2"],
      ext_modules=[core_ext],
      cmdclass= {"build_ext": build_ext},
      )
