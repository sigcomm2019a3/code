#!/usr/bin/env julia

using Fire
include("fattree.jl")

"A heuristic simulated annealing that is actually more like the genetic algorithm"
@main function ga(k::Int, cfile; T::f64=.1, decay::f64=.9995, poolsize::Int=1000)
    error("unimplemented")
    n = length(random_assign_roles(k))
    conn = read_cfile(cfile, n)

    pool = [let roles = random_assign_roles(k); roles, count(conn .⊻ gen_table_from_roles(roles)) end for i in 1:poolsize]

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

        if epoch_no_gain >= 10_000 + 2000k^2
            println(stderr, "#steps: $(epoch - epoch_no_gain), time per step: $((time() - starttime) / epoch)s")
            break
        end

        epoch_no_gain += 1
    end

    foreach(println, solution)
end