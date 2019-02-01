#!/usr/bin/env julia

using Fire
include("fattree.jl")

get_neighbours(node, table) = [i for i in 1:nrow(table) if i != node && table[max(i, node), min(i, node)]]

"show the topology and error between rfile and cfile"
@main function visualize(k::Int, rfile, cfile)
    roles = map(eval∘Meta.parse, readlines(rfile))
    n = length(roles)

    conn = fill(false, n, n)
    for line in eachline(cfile)
        a, b = split(line)
        conn[parse(Int, a), parse(Int, b)] = true
    end

    table = gen_table_from_roles(roles)
    ploss = count(conn .⊻ table)

    positions = fill((0, 0), length(roles))

    println("""
        <svg xmlns="http://www.w3.org/2000/svg" width="$(20 + 40 * k^2 ÷ 2)" height="$(200 + 20 + 15ploss)">
        <script><![CDATA[
            function mouseover(id) {
                for (let e of document.querySelectorAll("." + id)) {
                    e.setAttribute('opacity', '1')
                    e.setAttribute('stroke-width', '2.5')
                }
            }
            function mouseleave(id) {
                for (let e of document.querySelectorAll("." + id)) {
                    e.setAttribute('opacity', '0.6')
                    e.setAttribute('stroke-width', '1')
                }
            }
        ]]></script>    
    """)

    for (j, (i, r)) in sort(filter(x->cadr(x) isa CoreNode, collect(enumerate(roles))), by=x->cadr(x).group) |> enumerate
        positions[i] = (-40 + 80 * j, 15)
        println("""
            <g class="n$i $(join(map(x->"n$x", get_neighbours(i, conn)), ' '))" opacity="0.6" font-family="sans-serif" font-size="11">
                <circle id="n$i" cx="$(-40 + 80 * j + 4)" cy="15" r="8" opacity="1" onmouseover="mouseover(this.id)" onmouseleave="mouseleave(this.id)" />
                <text x="$(-40 + 80 * j + 12)" y="18">$i</text>
            </g>
        """)
    end

    for (j, (i, r)) in sort(filter(x->cadr(x) isa AggregateNode, collect(enumerate(roles))), by=x->(cadr(x).group, cadr(x).index)) |> enumerate
        positions[i] = (-20 + 40 * j, 120)
        println("""
            <g class="n$i $(join(map(x->"n$x", get_neighbours(i, conn)), ' '))" opacity="0.6" font-family="sans-serif" font-size="11">
                <circle id="n$i" cx="$(-20 + 40 * j + 4)" cy="120" r="8" opacity="1" onmouseover="mouseover(this.id)" onmouseleave="mouseleave(this.id)" />
                <text x="$(-20 + 40 * j + 12)" y="123">$i</text>
            </g>
        """)
    end

    for (j, (i, r)) in sort(filter(x->cadr(x) isa EdgeNode, collect(enumerate(roles))), by=x->cadr(x).group) |> enumerate
        positions[i] = (-20 + 40 * j, 185)
        println("""
            <g class="n$i $(join(map(x->"n$x", get_neighbours(i, conn)), ' '))" opacity="0.6" font-family="sans-serif" font-size="11">
                <circle id="n$i" cx="$(-20 + 40 * j + 4)" cy="185" r="8" opacity="1" onmouseover="mouseover(this.id)" onmouseleave="mouseleave(this.id)" />
                <text x="$(-20 + 40 * j + 12)" y="188">$i</text>
            </g>
        """)
    end

    fixes = []
    for (x, y) in Tuple.(findall(conn .| table))
        color = if !conn[x, y]
            push!(fixes, ('+', x, y))
            "green"
        elseif !table[x, y]
            push!(fixes, ('-', x, y))
            "red"
        else
            "black"
        end

        println("""
            <line class="n$x n$y" x1="$(car(positions[x])+4)" x2="$(car(positions[y])+4)" y1="$(cadr(positions[x]))" y2="$(cadr(positions[y]))"
            stroke="$color" opacity="0.6" />
        """)
    end

    println("""<g opacity="0.8" font-family="sans-serif" font-size="11">""")
    println("""    <text x="20" y="210"> distance: $ploss </text>""")
    for (i, (op, x, y)) in enumerate(fixes)
        println("""
            <text x="20" y="$(210+15i)"
                  onmouseover="mouseover('n$x');mouseover('n$y')"
                  onmouseleave="mouseleave('n$x');mouseleave('n$y')">
                $op $x $y
            </text>
        """)
    end
    println("</g>")

    println("</svg>")
end