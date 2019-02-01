# code
Experiments for A3: An Automatic Topology-Aware Malfunction Detection and Fixation System in Data Center Networks

The following is the steps of running comparison experiment and the steps of running heuristic 1 can use julia xx.jl --help to get and the way to run heuristic 2 is python2 newalgSWGfunc.py 10 2 1, which means to read the ct10-2-1.txt file (the first random physical graph for FatTree(k=10) with 2 link malfunctions). For simplicity, the ctxxx file includes only switch connections. 
## Deployment Guide

### Malfunction Detection

#### C++ implementation
The main code lies in detect.cpp. You need to compile it with
```
g++ detect.cpp -o detect
```

To run this program, please make sure data/ct10-0-1.txt and data/ct10-2-1.txt exist and run
```
./detect ct10-0-1.txt ct10-2-1.txt
```

And it will output result into "detect_result" as defined in detect.cpp line 22.

#### checking isomorphic graph
It's implemented with Python networkx. You need to install it before running.
```
pip install networkx
```
In this program, you can use *is_isomorphic* or *faster_could_be_isomorphic* to check whether two graphs are isomorphic.

Please note that is_isomorphic time complexity might be exponentional.

To run this program, please check C++ implementation.

### Visualization

#### Parse result and compare with real malfunction result

accuracy.cpp will do the work. Make sure you configure it with correct parameters.

*result_file* is the output file of *./detect*
*faster_result* is this comparison result.

#### Draw figure with result

graph.py will do this work. Please note you need to install numpy and matplotlib.
```
pip install numpy
pip install matplotlib
```

For the input, you need to manually edit output file of accuracy.cpp. Make sure its content is like
```
k e
<spld running time> <detection running time>
<node count of correct detection> <node count of actual malfunction> <node count of max counter in detection algorithm>
```

For every test case, it should contain 3 lines. And then you can use 
```
python graph.py
```
to get the figures.


