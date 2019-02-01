#!/usr/bin/env julia

using Fire
include("fattree.jl")

function natural_error!(table)
    conns = Tuple.(findall(table))
    (x1, y1), (x2, y2) = rand(conns), rand(conns)
    table[x1, y1] = false
    table[x2, y2] = false
    table[x1, y2] = true
    table[x2, y1] = true
end

"generate random rfile and cfile with errors"
@main function main(k::Int, e::Int=0; natural::Bool=false)
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

    open("rt$k-$e.txt", "w") do f
        for r in roles
            println(f, r)
        end
    end

    open("ct$k-$e.txt", "w") do f
        for i in 1:length(roles), j in 1:i-1
            table[i, j] && prt(f, i, j)
        end
    end
end