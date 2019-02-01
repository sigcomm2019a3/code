#!/usr/bin/env julia

using Fire
using Random
using Dates
using SparseArrays
using OhMyJulia
using JsonBuilder

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

function generate(k::Int, e::Int=0)
    roles = random_assign_roles(k)
    table = gen_table_from_roles(roles)
    
    einds = Set()
    while length(einds) < e
        i, j = rand(1:length(roles), 2) |> sort |> reverse
        if i != j && (i, j) ∉ einds
            push!(einds, (i, j))
            table[i, j] ⊻= true
        end
    end

    roles, table
end

@main function run(k::Int, e::Int)
    roles, conn = generate(k, e)

    starttime = time()
    solution = depthwise_oppotunistic_clustering_initialize(k, conn)
    elapsed = time() - starttime

    origin = gen_table_from_roles(roles)
    solution = gen_table_from_roles(solution)
    stdout << convert(JSON, (
        k = k,
        e = count(conn .⊻ origin),
        loss = count(solution .⊻ conn),
        time = elapsed,
        is_origin = count(solution .⊻ origin) == 0)
    ).str << '\n'
end

@main function gen_task()
    for n in 1:5, (k, e) in unique([
        (10, 0), (20, 0), (30, 0), (40, 0), (50, 0), (60, 0), (70, 0), (80, 0), (90, 0), (100, 0), # no error
        # (10, 5), (20, 5), (30, 5), (40, 5), (50, 5), (60, 5), (70, 5), (80, 5), (90, 5), (100, 5), # 5 errors
        (10, 2), (20, 4), (30, 7), (40, 9), (50, 12), (60, 14), (70, 17), (80, 19), (90, 22), (100, 24), # k/4 
        (10, 4), (20, 9), (30, 14), (40, 19), (50, 24), (60, 29), (70, 34), (80, 39), (90, 44), (100, 49), # k/2 
        (10, 5), (20, 10), (30, 15), (40, 20), (50, 25), (60, 30), (70, 35), (80, 40), (90, 45), (100, 50), # k/2 + 1
        (60, 5), (60, 10), (60, 15), (60, 20), (60, 25), (60, 30), (60, 35), (60, 40), (60, 50), (60, 60), (60, 65)
    ])
        println("tsp sh -c 'julia exp_init_only.jl run $k $e >> results.json'")
    end
end