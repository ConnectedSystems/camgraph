using DataFrames

abstract type NetworkNode end

@def network_node begin
    node_id::String
    area::Float64  # area in km^2
end

mutable struct StreamNode <: NetworkNode
    @network_node

    d::Float64
    d2::Float64
    e::Float64
    f::Float64
    a::Float64
    b::Float64
    storage_coef::Float64
    alpha::Float64

    storage::Array{Float64}
    quickflow::Array{Float64}
    slowflow::Array{Float64}
    outflow::Array{Float64}
    effective_rainfall::Array{Float64}
    et::Array{Float64}
    inflow::Array{Float64}
end


function get_climate_data(node::NetworkNode, climate_data::DataFrame)
    tgt::String = node.node_id
    rain_prefix = "pr_"
    et_prefix = "wvap_"

    rain = climate_data[Symbol(rain_prefix*tgt)]
    et = climate_data[Symbol(et_prefix*tgt)]

    return rain, et

end


function update_state(s_node::StreamNode, storage::Float64, e_rainfall::Float64, et::Float64, qflow_store::Float64, sflow_store::Float64, outflow::Float64)
    push!(s_node.storage, storage)
    push!(s_node.effective_rainfall, e_rainfall)
    push!(s_node.et, et)
    push!(s_node.outflow, outflow)
    
    push!(s_node.quickflow, qflow_store)
    push!(s_node.slowflow, sflow_store)
end


"""
Run node to calculate outflow and update state.

Parameters
----------
timestep: int, time step
rain: float, rainfall
evap: float, evapotranspiration
extractions: float, irrigation and other water extractions
gw_exchange: float, flux in ML - positive is contribution to stream, negative is infiltration
loss: float,

Returns
----------
float, outflow from node
"""
function run_node(s_node::StreamNode, 
                  rain::Float64, 
                  evap::Float64, 
                  inflow::Float64, 
                  ext::Float64, 
                  gw_exchange::Float64=0.0, 
                  loss::Float64=0.0)::Float64
    arr_len = length(s_node.storage)
    current_store = s_node.storage[arr_len]

    interim_results = [0.0, 0.0, 0.0]
    @ccall ihacres.calc_ft_interim(interim_results::Ptr{Cdouble}, 
                                   current_store::Cdouble, 
                                   rain::Cdouble, 
                                   s_node.d::Cdouble, 
                                   s_node.d2::Cdouble, 
                                   s_node.alpha::Cdouble)::Cvoid

    (mf, e_rainfall, recharge) = interim_results

    et::Float64 = @ccall ihacres.calc_ET(
        s_node.e::Cdouble,
        evap::Cdouble,
        mf::Cdouble,
        s_node.f::Cdouble,
        s_node.d::Cdouble
    )::Cdouble

    cmd::Float64 = @ccall ihacres.calc_cmd(
        current_store::Cdouble,
        rain::Cdouble,
        s_node.d::Cdouble,
        s_node.d2::Cdouble,
        s_node.alpha::Cdouble
    )::Cdouble

    # var inflow = 0.0
    # for nid in s_node.prev_node:
    #     inflow += s_node.prev_node[nid].run(timestep, rain_evap, ext)
    # # End for
    push!(s_node.inflow, inflow)

    flow_results = [0.0, 0.0, 0.0]
    @ccall ihacres.calc_ft_flows(
        flow_results::Ptr{Cdouble},
        s_node.quickflow[arr_len]::Cdouble, 
        s_node.slowflow[arr_len]::Cdouble,
        e_rainfall::Cdouble, 
        recharge::Cdouble, 
        s_node.area::Cdouble,
        s_node.a::Cdouble, 
        s_node.b::Cdouble, 
        loss::Cdouble
    )::Cvoid

    (quick_store, slow_store, outflow) = flow_results

    # if self.next_node:  # and ('dam' not in self.next_node.node_type):
    #     cmd, outflow = routing(cmd, s_node.storage_coef, inflow, outflow, ext, gamma=gw_exchange)
    # else:
    #     outflow = calc_outflow(outflow, ext)
    # # End if
    routing_res = [0.0, 0.0]
    @ccall ihacres.routing(
        routing_res::Ptr{Cdouble},
        cmd::Cdouble,
        s_node.storage_coef::Cdouble,
        inflow::Cdouble,
        outflow::Cdouble,
        ext::Cdouble,
        gw_exchange::Cdouble)::Cvoid

    (cmd, outflow) = routing_res

    # TODO: Calc stream level
    # if self.formula_type == 1:
    #     waterlevel = 1.0 * np.exp

    #       if (formula.eq.1) then
    # c      write(*,*) 'i'
    #        waterlevel=1.0d0
    #      :  *exp(par(1))*(tmp_flow**par(2))
    #      :  *1.0d0/((1.0d0+(tmp_flow/par(3))**par(4))**(par(5)/par(4)))
    #      :  *exp(par(6)/(1+exp(-par(7)*par(8))*tmp_flow**par(7)))
    #      :  +CTF

    update_state(s_node, cmd, e_rainfall, et, quick_store, slow_store, outflow)

    return outflow
end
