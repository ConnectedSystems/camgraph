using LightGraphs, MetaGraphs, GraphPlot
using Cairo, Compose

# g = SimpleDiGraph([0 1 0; 0 0 1; 0 0 0])
g = path_digraph(3)
mg = MetaGraph(g)

set_prop!(mg, :description, "Example stream network")

struct StreamNode
    run
end

function run(mg::MetaGraph, edge)
    this_name = get_prop(mg, src(edge), :name)
    dst_name = get_prop(mg, dst(edge), :name)

    println(this_name, " to ", dst_name)
end

set_props!(mg, 1, Dict(:name=>"Dam", :ntype=>"Dam", :attr=>StreamNode(run)))
set_props!(mg, 2, Dict(:name=>"Farm", :ntype=>"Farm", :attr=>StreamNode(run)))
set_props!(mg, 3, Dict(:name=>"Outlet", :ntype=>"End", :attr=>StreamNode(run)))


draw(PNG("test.png", 16cm, 16cm), gplot(mg))

for ed in edges(mg)
    # print(ed, get_prop(mg, idx, :name))
    node_attr = get_prop(mg, src(ed), :attr)

    node_attr.run(mg, ed)
end