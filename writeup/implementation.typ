= Implementation<implementation>

This chapter provides the technical details of the implementation of our process prediction technique with encompassing information on the data collection, preprocessing and on the architecture and training of the final model.

While the chapter will describe what we do and how we do it, it explicitly does not explain how to technically execute the code infrastructure. This information is available through a collection of _Markdown files_ that provide a walkthrough the project code, including the commands to execute in the command line. 

For our implementation we rely on several tools:

- `python`#footnote[#link("https://www.python.org") _last accessed: 11.06.2026_]: The programming language used for the code infrastructure and scripts.
- `uv`#footnote[#link("https://docs.astral.sh/uv/") _last accessed: 11.06.2026_]: A Python project and package manager handling the other listed dependencies and tools.
- `pytorch`#footnote[#link("https://docs.pytorch.org/docs/2.12/index.html") _last accessed: 11.06.2026_]: An optimized python library for deep learning. It supports training on CPUs and GPUs, including integrated GPUs such as ones used in Apple Silicon processors. We use it to build our models by using integrated base models or layers, and to perform the training.
- `numpy`#footnote[#link("https://numpy.org") _last accessed: 11.06.2026_]: An optimized python library for array programming, such as tensors. This is also implicitely used by `pytorch`, and we use it to interact with data to and from `pytorch`.
- `graphviz`#footnote[#link("https://graphviz.readthedocs.io/en/stable/") _last accessed: 11.06.2026_]: A library for a graph drawing software for python. We use it to visualize Heraklit runs.

The implementation was tested on both _macOS 15.7_ and _Ubuntu Linux 24.04_. The hardware used for training and evaluation consists of an _Apple MacBook Pro_ with an _M1 Pro_ chip and _32GB_ of memory.

== Data Collection and Preprocessing

- split is valid, as all exeuctions are independent of another
- want to extract all the steps required for the work piece

== Model Architecture 

-> embedder

== Training Details

training: Adam optimizer, regularization using dropout.

time to train