using Random
using Dates
using SparseArrays
using OhMyJulia

abstract type Role end

struct CoreNode <: Role
    group::Int
end

struct AggregateNode <: Role
    group::Int
    index::Int
end

struct EdgeNode <: Role
    group::Int
end

should_connect(r1::Role, r2::Role) = false
should_connect(r1::CoreNode, r2::AggregateNode) = r1.group == r2.index
should_connect(r1::AggregateNode, r2::CoreNode) = should_connect(r2, r1)
should_connect(r1::EdgeNode, r2::AggregateNode) = r1.group == r2.group
should_connect(r1::AggregateNode, r2::EdgeNode) = should_connect(r2, r1)

function gen_table_from_roles(roles::Vector{Role})
    n = length(roles)
    I, J = Int[], Int[]

    for (i, ir) in enumerate(roles), (j, jr) in enumerate(view(roles, 1:i-1)) @when should_connect(ir, jr)
        push!(I, i)
        push!(J, j)
    end

    sparse(I, J, map(x->true, I), n, n)
end

random_assign_roles(k::Int) = shuffle!([
    repeat([EdgeNode(i) for i in 1:k], k ÷ 2);
    [AggregateNode(i, j) for i in 1:k for j in 1:k÷2];
    repeat([CoreNode(i) for i in 1:k÷2], k ÷ 2)
])

function get_roles_count(k::Int)
    dict = Dict{Role, Int}()
    
    for i in 1:k
        dict[EdgeNode(i)] = k ÷ 2
    end

    for i in 1:k, j in 1:k÷2
        dict[AggregateNode(i, j)] = 1
    end

    for i in 1:k÷2
        dict[CoreNode(i)] = k ÷ 2
    end

    dict
end

function depthwise_oppotunistic_clustering_initialize(k, conn)
    n = nrow(conn)
    roles = Any[nothing for i in 1:n]

    cl(x) = conn[x, 1:x] ++ conn[x+1:end, x]

    # nodes with least degrees are edges
    edgelist = sort(1:n, by=x->count(cl(x)))[1:k^2÷2]

    # grouping edges oppotunistically
    for i in 1:k
        center = popfirst!(edgelist)
        roles[center] = EdgeNode(i)
        sort!(edgelist, by=x->cl(center)'cl(x))
        for j in 1:k÷2-1
            member = pop!(edgelist)
            roles[member] = EdgeNode(i)
        end
    end

    # nodes have most connections with edges are aggregators
    restlist = findall(x->x==nothing, roles)
    for i in 1:k
        sort!(restlist, by=x->sum(roles[m] == EdgeNode(i) ? 1 : roles[m] isa EdgeNode ? -1 : 0 for m in findall(cl(x))))
        for j in 1:k÷2
            member = pop!(restlist)
            roles[member] = AggregateNode(i, 0)
        end
    end

    # grouping cores oppotunistically
    corelist = findall(x->x==nothing, roles)
    for i in 1:k÷2
        center = pop!(corelist)
        roles[center] = CoreNode(i)
        sort!(corelist, by=x->cl(center)'cl(x))
        for j in 1:k÷2-1
            member = pop!(corelist)
            roles[member] = CoreNode(i)
        end
    end

    # set proper index for aggregators
    for i in 1:k
        list = findall(x->x==AggregateNode(i, 0), roles)
        for j in 1:k÷2
            sort!(list, by=x->sum(roles[m] == CoreNode(j) ? 1 : roles[m] isa CoreNode ? -1 : 0 for m in findall(cl(x))))
            member = pop!(list)
            roles[member] = AggregateNode(i, j)
        end
    end

    Vector{Role}(roles)
end

function read_cfile(cfile, n)
    I, J = Int[], Int[]
    for (a, b) in eachline(split, cfile)
        push!(I, parse(Int, a))
        push!(J, parse(Int, b))
    end
    sparse(I, J, map(x->true, I), n, n)
end
