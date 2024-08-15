# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE. 

"""
calc_clean_grid_kWh(m, p)

This function calculates the clean energy fraction of the electricity from the electric utility 
by multiplying the electricity from the grid used to charge the batteries and the electricity from the grid directly serving the load 
by the clean energy fraction series.

Returns:
- clean_energy_fraction: The clean energy fraction of the grid electricity.
"""
function calc_clean_grid_kWh(m, p)
    # Calculate the grid electricity used to charge the batteries and directly serve the load
    m[:CleanGridToLoad], m[:CleanGridToBatt] = calc_grid_to_load(m, p)
    
    # Calculate the clean energy fraction from the electric utility
    m[:grid_clean_energy_series_kw] = @expression(m, [
        ts in p.time_steps], (m[:CleanGridToLoad][ts] + m[:CleanGridToBatt][ts]) * p.s.electric_utility.clean_energy_fraction_series[ts]
    )
end


"""
calc_grid_to_load(m, p)

This function calculates, for each timestep:
1. The electricity from the grid used to charge the batteries, accounting for battery losses.
2. The electricity from the grid directly serving the load.

Returns:
- CleanGridToLoad: The electricity from the grid directly serving the load.
- CleanGridToBatt: The electricity from the grid used to charge the batteries, accounting for losses.
"""

function calc_grid_to_load(m, p)
    if !isempty(p.s.storage.types.elec)
        # Calculate the grid to load through the battery, accounting for the battery losses
        m[:CleanGridToBatt] = @expression(m, [
            ts in p.time_steps], sum(
            m[:dvGridToStorage][b, ts] * p.s.storage.attr[b].charge_efficiency * p.s.storage.attr[b].discharge_efficiency 
            for b in p.s.storage.types.elec)
        )
    else
        m[:CleanGridToBatt] = zeros(length(p.time_steps))
    end
    
    # Calculate the grid serving load not through the battery
    m[:CleanGridToLoad] = @expression(m, [
        ts in p.time_steps], (
        sum(m[:dvGridPurchase][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) - 
        sum(m[:dvGridToStorage][b, ts] for b in p.s.storage.types.elec)
    ))

    return m[:CleanGridToLoad], m[:CleanGridToBatt]
end
        


