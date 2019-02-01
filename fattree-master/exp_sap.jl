#!/usr/bin/env julia

using Fire
using Distributed
using JsonBuilder
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
function sap(k::Int, conn, T::f64=1/k, decay::f64=.9999; init::Bool=true)
    n = length(random_assign_roles(k))
    @everywhere const conn = $conn # should it be const?

    if init
        roles, initloss, inittime = hinit(k, conn)
    else
        roles = random_assign_roles(k)
        initloss, inittime = count(conn .⊻ gen_table_from_roles(roles)), -1
    end

    solution, sloss = Ref(roles), Ref(initloss)
    starttime, epoch = time(), Ref(0)

    task = Dict(x => 0 for x in workers()) # 0: sync, 1: run, 2: terminate
    dirty = Ref(false)
    epoch_no_gain = Ref(0)

    for pid in workers()
        @async while true
            if task[pid] == 0 @debug pid, "syncing"
                task[pid] = 1
                @fetchfrom pid sync(sloss[], solution[], T)
            elseif task[pid] == 1 @debug pid, "running"
                nloss, niter = @fetchfrom pid run()
                if nloss < sloss[]
                    solution[] = @fetchfrom pid get_solution()
                    sloss[] = nloss
                    dirty[] = true
                    epoch_no_gain[] = 0
                else
                    epoch_no_gain[] += niter
                end
                epoch[] += niter
            else # terminate
                break
            end
        end
    end

    while epoch_no_gain[] < 100+k^4
        sleep(2)
        if dirty[]
            task.vals .= 0 # hack
            dirty[] = false
        end
        T = max(T*decay, .001)
        prt(stderr, Dates.format(Dates.now(), "HH:MM:SS"), sloss[], epoch[] / (time() - starttime - 1))
    end

    task.vals .= 2 # terminate all
    sleep(1)

    solution[], (inittime = inittime, initloss = initloss, satime = time() - starttime - 1, saloss = sloss[], iteration = epoch[])
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

@main function run(k::Int, e::Int; init::Bool=false)
    roles, conn = generate(k, e)
    solution, info = sap(k, conn, init=init)
    origin = gen_table_from_roles(roles)
    solution = gen_table_from_roles(solution)
    stdout << convert(JSON, (k=k, e=count(conn .⊻ origin), is_origin=count(solution .⊻ origin) == 0, info...)).str << '\n'
end
