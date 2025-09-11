# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`HydrogenStorage` results keys:
- `size_kg` Optimal hydrogen storage capacity (kg)
- `soc_series_fraction` Vector of normalized (0-1) state of charge values 
- `storage_to_hydrogen_load_series_kg` Vector of hydrogen discharged from storage to meet the hydrogen load
- `initial_capital_cost` Upfront capital cost for the hydrogen storage tank
"""
function add_hydrogen_storage_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict, b::String; _n="")
    # Adds the `HydrogenStorage` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()
    r["size_kg"] = round(value(m[Symbol("dvStorageEnergy"*_n)][b]), digits=3)

    soc = (m[Symbol("dvStoredEnergy"*_n)][b, ts] for ts in p.time_steps)
    r["soc_series_fraction"] = round.(value.(soc) ./ r["size_kg"], digits=6)

    discharge = (m[Symbol("dvDischargeFromStorage"*_n)][b, ts] for ts in p.time_steps)
    r["storage_to_hydrogen_load_series_kg"] = round.(value.(discharge), digits=3)

    r["initial_capital_cost"] = round(r["size_kg"] * p.s.storage.attr[b].installed_cost_per_kg, digits = 2)

    d[b] = r
    nothing
end


"""
MPC `HydrogenStorage` results keys:
- `soc_series_fraction` Vector of normalized (0-1) state of charge values 
- `discharge_from_storage_series_kg` Vector of hydrogen discharged from storage to meet the hydrogen load and serve the fuel cell
"""
function add_hydrogen_storage_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict, b::String; _n="")
    r = Dict{String, Any}()

    soc = (m[Symbol("dvStoredEnergy"*_n)][b, ts] for ts in p.time_steps)
    r["soc_series_fraction"] = round.(value.(soc) ./ p.s.storage.attr[b].size_kg, digits=6)

    discharge = (m[Symbol("dvDischargeFromStorage"*_n)][b, ts] for ts in p.time_steps)
    r["discharge_from_storage_series_kg"] = round.(value.(discharge), digits=3)

    d[b] = r
    nothing
end