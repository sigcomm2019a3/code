#!/usr/bin/env julia

using Fire
using Distributed
@everywhere include("fattree.jl")

function hinit(k, conn)
    starttime = time()
    roles = depthwise_oppotunistic_clustering_initialize(k, conn)
    elapsed = time() - starttime
    loss = count(conn .⊻ gen_table_from_roles(roles))
    roles, loss, elapsed
end

@everywhere begin
    accept(l1, l2, T) = l1 > l2 || rand() < T / (l2 - l1)

    random_swap(roles) = let n = length(roles)
        @label gen_move
        i, j = rand(1:n), rand(1:n)
        roles[i] == roles[j] && @goto gen_move
        nroles = copy(roles)
        nroles[i], nroles[j] = nroles[j], nroles[i] 
        nroles
    end

    sync(_closs, _roles, _T) = let
        global closs, roles, T = _closs, _roles, _T
        nothing
    end

    run() = let
        for i in 1:20 # try multiple times before returning
            nroles = random_swap(roles)
            nloss = count(conn .⊻ gen_table_from_roles(nroles))

            if accept(closs, nloss, T)
                global closs, roles = nloss, nroles
                return closs, i
            end
        end

        closs, 20
    end

    get_solution() = roles
end

"run simulated annealing to recover rfile from cfile"
@main function sa(k::Int, cfile, T::f64=1/k, decay::f64=.99999; timeout::Real=2k)
    @error "ourdated, see exp_sap.jl"
    n = length(random_assign_roles(k))
    @everywhere const conn = $(read_cfile(cfile, n)) # should it be const?

    roles, closs, inittime = hinit(k, conn)
    println(stderr, "heuristic initialization: loss: $closs, time: $inittime")

    solution, sloss = Ref(roles), Ref(closs)
    last_update = Ref(∞)
    starttime = time()

    task = Dict(x => 0 for x in workers()) # 0: sync, 1: run, 2: terminate
    dirty = Ref(false)

    epoch = Ref(0)

    for pid in workers()
        @async while true
            if task[pid] == 0 @debug pid, "syncing"
                task[pid] = 1
                @fetchfrom pid sync(closs, roles, T)
            elseif task[pid] == 1 @debug pid, "running"
                nloss, n = @fetchfrom pid run()
                if nloss < sloss[]
                    solution[] = @fetchfrom pid get_solution()
                    sloss[] = nloss
                    last_update[] = time()
                    dirty[] = true
                end
                epoch[] += n
            else # terminate
                break
            end
        end
    end

    while time() - last_update[] < timeout
        sleep(2)
        if dirty[] && rand() < .1
            task.vals .= 0 # hack
            dirty[] = false
        end
        T *= decay
        prt(stderr, Dates.format(Dates.now(), "HH:MM:SS"), sloss[], epoch[])
    end

    foreach(println, solution[])
    println(time() - starttime)
end