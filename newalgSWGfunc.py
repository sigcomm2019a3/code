#TODO refer to alg20181019.pdf to write the algorithm
#1. remove servers (degree <= k/4) to get the switch graph
#2. hash each lines of the matrix, and the result of hash will be divided into two types,
#I. node with a unique hash value, II. nodes with same hash value
#3. group II (nodes with same hash value), if the node degree is k, then the group is core group; else if the node
#degree is k/2, then the group is edge group; else if the node degree < 3k/4, 'malfunction' edge group; else if the
#node degree > 3k/4, 'malfunction' core group
#4. if the group is not complete, then mark as 'incomplete' group, each 'complete' group includes k/2 nodes which
#have the same hash value. For core group, if there are k/2 'complete' core group, it means core switches are 'OK',
#(except those who wrongly connected to servers which we will handle as the last step). For edge group, if there are
#k 'complete' edge group, it means edge switches are 'OK'.
#5. for less than k/4 undirected link malfunction, we can prove that I. the number of core group and edge group are
#right, II, all the 'incomplete' groups (including edge and core groups) are less than k/4. Therefore, as I, based
#on the connection to the core groups (no matter it is complete or not), we can decide the index of aggregation
#switches and based on the connection to the edge groups (no matter it is complete or not), we can decide the
#group id of aggregation switches. So the role (group, index) of each aggregation switch is decided.
#6. remove the aggregation switches from the nodes which have unique hash value and the left is the malfunction ones,
#Then we need to decide the roles of those malfunction ones using majority rules.
#I. based on the degree of malfunction node to decide it is core (degree > 3k/4) or edge (degree < 3k/4)
#II. divided those malfunction nodes into suitable 'incomplete' groups
#the dividing method is similar for core and edge malfunction nodes:
#For each core malfunction node, computing the sum of XOR between the row of malfunction node and the row of any
#node in the 'incomplete' core group, the malunction core node belongs to the corresponding core group which has the
#maximum sum of XOR
#For each edge malfunction node, similar to core
#7. find fixation, we have known the roles of all the switches (switch-to-role mapping), thus based on upper
#roles and their connection rules, we can get the unique adjacency matrix A, the differences between A
#and the adjacency matrix A' of switch device graph are the fixations.
#if A[i,j]==1 and A'[i,j]==0, then add the link between switch i and switch j
#if A[i,j]==0 and A'[i,j]==1, then remove the link between switch i and switch j
#8. so far, we have known the minimum fixation for switches and for server malunctions, we can check
#the roles directly connected to the malfunciton server, except the role is edge, other roles means the
#corresponding connection is wrong, meanwhile, count the connected servers of each edge switch, if
#the number of connected servers are less than k/2, then mark this edge switch as 'incomplete' edge
#switch.

#9. output the switch-to-role mapping, minimum fixation, 'incomplete' edge switches and 'malunction'
#servers. (As for which 'incomplete' edge switches should connect to which 'malunction' servers, we
#need to know their location in order to make a decision, therefore, we do not consider it in this
#algorithm)
import time
import copy
import numpy as np
import sys
#TODO change this algorithm to decides whether the input device graph has less than k/4 malfunctions.
#Roles
CoreNodes={}#TODO node: role or group id : []
AggregateNodes={}#node:(group, index)
EdgeNodes={}#node:group
#Rules
#TODO consider ?
#TODO how about k? we just set it as a global variable or ?
def should_connect(r1,r2):
    if r1 in CoreNodes and r2 in CoreNodes:
        return False
    elif r1 in AggregateNodes and r2 in AggregateNodes:
        return False
    elif r1 in EdgeNodes and r2 in EdgeNodes:
        return False
    elif (r1 in CoreNodes and r2 in EdgeNodes) or (r1 in EdgeNodes and r2 in CoreNodes):
        return False
    elif (r1 in CoreNodes and r2 in AggregateNodes) and (CoreNodes[r1]==AggregateNodes[r2][1]):
        return True
    elif (r2 in CoreNodes and r1 in AggregateNodes) and (CoreNodes[r2]==AggregateNodes[r1][1]):
        return True
    elif (r1 in EdgeNodes and r2 in AggregateNodes) and (EdgeNodes[r1]==AggregateNodes[r2][0]):
        return True
    elif (r1 in AggregateNodes and r2 in EdgeNodes) and (AggregateNodes[r1][0]==EdgeNodes[r2]):
        return True
def get_switch_graph(devicegraph,k):#1, return switchgraph
#input device graph, then remove those nodes and its corresponding rows and columns
    n=len(devicegraph)
    switchgraph=copy.deepcopy(devicegraph)
    servers=[]
    for i in range(n):
        #compute the degree of each node, TODO either xor or sum(row)
        if sum(devicegraph[i])<=k/4:
            #mark as servers, TODO also remember to make the algorithm to be a decision algorithm,
            #which means when the malfuncitons are less than (<=) k/4
            #for j in range(n):#remove column
            #    del switchgraph[j][i-len(servers)]
            servers.append(i)
    servers.sort()
    nserver=len(servers)
    for i in range(nserver):
        for j in range(n):#remove column
            del switchgraph[j][servers[nserver-1-i]]#-len(servers)]
    for i in range(nserver):
        del switchgraph[servers[nserver-1-i]]
    #for i in range(len(servers)):
    #    del switchgraph[servers[i]-i]#remove row TODO but delete one line then the others are changed, too.
        #TODO think about the decision problem
    if len(servers)<>k*k*k/4:
        return "malunctions >= k/4, type 1"
    return switchgraph,servers

def SDBMHashold(key):#TODO this hash could hash the different rows with the same hash value
    hash = 0
    for i in range(len(key)):
      hash = ord(str(key[i])) + (hash << 6) + (hash << 16) - hash;
      #TODO test this ord(str(key[i]))
    return (hash & 0x7FFFFFFF)

def SDBMHash(key):#TODO this hash could hash the different rows with the same hash value
    hash = 0
    for i in range(len(key)):
      hash = ord(str(key[i]))*i + (hash << 6) + (hash << 16) - hash;
      #TODO test this ord(str(key[i]))
    return (hash & 0x7FFFFFFF)


def rowtonum(row):
    #TODO as data center scale is at most millions of devices, therefore, we can regard each row as a 32bit num
    #NO! we can not
    num=0
    for i in range(len(row)):
        num=num*2+int(row[i])
    if num>=pow(2,32):
        print row
        print num
        print "row is too long, lead to the num larger than 2^32"
    return num

def get_hash_value(switchgraph):#2, return node-to-hash dict
#TODO here need to be attention that
    #TODO here should not consider non same rows
    swhashmap={}
    swgrouphash={}
    coregroup={}
    edgegroup={}
    malcoregroup={}
    maledgegroup={}
    nsw=len(switchgraph)
    coregroupid=1
    edgegroupid=1
    CoreNodes={}
    EdgeNodes={}
    uniquehash=[]
    for i in range(nsw):
        #hashvalue=rowtonum(switchgraph[i])#
        hashvalue=SDBMHash(switchgraph[i])
        swhashmap[i]=hashvalue#TODO test this one, hash the row
        if hashvalue not in swgrouphash:
            swgrouphash[hashvalue]=[]
        swgrouphash[hashvalue].append(i)

    for i in range(nsw):
        hashvalue=swhashmap[i]
        degree=sum(switchgraph[i])
        if len(swgrouphash[hashvalue])==1:#either malfunction or agg
            uniquehash.append(i)
            continue
        if degree==k:#core group
            if hashvalue not in coregroup:
                coregroup[hashvalue]=[]#TODO? how about group id? the first one is group id?
                coregroup[hashvalue].append(coregroupid)
                coregroupid=coregroupid+1#TODO TODO here is wrong, agg's degree is also k,but it should not has the group id
            coregroup[hashvalue].append(i)
            if i not in CoreNodes:
                CoreNodes[i]=coregroup[hashvalue][0]
        elif degree==k/2:
            if hashvalue not in edgegroup:
                edgegroup[hashvalue]=[]
                edgegroup[hashvalue].append(edgegroupid)
                edgegroupid=edgegroupid+1
            edgegroup[hashvalue].append(i)
            if i not in EdgeNodes:
                EdgeNodes[i]=edgegroup[hashvalue][0]
        elif degree>3*k/4:
            if hashvalue not in malcoregroup:
                malcoregroup[hashvalue]=[]#TODO? how about group id? the first one is group id?
                malcoregroup[hashvalue].append(-1)#(coregroupid)
                #coregroupid=coregroupid+1
            malcoregroup[hashvalue].append(i)
            if i not in CoreNodes:
                CoreNodes[i]=-1
        elif degree<3*k/4:
            if hashvalue not in maledgegroup:
                maledgegroup[hashvalue]=[]
                maledgegroup[hashvalue].append(-1)#(edgegroupid)
                #edgegroupid=edgegroupid+1
            maledgegroup[hashvalue].append(i)
            if i not in EdgeNodes:
                EdgeNodes[i]=-1
        else:
            return "malunctions >= k/4, type 2"
    for hashvalue in coregroup:
        #if coregroup[hashvalue][0]<>-1:
        #    continue
        #else:
        #    return "bug"
        #TODO TODO we can not judge which one is agg or malcore just based on hash value
        if len(coregroup[hashvalue])<k/4:
            coregroup[hashvalue].append(-2)#TODO this should not use the id!!!
        elif len(coregroup[hashvalue])<k/2+1:
            coregroup[hashvalue].append(-1)#coregroup[hashvalue][-1]==-1 means it is 'incomplete' group
            if coregroup[hashvalue][0]==-1:
                coregroup[hashvalue][0]=coregroupid
                coregroupid=coregroupid+1
        elif len(coregroup[hashvalue])==k/2+1:
            coregroup[hashvalue].append(0)#means 'complete' core group
            if coregroup[hashvalue][0]==-1:#TODO this should not happen for less than k/4 malunctions
                coregroup[hashvalue][0]=coregroupid
                coregroupid=coregroupid+1
        else:
            return "malunctions >= k/4, type 3"
    for hashvalue in edgegroup:
        if len(edgegroup[hashvalue])<k/4:
            edgegroup[hashvalue].append(-2)
        elif len(edgegroup[hashvalue])<k/2+1:
            edgegroup[hashvalue].append(-1)
            if edgegroup[hashvalue][0]==-1:
                edgegroup[hashvalue][0]=edgegroupid
                edgegroupid=edgegroupid+1
        elif len(edgegroup[hashvalue])==k/2+1:
            edgegroup[hashvalue].append(0)
            if edgegroup[hashvalue][0]==-1:#TODO this should also not happen for less than k/4 malfuncitons
                edgegroup[hashvalue][0]=edgegroupid
                edgegroupid=edgegroupid+1
        else:
            return "malunctions >= k/4, type 4"
    return swhashmap,swgrouphash,coregroup,edgegroup,malcoregroup,maledgegroup,CoreNodes,EdgeNodes

#def group_hash(switchgraph,swgrouphash):#3,4, return core groups (3k/4 < node degree <= k, core-to-role) and edge groups
#(k/4 < node degree < 3k/4, edge-to-role) and mark as 'complete' or 'incomplete' group
    #TODO judge whether the group are complete TODO using the last one to mark? or use another dict?

def label_aggregation(switchgraph,swgrouphash,coregroup,edgegroup,malcoregroup,maledgegroup):#5, return AggregateNode-to-role
    if len(coregroup)+len(malcoregroup)<>k/2 or len(edgegroup)+len(maledgegroup)<>k:
        print len(coregroup),len(malcoregroup),len(edgegroup),len(maledgegroup)
        return "malunctions >= k/4, type 5"#TODO we can judge here as coregroup may include AggregateNode
    #AggregateNodes[r1][0] -> group id, AggregateNodes[r1][1] -> index id
    AggregateNodes={}
    #TODO attention that we should use the majority rule to decide the index and group of a aggregation node
    for hashvalue in swgrouphash:
        swnode=swgrouphash[hashvalue][0]#select one in each group
        degree=sum(switchgraph[swnode])
        id=-1
        indexornot=-1
        selectone=-1
        if len(swgrouphash[hashvalue])<=k/4:
            continue
        if degree==k:
            id=coregroup[hashvalue][0]#TODO here has bug, as
            indexornot=1#index id for AggregateNode
        elif degree==k/2:
            id=edgegroup[hashvalue][0]
            indexornot=0#group id for AggregateNode
        elif degree>3*k/4:
            id=malcoregroup[hashvalue][0]
            indexornot=1
        elif degree<3*k/4:
            print "strange degree<3*k/4 "
            print degree,swnode
            print switchgraph[swnode]
            id=maledgegroup[hashvalue][0]
            indexornot=0
        if id==-1:
            continue
        selectone=swnode#swgrouphash[hashvalue][0]
        for i in range(len(switchgraph)):#TODO here can use the adjacency list to reduce time
            if switchgraph[selectone][i]==1:#0 for no connection and 1 for connection
                if i not in AggregateNodes:
                    AggregateNodes[i]=[]#initialize the (group,index) of agg node
                    AggregateNodes[i].append(-1)
                    AggregateNodes[i].append(-1)
                if indexornot==0:
                    AggregateNodes[i][0]=id
                else:
                    AggregateNodes[i][1]=id
    if len(AggregateNodes)<>k*k/2:
        print "len(agg)",len(AggregateNodes)
        return "malunctions >= k/4, type 6"
    return AggregateNodes

#TODO TODO debug here, label_malfunctions() does not label the malfuncitons correctly
def label_malfunctions(switchgraph, coregroup, edgegroup, malcoregroup, maledgegroup, CoreNodes, EdgeNodes, swgrouphash, AggregateNodes):#6, return malfunctions-to-role
#TODO as we have decided the malfunction core and edge, then decide their roles
    #TODO only need to match the malfunction ones to the incomplete groups
    #TODO first, as for less than k/4 malfuncitons, the degree ok incomplete group must have
    #the group id, in other words including majority nodes,
#TODO the problem is that if there is no node in the malcoregroup or maledgegroup, we need to find them!!!
#as we can not judge whether a node with unique hash is agg or core or edge !, therefore, we need to first
#label the aggregations, then remove the aggregations from the unique hash nodes
#the rest are malfuncitons

    for hashvalue in swgrouphash:
        node=swgrouphash[hashvalue]
        if len(node)==1 and node[0] not in AggregateNodes:
            degree=sum(switchgraph[node[0]])
            if degree>3*k/4:
                if hashvalue not in malcoregroup:
                    malcoregroup[hashvalue]=[]#TODO? how about group id? the first one is group id?
                    malcoregroup[hashvalue].append(-1)#(coregroupid)
                    #coregroupid=coregroupid+1
                malcoregroup[hashvalue].append(node[0])
                if node[0] not in CoreNodes:
                    CoreNodes[node[0]]=-1
            if degree<3*k/4:
                if hashvalue not in maledgegroup:
                    maledgegroup[hashvalue]=[]
                    maledgegroup[hashvalue].append(-1)#(edgegroupid)
                    #edgegroupid=edgegroupid+1
                maledgegroup[hashvalue].append(node[0])
                if node[0] not in EdgeNodes:
                    EdgeNodes[node[0]]=-1

    for malhashvalue in malcoregroup:
        selmal=malcoregroup[malhashvalue][1]
        rowmal=copy.deepcopy(switchgraph[selmal])
        minsumxor=100000000
        malgroupid=-1
        for hashvalue in coregroup:#TODO here actually we can just find in those incomplete ones
            if coregroup[hashvalue][-1]==0:#complete group
                continue
            id=coregroup[hashvalue][0]
            if id==-1:
                return "malunctions >= k/4, type 7"
            sel=coregroup[hashvalue][1]
            rowsel=copy.deepcopy(switchgraph[sel])
            s=np.array(rowmal)
            t=np.array(rowsel)
            #compute the sum xor
            xorlist=np.bitwise_xor(s,t)
            if minsumxor>sum(xorlist):
                minsumxor=sum(xorlist)
                malgroupid=id
        malcoregroup[malhashvalue][0]=malgroupid
        for i in range(1,len(malcoregroup[malhashvalue])):
            core = malcoregroup[malhashvalue][i]
            if core not in CoreNodes or CoreNodes[core]==-1:
                CoreNodes[core]=malgroupid

    for malhashvalue in maledgegroup:
        selmal=maledgegroup[malhashvalue][1]
        rowmal=copy.deepcopy(switchgraph[selmal])
        minsumxor=100000000
        malgroupid=-1
        for hashvalue in edgegroup:#TODO here actually we can just find in those incomplete ones
            if edgegroup[hashvalue][-1]==0:#complete group
                continue
            id=edgegroup[hashvalue][0]
            if id==-1:
                return "malunctions >= k/4, type 8"
            sel=edgegroup[hashvalue][1]
            rowsel=copy.deepcopy(switchgraph[sel])
            s=np.array(rowmal)
            t=np.array(rowsel)
            xorlist=np.bitwise_xor(s,t)
            if minsumxor>sum(xorlist):
                minsumxor=sum(xorlist)
                malgroupid=id
        maledgegroup[malhashvalue][0]=malgroupid
        for i in range(1,len(maledgegroup[malhashvalue])):
            edge = maledgegroup[malhashvalue][i]
            if edge not in EdgeNodes or EdgeNodes[edge]==-1:
                EdgeNodes[edge]=malgroupid
    return malcoregroup, maledgegroup, CoreNodes, EdgeNodes

#TODO TODO 20181104 the problem should be here when constructing the role graph or label the aggregation
def find_switch_fixation(switchgraph, CoreNodes, AggregateNodes, EdgeNodes):#7, return switch-to-role mapping, minimum fixation
    #TODO first, construct the only adjacency matrix based on the switch-to-role mapping
    #using should_connect() function
    if len(CoreNodes)<>k*k/4 or len(EdgeNodes)<>k*k/2:
        print "CoreNodes or EdgeNodes incomplete"
        return "malunctions >= k/4, type 9"
    rolegraph=[]
    fixations={}
    for i in range(len(switchgraph)):
        rolegraph.append(i)
        rolegraph[i]=[]
        for j in range(len(switchgraph)):
            flag=should_connect(i,j)
            rolegraph[i].append(j)
            if flag==True:
                rolegraph[i][j]=1
            else:
                rolegraph[i][j]=0
            if rolegraph[i][j]<>switchgraph[i][j]:
                fixations[(i,j)]=switchgraph[i][j]
    #TODO compare role graph and switch graph
    return rolegraph, fixations
def find_server_fixation(devicegraph, CoreNodes, AggregateNodes, EdgeNodes, servers):#8, return 'incomplete' edge switches, 'malfunction' servers
    malservers=[]
    maledge=[]
    for s in servers:
        for i in range(len(devicegraph)):#TODO here use adj list to save time
            if devicegraph[s][i]==1 and i-k*k*k/4 not in EdgeNodes:
                malservers.append(s)
    for edge in EdgeNodes:
        connecttoservers=0
        for i in range(len(devicegraph)):
            if devicegraph[edge+k*k*k/4][i]==1 and i in servers:
                connecttoservers=connecttoservers+1
        if connecttoservers<>k/2:
            maledge.append(edge)
    return malservers,maledge

#TODO get k?
def read_collected_topo(filename,k):
    devicegraph=[]
    n=5*k*k/4+k*k*k/4
    for i in range(n):
        devicegraph.append(i)
        devicegraph[i]=[]
        for j in range(n):
            devicegraph[i].append(j)
            devicegraph[i][j]=0
    f=open(filename)
    edgelist=f.readlines()
    for str in edgelist:
        edge=str.split()
        s=int(edge[0])
        t=int(edge[1])
        devicegraph[s][t]=1
        devicegraph[t][s]=1
    return devicegraph

def read_julia_swtopo(filename,k):
    switchgraph=[]
    n=5*k*k/4
    for i in range(n):
        switchgraph.append(i)
        switchgraph[i]=[]
        for j in range(n):
            switchgraph[i].append(j)
            switchgraph[i][j]=0
    f=open(filename)
    edgelist=f.readlines()
    for str in edgelist:
        edge=str.split()
        s=int(edge[0])-1#start from 0
        t=int(edge[1])-1
        switchgraph[s][t]=1
        switchgraph[t][s]=1
    return switchgraph

# def run(k,e):
#     #roles, conn = generate(k, e)
#
#     filename="/home/run/Desktop/ipdps2019exp/ct"+str(k)+"-"+str(e)+".txt"
#     print filename
#     switchgraph=read_julia_swtopo(filename,k)
#
#     endgetswitch=time.time()
#
#     swhashmap,swgrouphash,coregroup,edgegroup,malcoregroup,maledgegroup,CoreNodes,EdgeNodes=get_hash_value(switchgraph)
#
#     AggregateNodes=label_aggregation(switchgraph,swgrouphash,coregroup,edgegroup,malcoregroup,maledgegroup)
#
#     malcoregroup, maledgegroup, CoreNodes, EdgeNodes=label_malfunctions(switchgraph, coregroup, edgegroup, malcoregroup, maledgegroup, CoreNodes, EdgeNodes, swgrouphash, AggregateNodes)#)
#
#     rolegraph, fixations=find_switch_fixation(switchgraph, CoreNodes, AggregateNodes, EdgeNodes)
#
#     endfindswitchfix=time.time()
#     print (endfindswitchfix-endgetswitch)
#     print fixations
#     #TODO check the result TODO read rtk-e.txt and compare it with our CoreNodes, AggregateNodes, EdgeNodes ?

#def gen_task():
if __name__=='__main__':
    # exp=[
    #     (10, 0), (20, 0), (30, 0), (40, 0), (50, 0), (60, 0), (70, 0), (80, 0), (90, 0),# (100, 0), # no error
    #     # (10, 5), (20, 5), (30, 5), (40, 5), (50, 5), (60, 5), (70, 5), (80, 5), (90, 5), (100, 5), # 5 errors
    #     (10, 2), (20, 4), (30, 7), (40, 9), (50, 12), (60, 14), (70, 17), (80, 19), (90, 22)#, (100, 24), # k/4
    #     # (10, 4), (20, 9), (30, 14), (40, 19), (50, 24), (60, 29), (70, 34), (80, 39), (90, 44), (100, 49), # k/2
    #     # (10, 5), (20, 10), (30, 15), (40, 20), (50, 25), (60, 30), (70, 35), (80, 40), (90, 45), (100, 50), # k/2 + 1
    #     # (60, 5), (60, 10), (60, 15), (60, 20), (60, 25), (60, 30), (60, 35), (60, 40), (60, 50), (60, 60), (60, 65)
    # ]
    # for i in range(5):
    #     for (k, e) in exp:
    #         print "tsp sh -c 'python2 newalgSWGfunc.py "+str(k)+" "+str(e)+" "+str(i+1)+" >>newalgresults.json'"
    global k#TODO test this
    #print str(sys.argv)
    k=int(sys.argv[1])
    e=int(sys.argv[2])
    num=int(sys.argv[3])
    #run(k,e)#test
    #filename="/home/run/Desktop/ipdps2019exp/ct4-0.txt"
    #k=4
    #filename="/home/run/Desktop/fattreemodify/ct"+str(k)+"-"+str(e)+"-"+str(num)+".txt"
    filename="/home/ylxdzsw/che/fattreemodify/ct"+str(k)+"-"+str(e)+"-"+str(num)+".txt"
    #print filename
    switchgraph=read_julia_swtopo(filename,k)

    endgetswitch=time.time()

    swhashmap,swgrouphash,coregroup,edgegroup,malcoregroup,maledgegroup,CoreNodes,EdgeNodes=get_hash_value(switchgraph)

    AggregateNodes=label_aggregation(switchgraph,swgrouphash,coregroup,edgegroup,malcoregroup,maledgegroup)

    malcoregroup, maledgegroup, CoreNodes, EdgeNodes=label_malfunctions(switchgraph, coregroup, edgegroup, malcoregroup, maledgegroup, CoreNodes, EdgeNodes, swgrouphash, AggregateNodes)#)

    rolegraph, fixations=find_switch_fixation(switchgraph, CoreNodes, AggregateNodes, EdgeNodes)

    endfindswitchfix=time.time()
    print num,k,e,(endfindswitchfix-endgetswitch)
    print fixations

    #run(k,e)
