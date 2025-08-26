# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`Compressor` results keys:
- `size_kw` Optimal compressor capacity (kW)
- `year_one_hydrogen_compressed_kg` Total hydrogen compressed over the first year (kg)
- `year_one_electricity_consumed_kwh` Total energy consumed by the compressor over the first year (kg)
- `electricity_consumed_series_kw` Vector of power consumed by the compressor
- `electricity_from_grid_series_kw` Vector of power from the grid consumed by the compressor
- `electricity_from_fuel_cell_series_kw` Vector of power from the fuel cell consumed by the compressor
- `hydrogen_compressed_series_kg` Vector of hydrogen compressed going into the hydrogen storage tank

!!! note "'Series' and 'Annual' energy outputs are average annual"
    REopt performs load balances using average annual production values for technologies that include degradation. 
    Therefore, all timeseries (`_series`) and `annual_` results should be interpreted as energy outputs averaged over the analysis period. 
    
"""
function add_compressor_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `Compressor` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()
    r["size_kw"] = round(value(m[Symbol("dvSize"*_n)]["Compressor"]), digits=4)

    CompressorConsumption = @expression(m, [ts in p.time_steps],
                                sum(p.production_factor[t, ts] * p.levelization_factor[t] * 
                                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.compressor)
                            )
    r["electricity_consumed_series_kw"] = round.(value.(CompressorConsumption).data, digits=3)
    FuelCellToCompressor = @expression(m, [ts in p.time_steps],
                                sum(m[Symbol("dvProductionToCompressor"*_n)][t, ts] for t in p.techs.fuel_cell)
                            )
    r["electricity_from_fuel_cell_series_kw"] = round.(value.(FuelCellToCompressor).data, digits=3)
    r["year_one_electricity_consumed_kwh"] = round(sum(r["electricity_consumed_series_kw"]), digits=2)
    GridToCompressor = @expression(m, [ts in p.time_steps],
                                m[Symbol("dvGridToCompressor"*_n)][ts]
                            )
    r["electricity_from_grid_series_kw"] = round.(value.(GridToCompressor).data, digits=3)

    if p.s.electrolyzer.require_compression
        CompressorProduction = @expression(m, [ts in p.time_steps],
                                sum(p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.compressor)
                                / p.s.compressor.efficiency_kwh_per_kg
                            )
    else
        CompressorProduction = repeat([0], length(p.time_steps))
    end

    r["hydrogen_compressed_series_kg"] = round.(value.(CompressorProduction).data, digits=3)
    r["year_one_hydrogen_compressed_kg"] = round(sum(r["hydrogen_compressed_series_kg"]), digits=2)                      

    d["Compressor"] = r

end

"""
MPC `Compressor` results keys:
- `hydrogen_compressed_series_kg` Vector of hydrogen compressed going into the hydrogen storage tank (kg)
- `electricity_consumed_series_kw` Vector of power consumed by the compressor (kW)
"""
function add_compressor_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    # Adds the `Compressor` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()
    CompressorProduction = @expression(m, [ts in p.time_steps],
                                sum(m[Symbol("dvProductionToStorage"*_n)]["HydrogenStorage", t, ts] for t in p.techs.compressor)
                            )
    r["hydrogen_compressed_series_kg"] = round.(value.(CompressorProduction), digits=3)
    
    CompressorConsumption = @expression(m, [ts in p.time_steps],
                                sum(p.production_factor[t, ts] * p.levelization_factor[t] * 
                                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.compressor)
                            )
    r["electricity_consumed_series_kw"] = round.(value.(CompressorConsumption), digits=3)
    
    d["Compressor"] = r

end