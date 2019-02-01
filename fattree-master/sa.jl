#!/usr/bin/env julia

using Fire
include("fattree.jl")

function hinit(k, conn)
    starttime = time()
    roles = depthwise_oppotunistic_clustering_initialize(k, conn)
    elapsed = time() - starttime
    loss = count(conn .⊻ gen_table_from_roles(roles))
    roles, loss, elapsed
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

"run simulated annealing to recover rfile from cfile"
@main function sa(k::Int, cfile, T::f64=1/k, decay::f64=.9999)
    n = length(random_assign_roles(k))
    conn = read_cfile(cfile, n)

    roles, closs, inittime = hinit(k, conn)
    println(stderr, "heuristic initialization: loss: $closs, time: $inittime")

    solution, sloss = roles, closs
    epoch_no_gain = 0
    starttime = time()

    for epoch in 1:typemax(1)
        # one method is to make a full copy of roles and tables, and discard them if rejected
        # another approch would be updating the current solution, and revert (swapback) if rejected

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
            T *= decay
            prt(stderr, epoch ÷ 1000, Dates.format(Dates.now(), "HH:MM:SS"), sloss, T)
        end

        if epoch_no_gain >= 20_000k^2
            println(stderr, "#steps: $(epoch - epoch_no_gain), time per step: $((time() - starttime) / epoch)s")
            break
        end

        epoch_no_gain += 1
    end

    foreach(println, solution)
end