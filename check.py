#!/usr/bin/python

import sys
import networkx as nx

def check(blueprint, physical):
  g_blue = nx.Graph()
  g_phy = nx.Graph()

  with open(blueprint) as f:
    arr = [tuple([int(x) for x in line.split()]) for line in f]
    g_blue.add_edges_from(arr[:-1])
    f.close()

  with open(physical) as f:
    arr = [tuple([int(x) for x in line.split()]) for line in f]
    g_phy.add_edges_from(arr[:-1])
    f.close()
  
  return nx.is_isomorphic(g_blue, g_phy)

def faster_check(blueprint, physical):
  g_blue = nx.Graph()
  g_phy = nx.Graph()

  with open(blueprint) as f:
    arr = [tuple([int(x) for x in line.split()]) for line in f]
    g_blue.add_edges_from(arr[:-1])
    f.close()

  with open(physical) as f:
    arr = [tuple([int(x) for x in line.split()]) for line in f]
    g_phy.add_edges_from(arr[:-1])
    f.close()
  
  return nx.faster_could_be_isomorphic(g_blue, g_phy)

def main(argv=sys.argv):
  if argv is None or len(argv) < 4:
    print "Please use check.py <blueprint> <physical> <result> to run this program"
    return 1

  # flag = check(argv[1], argv[2])
  flag = faster_check(argv[1], argv[2])

  with open(argv[3], 'w') as f:
    if flag:
      f.write(str(1))
    else:
      f.write(str(0))
    f.close()

if __name__ == "__main__":
    sys.exit(main())