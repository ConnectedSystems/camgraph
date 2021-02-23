module Waterflow

using LightGraphs, MetaGraphs, Distributed, DataFrames


# Can't use string, DLL location has to be a const
# (which makes sense but still, many hours wasted!)
# https://github.com/JuliaLang/julia/issues/29602
const ihacres = "../../ihacres_nim/lib/ihacres.dll"

"""@def macro

Inline code to avoid repetitious declarations.
"""
macro def(name, definition)
    return quote
        macro $(esc(name))()
            esc($(Expr(:quote, definition)))
        end
    end
end


@def add_preprefix begin
    if !isnothing(id_prefix)
        prefix = id_prefix * prefix
    end
end


include("Node.jl")
include("StreamNode.jl")
include("DamNode.jl")
include("Climate.jl")


function run_node!(mg::MetaGraph, g::AbstractGraph, node_id::Int, climate::Climate, timestep::Int)

    curr_node = get_prop(mg, node_id, :node)
    if checkbounds(Bool, curr_node.outflow, timestep)
        # already ran for this time step so no need to recurse further
        return curr_node.outflow[timestep]
    end

    outflow = 0.0
    inflow = 0.0

    ins = inneighbors(g, node_id)
    if length(ins) == 0
        inflow = 0.0
        src_name = "Out-of-Catchment"
    else
        inflow = 0.0
        for i in ins
            src_name = get_prop(mg, i, :name)
            # Get inflow from previous node
            inflow += run_node!(mg, g, i, climate, timestep)
        end
    end

    dst_name = get_prop(mg, node_id, :name)
    curr_node = get_prop(mg, node_id, :node)

    rain, et = try
                    climate_values(curr_node, climate, timestep)
                catch e
                    if e isa BoundsError
                        # Temporary hack - if no relevant data is found, return 0
                        return 0.0
                    else
                        rethrow()
                    end
                end

    # Calculate outflow for this node
    # node_type = typeof(curr_node)
    if curr_node isa StreamNode
        outflow = get_prop(mg, node_id, :nfunc)(curr_node, rain, et, inflow, 0.0)
        # outflow = Waterflow.run_node!(curr_node, rain, et, inflow, 0.0)
    elseif curr_node isa DamNode
        water_order = float(rand((0:1000)))  # need to accept water order as a parameter
        exchange = 0.0
        outflow = get_prop(mg, node_id, :nfunc)(curr_node, rain, et, inflow, water_order, exchange)
        # outflow = Waterflow.run_node!(curr_node, rain, et, inflow, water_order, exchange)
    else
        throw(ArgumentError("Unknown node type!"))
    end

    return outflow
end

include("Network.jl")


export @def
export ihacres, StreamNode, DamNode, Climate
export find_inlets_and_outlets, create_network, create_node
export climate_values, run_node!, reset!, sim_length

end  # end module
