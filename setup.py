from setuptools import find_packages, setup

setup(
    name="devcontainer-python",
    version="0.1.0",
    description="A sample Python project",
    author="tomohiro.jin",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=[],
    python_requires=">=3.15,<3.16",
)
