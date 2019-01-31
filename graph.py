import numpy as np
import pylab as pl

# result_file = 'faster_dot015_result.txt'
result_file = 'faster_dot03_result.txt'

def draw_graph(data):
  #fat(10),fat(20),...,fat(100)
  x=[]
  for i in range(10):
    k=10*(i+1)
    x.append(k*k*5/4+k*k*k/4)
  #x=[2500, 18600, 58500, 136000, 262500]#fat(20), fat(40), ... , fat(100)
  #y=range(10)#us
  for i in range(2, 10):
    for key in data[10*(i+1)]:
      pl.plot(x[i],data[10*(i+1)][key], marker='v')  

  pl.xlabel("scale (number of nodes)", fontsize=12)
  pl.ylabel("running time(s)", fontsize=12)
  #pl.plot(x,y, marker='v')
  pl.grid(True)
  pl.show()

def draw_accu_graph(data):
  #fat(10),fat(20),...,fat(100)
  x=[]
  for i in range(10):
    k=10*(i+1)
    x.append(k*k*5/4+k*k*k/4)
  #x=[2500, 18600, 58500, 136000, 262500]#fat(20), fat(40), ... , fat(100)
  #y=range(10)#us
  for i in range(2, 10):
    for key in data[10*(i+1)]:
      #pl.plot(x[i],data[10*(i+1)][key]['avg_val'], marker='v')
      pl.plot(x[i],data[10*(i+1)][key]['max_val'], marker='v')

  pl.xlabel("scale (number of nodes)", fontsize=12)
  pl.ylabel("Accuracy", fontsize=12)
  #pl.plot(x,y, marker='v')
  pl.grid(True)
  pl.show()

time_dict = dict()
result_dict = dict()

with open(result_file, 'r') as f:
  while True:
    line = f.readline()
    if not line:
      break
    
    k, e = [int(x) for x in line.split()]
    line = f.readline()

    times = [float(x) for x in line.split()]

    line = f.readline()
    node_count = [int(x) for x in line.split()]
    accurate_ratio = 0.0
    if node_count[2] > 0:
      accurate_ratio = 1.0 * node_count[0] / node_count[2]

    if k not in time_dict:
      time_dict[k] = dict()

    if e not in time_dict[k]:
      time_dict[k][e] = list()

    if k not in result_dict:
      result_dict[k] = dict()

    if e not in result_dict[k]:
      result_dict[k][e] = list()

    time_dict[k][e].append(times)
    result_dict[k][e].append(accurate_ratio)

  f.close()

spld_time = dict()
for k in time_dict: 
  if k not in spld_time:
    spld_time[k] = dict()
  for e in time_dict[k]:
    spld_time[k][e] = sum([x[0] for x in time_dict[k][e]]) / len(time_dict[k][e])

draw_graph(spld_time)

detection_time = dict()
for k in time_dict: 
  if k not in detection_time:
    detection_time[k] = dict()
  for e in time_dict[k]:
    #
    # If you want to remove isomorphic graphs, use this if e > 0
    #
    if e > 0:
      detection_time[k][e] = sum([x[1] for x in time_dict[k][e]]) / len(time_dict[k][e])

draw_graph(detection_time)

accuracy = dict()
for k in result_dict:
  if k not in accuracy:
    accuracy[k] = dict()
  for e in result_dict[k]:
    accuracy[k][e] = dict()
    accuracy[k][e]['avg_val'] = sum(result_dict[k][e]) / len(result_dict[k][e])
    accuracy[k][e]['max_val'] = max(result_dict[k][e])

draw_accu_graph(accuracy)
