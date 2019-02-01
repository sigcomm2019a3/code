#!/usr/bin/env julia

using Fire

include("fattree.jl")

mutable struct Node
    role::(Role | Nothing)

    nvisit::Int
    lb::Int
    ub::Int

    score::Float64

    parent::(Node | Nothing)
    children::Vector{Node}

    Node(role, parent) = new(role, 0, 0, typemax(Int), ∞, parent, Node[])
end

import Base.show
function show(io::IO, node::Node)
    print(io, "Node(role=$(node.role == nothing ? "root" : node.role), nvisit=$(node.nvisit), lb=$(node.lb), ub=$(node.ub), score=$(node.score), nchildren=$(length(node.children)))")
end

mutable struct BNBState
    roles::Vector{Role}
    remaining::Dict{Role, Int}
    groupid::Int
    indexid::Int
    cost::Int
end

@main function bnb(k::Int, cfile, socket="/tmp/fattree_bnb")
    n = length(random_assign_roles(k))
    conn = fill(false, n, n)
    for line in eachline(cfile)
        a, b = parse.(Int, split(line))
        conn[a, b] = true
        conn[b, a] = true
    end

    root, best, solution = Node(nothing, nothing), typemax(Int), nothing

    "get state of node"
    function get_state(node)
        node == root ? BNBState([], get_roles_count(k), 1, 1, 0) : update_state!(get_state(node.parent), node)
    end

    "get state of node by updating its parent's state"
    function update_state!(state, node)
        local role = node.role

        push!(state.roles, role)
        state.remaining[role] -= 1
        if (role isa EdgeNode && role.group == state.groupid) || (role isa AggregateNode && role.group == state.groupid)
            state.groupid += 1
        end
        if (role isa CoreNode && role.group == state.indexid) || (role isa AggregateNode && role.index == state.indexid)
            state.indexid += 1
        end

        state.cost += let j = length(state.roles)
            count(should_connect(state.roles[i], role) ⊻ conn[i, j] for i in 1:j-1)
        end

        state
    end

    "select a leaf node to expand"
    function select()
        "select a promising child with best score"
        function _select_child(state, node)
            local children = filter(x->x.lb < best, node.children)
            local v, i = findmax(map(x->x.score, children))
            update_state!(state, children[i])
            state, children[i]
        end

        local state, node = get_state(root), root
        while !isempty(node.children)
            state, node = _select_child(state, node)
        end

        state, node
    end

    "estimate how promising a node is"
    function score(node)
        node.nvisit == 0 ? -(node.parent.ub + k) : -(node.ub + node.nvisit)
    end

    "branch on node, set it's children"
    function branch!(state, node)
        for (role, c) in state.remaining @when c > 0
            role isa EdgeNode && role.group > state.groupid && continue
            role isa AggregateNode && role.group > state.groupid && continue
            role isa AggregateNode && role.index > state.indexid && continue
            role isa CoreNode && role.group > state.indexid && continue

            child = Node(role, node)
            child.score = score(child)
            push!(node.children, child)
        end
    end

    "set node's lower bound and propagate through its parents, prune parent when possible"
    function bound!(state, node)
        node.lb = state.cost
        while node != root
            node.score = score(node)
            node = node.parent
            node.lb = max(node.lb, minimum(map(x->x.lb, node.children)))
            node.lb >= best && empty!(node.children)
        end
    end

    "get a heuristic solution from node"
    function simulate(state, node)
        _simulate_greedy_random_order(state)
    end

    "update visit count and upper bound recursively"
    function propagate!(node, cost)
        node.ub = min(node.ub, cost)
        node.nvisit += 1
        node.score = score(node)
        node != root && propagate!(node.parent, cost)
    end

    function _simulate_greedy_random_order(state)
        local order = randperm(n - length(state.roles)) .+ length(state.roles)
        local roles = resize!(copy(state.roles), n)
        local remaining = copy(state.remaining)
        local groupid, indexid, cost = state.groupid, state.indexid, state.cost

        for i in order
            local brole, bcost = nothing, typemax(Int)

            for (role, c) in remaining @when c > 0
                role isa EdgeNode && role.group > groupid && continue
                role isa AggregateNode && role.group > groupid && continue
                role isa AggregateNode && role.index > indexid && continue
                role isa CoreNode && role.group > indexid && continue

                # Julia sucks, the following line is much slower than current version, yet doing the same thing
                # local cost = count(should_connect(roles[j], role) ⊻ conn[i, j] for j in 1:n if isassigned(roles, j))
                local cost = let x = 0
                    for j in 1:n @when isassigned(roles, j)
                        x += should_connect(roles[j], role) != conn[i, j]
                    end
                    x
                end
                
                if cost < bcost
                    brole, bcost = role, cost
                    cost == 0 && break
                end
            end
            
            roles[i] = brole
            remaining[brole] -= 1
            if (brole isa EdgeNode && brole.group == groupid) || (brole isa AggregateNode && brole.group == groupid)
                groupid += 1
            end
            if (brole isa CoreNode && brole.group == indexid) || (brole isa AggregateNode && brole.index == indexid)
                indexid += 1
            end
            cost += bcost
        end

        if cost < best
            best, solution = cost, roles
        end

        cost
    end

    while root.lb < best
        # first, select a leaf node
        state, node = select()

        # calculate its lowerbound
        bound!(state, node)

        rand() < .001 && println("depth: $(length(state.roles)), best: $best, lb: $(node.lb), ub: $(node.ub)")

        # drop it if not promising
        node.lb >= best && continue

        # expand the node
        branch!(state, node)

        # node won't be an ending node because we only expand once an iteration. In the second last layer, the simulated
        # cost is the actual cost, so we will get the correct `best` score before touching the last layer. In the `bound!`
        # step of any ending node, the lb is it's actual cost, and must be less than or equal to the best score, so it
        # will be pruned before being `branch!`

        # randomly simulate a newly branched node
        node = rand(node.children)
        cost = simulate(state, node)

        # propagate the result of this simulation
        propagate!(node, cost)
    end

    println(best)
    println(solution)
end