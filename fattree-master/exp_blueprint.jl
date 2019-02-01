#!/usr/bin/env julia

using Fire
using Random
using Dates
using SparseArrays
using OhMyJulia
using JsonBuilder

struct Role
    x::Int
end

should_connect(rc, r1::Role, r2::Role) = rc[max(r1.x, r2.x), min(r1.x, r2.x)]

function gen_table_from_roles(rc, roles::Vector{Role})
    n = length(roles)
    I, J = Int[], Int[]

    for (i, ir) in enumerate(roles), (j, jr) in enumerate(view(roles, 1:i-1)) @when should_connect(rc, ir, jr)
        push!(I, i)
        push!(J, j)
    end

    sparse(I, J, map(x->true, I), n, n)
end

random_assign_roles(rd) = shuffle!([role for (role, number) in rd for i in 1:number])

function natural_error!(table)
    conns = Tuple.(findall(table))
    (x1, y1), (x2, y2) = rand(conns), rand(conns)
    table[x1, y1] = false
    table[x2, y2] = false
    table[x1, y2] = true
    table[x2, y1] = true
end

function generate(rc, rd, e::Int=0; natural::Bool=false)
    roles = random_assign_roles(rd)
    table = gen_table_from_roles(rc, roles)

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

function sa(rc, rd, conn, T::f64=0.1, decay::f64=.9999)
    roles = random_assign_roles(rd)
    # closs = initloss = count(conn .⊻ gen_table_from_roles(rc, roles))
    # closs < k ÷ 4 && return roles, (inittime = inittime, initloss = initloss, satime = 0., saloss = closs, iteration = 0)

    starttime = time()
    closs = typemax(Int)
    solution, sloss = roles, typemax(Int)
    epoch_no_gain = 0
    for epoch in 1:typemax(1)
        nroles = random_swap(roles)
        nloss = count(conn .⊻ gen_table_from_roles(rc, nroles))

        if accept(closs, nloss, T)
            roles, closs = nroles, nloss
            if closs < sloss
                solution = roles
                sloss = closs
                epoch_no_gain = 0
            end
        end

        # if epoch % 1000k == 0
        #     T *= decay
        # end

        if epoch_no_gain >= 1000length(roles)
            return solution, (satime = time() - starttime, saloss = sloss, iteration = epoch)
        end

        epoch_no_gain += 1
    end
end

function parse_blueprint(blueprint)
    list = map((x->parse.(Int, x))∘split, readlines(blueprint))
    n = maximum(maximum.(list))
    tab = map(x->BitVector(zeros(n)), 1:n)
    for (i, j) in list
        tab[i][j] = tab[j][i] = true
    end
    g = groupby(cadr, (x,y)->(car(x)+1, car(y)), ()->(0, 0), enumerate(tab)) # conn => (count, lastindex)
    id = collect(keys(g))
    rd = Dict(Role(i) => car(g[c]) for (i, c) in enumerate(id))
    rc = sparse([tab[cadr(g[id[i]])][cadr(g[id[j]])] for i in 1:length(id), j in 1:length(id)])
    rc, rd
end

@main function run(blueprint, e::Int)
    rc, rd = parse_blueprint(blueprint)
    roles, conn = generate(rc, rd, e)
    solution, info = sa(rc, rd, conn)
    origin = gen_table_from_roles(rc, roles)
    solution = gen_table_from_roles(rc, solution)
    stdout << convert(JSON, (n=sum(values(rd)), e=count(conn .⊻ origin), is_origin=count(solution .⊻ origin) == 0, info...)).str << '\n'
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