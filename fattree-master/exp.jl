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

function natural_error!(table)
    conns = Tuple.(findall(table))
    (x1, y1), (x2, y2) = rand(conns), rand(conns)
    table[x1, y1] = false
    table[x2, y2] = false
    table[x1, y2] = true
    table[x2, y1] = true
end

function generate(k::Int, e::Int=0; natural::Bool=false)
    roles = random_assign_roles(k)
    table = gen_table_from_roles(roles)
    
    if natural
        for i in 1:e÷4
            natural_error!(table)
        end
    else
        einds = Set()
        while length(einds) < e
            i, j = rand(1:length(roles), 2) |> sort |> reverse
            if i != j && (i, j) ∉ einds
                push!(einds, (i, j))
                table[i, j] ⊻= true
            end
        end
    end

    roles, table
end

accept(l1, l2, T) = l1 > l2 || rand() < T / (l2 - l1)

random_swap(roles) = let n = length(roles)
    @label gen_move
    i, j = rand(1:n), rand(1:n)
    roles[i] == roles[j] && @goto gen_move
    nroles = copy(roles)
    nroles[i], nroles[j] = nroles[j], nroles[i] 
    nroles
end

function sa(k::Int, conn, T::f64=1/k, decay::f64=.9999; init=true)
    n = length(random_assign_roles(k))

    if init
        starttime = time()
        roles = depthwise_oppotunistic_clustering_initialize(k, conn)
        inittime = time() - starttime
    else
        roles = random_assign_roles(k)
        inittime = -1
    end

    closs = initloss = count(conn .⊻ gen_table_from_roles(roles))
    closs < k ÷ 4 && return roles, (inittime = inittime, initloss = initloss, satime = 0., saloss = closs, iteration = 0)
    
    starttime = time()
    solution, sloss = roles, closs
    epoch_no_gain = 0
    for epoch in 1:typemax(1)
        nroles = random_swap(roles)
        nloss = count(conn .⊻ gen_table_from_roles(nroles))

        if accept(closs, nloss, T)
            roles, closs = nroles, nloss
            if closs < sloss
                solution = roles
                sloss = closs
                epoch_no_gain = 0
            end
        end

        if epoch % 1000 == 0
            T = max(T*decay, .001)
            prt(stderr, Dates.format(Dates.now(), "HH:MM:SS"), sloss, epoch / (time() - starttime - 1))
        end

        if epoch_no_gain >= 200+4k^4
            return solution, (inittime = inittime, initloss = initloss, satime = time() - starttime, saloss = sloss, iteration = epoch)
        end

        epoch_no_gain += 1
    end
end

@main function run(k::Int, e::Int; init::Bool=false)
    roles, conn = generate(k, e)
    solution, info = sa(k, conn, init=init)
    origin = gen_table_from_roles(roles)
    solution = gen_table_from_roles(solution)
    stdout << convert(JSON, (k=k, e=count(conn .⊻ origin), is_origin=count(solution .⊻ origin) == 0, info...)).str << '\n'
end

# @main function gen_task()
#     for (k, e) in [
#         (10, 0), (20, 0), (30, 0), (40, 0), (50, 0), (60, 0), (70, 0), (80, 0),
#         (10, 5), (20, 5), (30, 5), (40, 5), (50, 5), (60, 5), (70, 5), (80, 5),
#         (60, 10), (60, 15), (60, 20), (60, 25), (60, 30), (60, 35), (60, 40)
#     ], n in 1:10
#         println("tsp sh -c 'julia exp.jl run $k $e >> results.json'")
#     end
# end