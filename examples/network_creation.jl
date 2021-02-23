using YAML
using LightGraphs, MetaGraphs
using DataFrames, CSV

import ModelParameters: update, update!, Model
using Waterflow

using Infiltrator


network = YAML.load_file("../tests/data/AWRA_R_Network/campaspe_network.yml")
g, mg = create_network("Example Network", network)

inlets, outlets = find_inlets_and_outlets(g)

@info "Network has the following inlets and outlets:" inlets outlets
