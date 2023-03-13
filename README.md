# auhpc-tools

A collection of functions and metadata for hpc workloads, build environments, and automation.

Installation and Setup
----------------------

*The recommended install location is directly from the root of your home directory*

cd ~
git clone https://github.com/auburn-research-computing/.auhpc.git ${HOME}/.auhpc

*To begin automation of a specific runtime environment ... 

* If needed, modify the variables in tools/auhpc-runtime.cfg to reflect your target environment
* source ~/.auhpc/tools/auhpc-runtime.sh
* follow the prompts, ensureing that the output matches your target environment and that no errors are thrown


auhpc-runtime
-------------

Automate environment configuration for a specified build toolchain and software runtime.

Reference use case: R statistical computing language and platform

The R programming environment requires a number of steps for allowing customizable package installation and ensuring that internal compiler references the correct system toolchain libraries. For example, a typical procedure might involve:

1. Loading the correct system compiler and linker environment by loading module files or setting PATH environment variables.
2. Loading corresponding toolchain software versions to avoid errors or unexpected behavior and optimize performance
3. Modifying runtime configuration files and data paths to so that they reflect any environment-specific settings
4. Installing or loading runtime libraries for a specific workflow




