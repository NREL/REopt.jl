# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`HydrogenLoad` results keys:
- `load_series_kg` Vector of site hydrogen load (kg) in every time step
- `critical_load_series_kg` Vector of site critical hydrogen load (kg) in every time step
- `annual_calculated_kg` Sum of the `load_series_kg`

!!! note "'Series' and 'Annual' energy outputs are average annual"
	REopt performs load balances using average annual production values for technologies that include degradation. 
	Therefore, all timeseries (`_series`) and `annual_` results should be interpreted as energy outputs averaged over the analysis period. 

"""
function add_hydrogen_load_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `HydrogenLoad` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()

    r["load_series_kg"] = p.s.hydrogen_load.loads_kg
    r["critical_load_series_kg"] = p.s.hydrogen_load.critical_loads_kg
    r["annual_calculated_kg"] = round(sum(r["load_series_kg"]), digits=2)
    # r["annual_calculated_kg"] = round(
    #     sum(r["load_series_kg"]) / p.s.settings.time_steps_per_hour, digits=2
    # )
    
    d["HydrogenLoad"] = r
    nothing
end


"""
MPC `HydrogenLoad` results keys:
- `load_series_kg` Vector of site hydrogen consumption (kg) over the MPC horizon
"""
function add_hydrogen_load_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    # Adds the `HydrogenLoad` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()

    r["load_series_kg"] = p.s.hydrogen_load.loads_kg
    
    d["HydrogenLoad"] = r
    nothing
end