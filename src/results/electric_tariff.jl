# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`ElectricTariff` results keys:
- `lifecycle_energy_cost_after_tax` lifecycle cost of energy from the grid in present value, after tax
- `year_one_energy_cost_before_tax` cost of energy from the grid over the first year, before considering tax benefits
- `lifecycle_demand_cost_after_tax` lifecycle cost of power from the grid in present value, after tax
- `year_one_demand_cost_before_tax` cost of power from the grid over the first year, before considering tax benefits
- `lifecycle_fixed_cost_after_tax` lifecycle fixed cost in present value, after tax
- `year_one_fixed_cost_before_tax` fixed cost over the first year, before considering tax benefits
- `lifecycle_min_charge_adder_after_tax` lifecycle minimum charge in present value, after tax
- `year_one_min_charge_adder_before_tax` minimum charge over the first year, before considering tax benefits
- `year_one_bill_before_tax` sum of `year_one_energy_cost_before_tax`, `year_one_demand_cost_before_tax`, `year_one_fixed_cost_before_tax`, `year_one_min_charge_adder_before_tax`, and `year_one_coincident_peak_cost_before_tax`
- `lifecycle_export_benefit_after_tax` lifecycle export credits in present value, after tax
- `year_one_export_benefit_before_tax` export credits over the first year, before considering tax benefits. A positive value indicates a benefit. 
- `lifecycle_coincident_peak_cost_after_tax` lifecycle coincident peak charge in present value, after tax
- `year_one_coincident_peak_cost_before_tax` coincident peak charge over the first year
"""
function add_electric_tariff_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `ElectricTariff` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()
    m[Symbol("Year1UtilityEnergy"*_n)] = p.hours_per_time_step * 
        sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for ts in p.time_steps, tier in 1:p.s.electric_tariff.n_energy_tiers)

    r["lifecycle_energy_cost_after_tax"] = round(value(m[Symbol("TotalEnergyChargesUtil"*_n)]) * (1 - p.s.financial.offtaker_tax_rate_fraction), digits=2)
    r["year_one_energy_cost_before_tax"] = round(value(m[Symbol("TotalEnergyChargesUtil"*_n)]) / p.pwf_e, digits=2)

    r["lifecycle_demand_cost_after_tax"] = round(value(m[Symbol("TotalDemandCharges"*_n)]) * (1 - p.s.financial.offtaker_tax_rate_fraction), digits=2)
    r["year_one_demand_cost_before_tax"] = round(value(m[Symbol("TotalDemandCharges"*_n)]) / p.pwf_e, digits=2)
    
    r["lifecycle_fixed_cost_after_tax"] = round(m[Symbol("TotalFixedCharges"*_n)] * (1 - p.s.financial.offtaker_tax_rate_fraction), digits=2)
    r["year_one_fixed_cost_before_tax"] = round(m[Symbol("TotalFixedCharges"*_n)] / p.pwf_e, digits=0)

    r["lifecycle_min_charge_adder_after_tax"] = round(value(m[Symbol("MinChargeAdder"*_n)]) * (1 - p.s.financial.offtaker_tax_rate_fraction), digits=2)
    r["year_one_min_charge_adder_before_tax"] = round(value(m[Symbol("MinChargeAdder"*_n)]) / p.pwf_e, digits=2)
                                
    r["lifecycle_export_benefit_after_tax"] = -1 * round(value(m[Symbol("TotalExportBenefit"*_n)]) * (1 - p.s.financial.offtaker_tax_rate_fraction), digits=2)
    r["year_one_export_benefit_before_tax"] = -1 * round(value(m[Symbol("TotalExportBenefit"*_n)]) / p.pwf_e, digits=0)
    r["year_one_export_benefit_after_tax"] = r["year_one_export_benefit_before_tax"] * (1 - p.s.financial.offtaker_tax_rate_fraction)

    r["lifecycle_coincident_peak_cost_after_tax"] = round(value(m[Symbol("TotalCPCharges"*_n)]) * (1 - p.s.financial.offtaker_tax_rate_fraction), digits=2)
    r["year_one_coincident_peak_cost_before_tax"] = round(value(m[Symbol("TotalCPCharges"*_n)]) / p.pwf_e, digits=2)
    
    r["year_one_bill_before_tax"] = r["year_one_energy_cost_before_tax"] + r["year_one_demand_cost_before_tax"] +
                                    r["year_one_fixed_cost_before_tax"]  + r["year_one_min_charge_adder_before_tax"] + r["year_one_coincident_peak_cost_before_tax"]
    
    r["year_one_bill_after_tax"] = r["year_one_bill_before_tax"] * (1 - p.s.financial.offtaker_tax_rate_fraction)

    # timeseries of electricity cost ($/kWh * (kW * hours per timestep))
    r["annual_electric_gross_purchase_cost_series"] = sum(Array(p.s.electric_tariff.energy_rates.*value.(m[Symbol("dvGridPurchase"*_n)].* p.hours_per_time_step)), dims=2)

    if isleapyear(p.s.electric_load.year) # end dr on Dec 30th 11:59 pm. TODO handle extra day for leap year, remove ts_shift.
        dr = DateTime(p.s.electric_load.year):Dates.Minute(Int(60*p.hours_per_time_step)):DateTime(p.s.electric_load.year,12,30,23,59)
    else
        dr = DateTime(p.s.electric_load.year):Dates.Minute(Int(60*p.hours_per_time_step)):DateTime(p.s.electric_load.year,12,31,23,59)
    end
    # Shift required to capture months identification in leap year.
    ts_shift = Int(24/p.hours_per_time_step)

    if size(p.s.electric_tariff.energy_tier_limits)[2] <= 1
        r["annual_electric_to_storage_purchase_cost_series"] = zeros(p.time_steps[end])
        r["monthly_electric_to_storage_purchase_cost_series"] = []
        # TODO add boolean dvs to track which tier is supplying power to storage (or depend dvGridToStorage on energy tiers)
        for b in p.s.storage.types.elec
            r["annual_electric_to_storage_purchase_cost_series"] .+= p.s.electric_tariff.energy_rates[:,1] .* collect(value.(m[Symbol("dvGridToStorage"*_n)][b,:])) .* p.hours_per_time_step
        end
        for mth in 1:12
            idx = findall(x -> Dates.month(x) == mth, dr)
            push!(r["monthly_electric_to_storage_purchase_cost_series"], sum(r["annual_electric_to_storage_purchase_cost_series"][idx]))
        end
    end

    r["monthly_electric_gross_purchase_cost_series"] = []
    for mth in 1:12
        idx = findall(x -> Dates.month(x) == mth, dr)
        push!(r["monthly_electric_gross_purchase_cost_series"], sum(r["annual_electric_gross_purchase_cost_series"][idx]))
    end

    if isempty(p.s.electric_tariff.monthly_demand_rates)
        r["monthly_facility_demand_cost_series"] = repeat([0], 12)
    else
        r["monthly_facility_demand_cost_series"] = Matrix(p.s.electric_tariff.monthly_demand_rates.*value.(m[Symbol("dvPeakDemandMonth")]))
    end

    # Create list, each row contains month | TOU rate | peak demand for that TOU period | rate * peak demand for a TOU period.
    r["tou_demand_cost_series"] = []
    tou_demand_charges = Dict()
    for tier in 1:p.s.electric_tariff.n_tou_demand_tiers
        for (a,b,c) in zip(
                p.s.electric_tariff.tou_demand_ratchet_time_steps,
                p.s.electric_tariff.tou_demand_rates[:,tier],
                value.(m[Symbol("dvPeakDemandTOU"*_n)][:,tier]))

            idx = a[1] + ts_shift # DateTime element to inspect for month determination. Shift ts by a day in case of leap year to capture December TOU ratchets.
            
            push!(r["tou_demand_cost_series"], string("Tier",tier,"|",monthabbr(dr[idx]),"|",b,"|",c,"|",b*c))
            
            # initialize a dict to track each month's cumulative TOU demand charges.
            if !haskey(tou_demand_charges, month(dr[idx]))
                tou_demand_charges[month(dr[idx])] = 0.0
            end
            tou_demand_charges[month(dr[idx])] += b*c
        end
    end

    r["monthly_tou_demand_cost_series"] = []
    if !isempty(tou_demand_charges)
        for mth in 1:12
            push!(r["monthly_tou_demand_cost_series"], tou_demand_charges[mth])
        end
    end

    # Cost of energy by timestep (rows) and tiers (columns)
    r["energy_charge_cost_matrix"] = p.s.electric_tariff.energy_rates
    r["monthly_demand_charge_cost_matrix"] = p.s.electric_tariff.monthly_demand_rates

    # Add NEM, WHL and EXC export rates and kW sent to each here.
    for bin in p.s.electric_tariff.export_bins
        cost_series = string(bin, "_export_rate_series")
        export_series = string(bin, "_electric_to_grid_series_kw")

        r[cost_series] = collect(p.s.electric_tariff.export_rates[bin])
        r[export_series] = collect(value.(sum(m[Symbol("dvProductionToGrid"*_n)][t, bin, :] for t in p.techs.elec)))

        r[string(bin, "_monthly_export_series_kwh")] = []
        r[string(bin, "_monthly_export_cost_benefit")] = []
        for mth in 1:12
            idx = findall(x -> Dates.month(x) == mth, dr)
            push!(r[string(bin, "_monthly_export_series_kwh")], sum(r[export_series][idx]))
            push!(r[string(bin, "_monthly_export_cost_benefit")], sum((r[cost_series].*r[export_series])[idx]))
        end
    end

    d["ElectricTariff"] = r
    nothing
end

"""
MPC `ElectricTariff` results keys:
- `energy_cost`
- `demand_cost`
- `export_benefit`
"""
function add_electric_tariff_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    m[Symbol("energy_purchased"*_n)] = p.hours_per_time_step * 
        sum(m[Symbol("dvGridPurchase"*_n)][ts] for ts in p.time_steps)

    r["energy_cost"] = round(value(m[Symbol("TotalEnergyChargesUtil"*_n)]), digits=2)

    r["demand_cost"] = round(value(m[Symbol("TotalDemandCharges"*_n)]), digits=2)
                                
    r["export_benefit"] = -1 * round(value(m[Symbol("TotalExportBenefit"*_n)]), digits=0)
    
    d["ElectricTariff"] = r
    nothing
end