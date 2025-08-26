# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`Electrolyzer` results keys:
- `size_kw` Optimal electrolyzer capacity (kW)
- `year_one_hydrogen_produced_kg` Total hydrogen produced over the first year (kg)
- `year_one_electricity_consumed_kwh` Total energy consumed by the electrolyzer over the first year (kWh)
- `year_one_water_consumed_gal` Total water consumed by the electrolyzer to produce hydrogen over the first year (gal)
- `electricity_consumed_series_kw` Vector of total power consumed by the electrolyzer to produce hydrogen
- `electricity_from_grid_series_kw` Vector of power from the grid consumed by the electrolyzer to produce hydrogen 
- `electricity_from_fuel_cell_series_kw` Vector of power from the fuel cell consumed by the electrolyzer to produce hydrogen
- `electricity_from_pv_series_kw` Vector of power from PV consumed by the electrolyzer to produce hydrogen
- `hydrogen_produced_series_kg` Vector of hydrogen produced by the electrolyzer
- `water_consumed_series_gal` Vector of water consumed by the electrolyzer to produce hydrogen 

!!! note "'Series' and 'Annual' energy outputs are average annual"
    REopt performs load balances using average annual production values for technologies that include degradation. 
    Therefore, all timeseries (`_series`) and `annual_` results should be interpreted as energy outputs averaged over the analysis period. 
    
"""
function add_electrolyzer_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `Electrolyzer` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()
    r["size_kw"] = round(value(m[Symbol("dvSize"*_n)]["Electrolyzer"]), digits=4)

    ElectrolyzerConsumption = @expression(m, [ts in p.time_steps],
                                sum(p.production_factor[t, ts] * p.levelization_factor[t] * 
                                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.electrolyzer)
                            )
    r["electricity_consumed_series_kw"] = round.(value.(ElectrolyzerConsumption).data, digits=3)
    GridToElectrolyzer = @expression(m, [ts in p.time_steps],
                                m[Symbol("dvGridToElectrolyzer"*_n)][ts]
                            )
    r["electricity_from_grid_series_kw"] = round.(value.(GridToElectrolyzer).data, digits=3)
    FuelCellToElectrolyzer = @expression(m, [ts in p.time_steps],
                                sum(m[Symbol("dvProductionToElectrolyzer"*_n)][t, ts] for t in p.techs.fuel_cell)
                            )
    r["electricity_from_fuel_cell_series_kw"] = round.(value.(FuelCellToElectrolyzer).data, digits=3)
    PVToElectrolyzer = @expression(m, [ts in p.time_steps],
                                sum(m[Symbol("dvProductionToElectrolyzer"*_n)][t, ts] for t in p.techs.pv)
                            )
    r["electricity_from_pv_series_kw"] = round.(value.(PVToElectrolyzer).data, digits=3)
    r["year_one_electricity_consumed_kwh"] = round(sum(r["electricity_consumed_series_kw"]), digits=2)

    ElectrolyzerProduction = @expression(m, [ts in p.time_steps],
                            sum(p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.electrolyzer)
                            / p.s.electrolyzer.efficiency_kwh_per_kg
                        )
    r["hydrogen_produced_series_kg"] = round.(value.(ElectrolyzerProduction).data, digits=3)
    r["year_one_hydrogen_produced_kg"] = round(sum(r["hydrogen_produced_series_kg"]), digits=2)
    r["water_consumed_series_gal"] = round.(value.(ElectrolyzerProduction).data * 3.78, digits=3)
    r["year_one_water_consumed_gal"] = round(sum(r["hydrogen_produced_series_kg"]) * 3.78, digits=2)

    d["Electrolyzer"] = r

end

"""
MPC `Electrolyzer` results keys:
- `electricity_consumed_series_kw` Vector of total power consumed by the electrolyzer to produce hydrogen (kW)
- `hydrogen_produced_series_kg` Vector of hydrogen produced by the electrolyzer (kg)
"""
function add_electrolyzer_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    ElectrolyzerConsumption = @expression(m, [ts in p.time_steps],
                                sum(p.production_factor[t, ts] * p.levelization_factor[t] * 
                                m[Symbol("dvRatedProduction"*_n)][t,ts] for t in p.techs.electrolyzer)
                            )
    r["electricity_consumed_series_kw"] = round.(value.(ElectrolyzerConsumption), digits=6)

    ElectrolyzerProduction = @expression(m, [ts in p.time_steps],
                            sum(m[Symbol("dvProductionToStorage"*_n)]["HydrogenStorage", t, ts] for t in p.techs.electrolyzer)
                        )
    r["hydrogen_produced_series_kg"] = round.(value.(ElectrolyzerProduction), digits=6)
    d["Electrolyzer"] = r

end