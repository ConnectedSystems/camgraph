using DataFrames, CSV
using Statistics
using BlackBoxOptim

using ModelParameters

using Infiltrator



include("./network_creation.jl")

climate_data = DataFrame!(CSV.File("../tests/data/climate/climate_historic.csv", 
                          comment="#",
                          dateformat="YYYY-mm-dd"))

hist_dam_levels = DataFrame!(CSV.File("../tests/data/dam/historic_levels_for_fit.csv", dateformat="YYYY-mm-dd"))
hist_dam_releases = DataFrame!(CSV.File("../tests/data/dam/historic_releases.csv", dateformat="YYYY-mm-dd"))

# Subset to same range
last_date = hist_dam_levels.Date[end]
climate_data = climate_data[climate_data.Date .<= last_date, :]
hist_dam_releases = hist_dam_releases[hist_dam_releases.Date .<= last_date, :]

climate = Climate(climate_data, "_rain", "_evap")


function obj_func(params)
    global climate
    global hist_dam_levels
    global hist_dam_releases
    global mg
    global g
    global v_id

    node = get_prop(mg, v_id, :node)
    node = deepcopy(node)
    set_prop!(mg, v_id, :node, ModelParameters.update(node, params))

    timesteps = sim_length(climate)
    for ts in (1:timesteps)
        run_node!(mg, g, v_id, climate, ts; water_order=hist_dam_releases)
    end

    # Calculate score (NSE)
    hist_levels = hist_dam_levels[:, "Dam Level [mAHD]"]
    score = -(1.0 - sum((node.level .- hist_levels).^2) / sum((hist_levels .- mean(hist_levels)).^2))

    @infiltrate

    # reset to clear stored values
    # reset!(get_prop(mg, v_id, :node))

    return score
end


function calibrate(mg, v_id)
    target_node = Model(get_prop(mg, v_id, :node))
    @info "Calibrating:" get_prop(mg, v_id, :name)
    @info target_node

    score = bboptimize(obj_func; SearchRange=collect(target_node.bounds))

    return score
end


match = collect(filter_vertices(mg, :name, "406000"))
v_id = match[1]
target_node = Model(get_prop(mg, v_id, :node))

@info "Before call to function" target_node

@info calibrate(mg, v_id)
