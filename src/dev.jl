using LightGraphs, MetaGraphs, GraphPlot
using Cairo, Compose
using BenchmarkTools
using DataFrames

using Waterflow
import Waterflow


g = path_digraph(3)
mg = MetaGraph(g)

set_prop!(mg, :description, "Simple network")


function run_node(mg::MetaGraph, current_node::Int)
    outflow = 0.0
    inflow = 0.0
    src_name = get_prop(mg, current_node-1, :name)
    dst_name = get_prop(mg, current_node, :name)

    if (current_node-1 < 1)
        inflow = 0.0
    else
        try
            # Get inflow from previous node
            inflow = get_prop(mg, current_node-1, :nfunc)(mg, current_node-1) 
        catch KeyError
            inflow = 0.0
        end
    end

    curr_node = get_prop(mg, current_node, :node)

    rain::Float64 = rand((1:10))
    et::Float64 = rand((1:10))

    # Calculate outflow for this node
    outflow = Waterflow.run_node(curr_node, rain, et, inflow, 0.0)

    @info "$inflow from $src_name to $dst_name, $outflow coming out"

    return outflow
end


# set_props!(mg, 1, Dict(:name=>"Dam", :ntype=>"Dam", :nfunc=>stream_node))
# set_props!(mg, 2, Dict(:name=>"Farm", :ntype=>"Farm", :nfunc=>stream_node))
# set_props!(mg, 3, Dict(:name=>"Outlet", :ntype=>"End", :nfunc=>stream_node))

# draw(PNG("test.png", 8cm, 8cm), gplot(mg; arrowlengthfrac=0.3))

# last_vertex = last(collect(vertices(mg)))
# @info "Property..."
# @info get_prop(mg, last_vertex, :nfunc)(mg, last_vertex)

@info "Ccall!"
@btime @ccall ihacres.calc_outflow(10.0::Cdouble, 8.0::Cdouble)::Cdouble
@btime @ccall ihacres.calc_outflow(11.0::Cdouble, 1.0::Cdouble)::Cdouble


function calc_outflow(flow::Float64, extractions::Float64)::Float64
    return max(0.0, flow-extractions)
end


@btime calc_outflow(10.0, 8.0)
@btime calc_outflow(11.0, 1.0)

test_node = StreamNode(
    "406265",
    100.0,  # area
    100.0,  # d 
    0.1,  # d2
    0.1,  # e 
    0.1,  # f
    54.35,  # a
    0.012,  # b
    2.5,  # storage_coef
    0.240195,  # alpha
    [100.0],  # storage
    [100.0],  # quickflow
    [100.0],  # slowflow
    [],  # outflow
    [],  # effective_rainfall
    [],  # et
    []   # inflow
)

example_graph = path_digraph(3)
example_mg = MetaGraph(example_graph)

set_prop!(example_mg, :description, "Example stream network")

set_props!(example_mg, 1, Dict(:name=>"Dam", 
                               :node=>deepcopy(test_node),
                               :nfunc=>run_node))
set_props!(example_mg, 2, Dict(:name=>"Farm", 
                               :node=>deepcopy(test_node),
                               :nfunc=>run_node))
set_props!(example_mg, 3, Dict(:name=>"Outlet", 
                               :node=>deepcopy(test_node),
                               :nfunc=>run_node))

last_vertex = last(collect(vertices(example_mg)))
@info "Running example stream..."
@info get_prop(example_mg, last_vertex, :nfunc)(example_mg, last_vertex)
