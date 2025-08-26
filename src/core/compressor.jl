# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
`Compressor` is an optional REopt input with the following keys and default values:
```julia
    min_kw = 0.0, # Minimum compressor size in kW
    max_kw = 1.0e9, # Maximum compressor size in kW
    installed_cost_per_kw = 2612, # Total installed cost per kW of compressor capacity
    om_cost_per_kw = 0, # Fixed O&M cost based on power capacity (\$/kW-installed)
    om_cost_per_kwh = 0, # Variable O&M cost based on production (\$/kWh of production)
    efficiency_kwh_per_kg = 3.3, # Efficiency of the compressor in kWh of energy required per kg of hydrogen compressed
    macrs_option_years = 7, # MACRS schedule for financial analysis (5 or 7 years). Set to zero to disable
    macrs_bonus_fraction = 0.0, # Fraction of upfront project costs to depreciate in Year 1 in addition to scheduled depreciation
    macrs_itc_reduction = 0.5, # Fraction of the ITC value by which the depreciable basis is reduced
    federal_itc_fraction = 0.0, # Fraction of capital costs that are credited towards federal taxes
    federal_rebate_per_kw = 0.0, # Federal rebates based on installed capacity (\$/kW)
    state_ibi_fraction = 0.0, # Fraction of capital costs offset by state incentives
    state_ibi_max = 1.0e10, # Maximum dollar value of state percentage-based capital cost incentives
    state_rebate_per_kw = 0.0, # State rebates based on installed capacity (\$/kW) 
    state_rebate_max = 1.0e10, # Maximum state rebate
    utility_ibi_fraction = 0.0, # Fraction of capital costs offset by utility incentives
    utility_ibi_max = 1.0e10, # Maximum dollar value of utility percentage-based capital cost incentives
    utility_rebate_per_kw = 0.0, # Utility rebates based on installed capacity (\$/kW)
    utility_rebate_max = 1.0e10, # Maximum utility rebate
    production_incentive_per_kwh = 0.0, # Revenue from production incentives per kWh of production, including curtailment
    production_incentive_max_benefit = 1.0e9, # Maximum annual value in present terms of production-based incentives
    production_incentive_years = 1, # Duration of production-based incentives from installation date in years
    production_incentive_max_kw = 1.0e9, # Maximum system size eligible for production-based incentive (kW)
    can_net_meter = false, # True/False for if technology has option to participate in a net metering agreement with utility
    can_wholesale = false, # True/False for if technology has option to export production that is compensated at the wholesale_rate
    can_export_beyond_nem_limit = false, # True/False for if technology can export production beyond the annual site load (and be compensated for that energy at the export_rate_beyond_net_metering_limit)
    can_curtail= false, # True/False for if technology has the ability to curtail production
    min_turn_down_fraction = 0.0 # Minimum compressor loading in fraction of capacity (size_kw)
```
"""
struct Compressor <: AbstractCompressor
    min_kw::Real
    max_kw::Real
    installed_cost_per_kw::Real
    om_cost_per_kw::Real
    om_cost_per_kwh::Real
    efficiency_kwh_per_kg::Real
    macrs_option_years::Int
    macrs_bonus_fraction::Real
    macrs_itc_reduction::Real
    federal_itc_fraction::Real
    federal_rebate_per_kw::Real
    state_ibi_fraction::Real
    state_ibi_max::Real
    state_rebate_per_kw::Real
    state_rebate_max::Real
    utility_ibi_fraction::Real
    utility_ibi_max::Real
    utility_rebate_per_kw::Real
    utility_rebate_max::Real
    production_incentive_per_kwh::Real
    production_incentive_max_benefit::Real
    production_incentive_years::Int
    production_incentive_max_kw::Real
    can_net_meter::Bool
    can_wholesale::Bool
    can_export_beyond_nem_limit::Bool
    can_curtail::Bool
    min_turn_down_fraction::Real

    function Compressor(;
        min_kw = 0.0,
        max_kw = 1.0e9,
        installed_cost_per_kw = 2612,
        om_cost_per_kw = 0,
        om_cost_per_kwh = 0,
        efficiency_kwh_per_kg = 3.3,
        macrs_option_years = 7,
        macrs_bonus_fraction = 0.0,
        macrs_itc_reduction = 0.5,
        federal_itc_fraction = 0.0,
        federal_rebate_per_kw = 0.0,
        state_ibi_fraction = 0.0,
        state_ibi_max = 1.0e10,
        state_rebate_per_kw = 0.0,
        state_rebate_max = 1.0e10,
        utility_ibi_fraction = 0.0,
        utility_ibi_max = 1.0e10,
        utility_rebate_per_kw = 0.0,
        utility_rebate_max = 1.0e10,
        production_incentive_per_kwh = 0.0,
        production_incentive_max_benefit = 1.0e9,
        production_incentive_years = 1,
        production_incentive_max_kw = 1.0e9,
        can_net_meter = false,
        can_wholesale = false,
        can_export_beyond_nem_limit = false,
        can_curtail= false,
        min_turn_down_fraction = 0.0
        )
      
        new(
            min_kw,
            max_kw,
            installed_cost_per_kw,
            om_cost_per_kw,
            om_cost_per_kwh,
            efficiency_kwh_per_kg,
            macrs_option_years,
            macrs_bonus_fraction,
            macrs_itc_reduction,
            federal_itc_fraction,
            federal_rebate_per_kw,
            state_ibi_fraction,
            state_ibi_max,
            state_rebate_per_kw,
            state_rebate_max,
            utility_ibi_fraction,
            utility_ibi_max,
            utility_rebate_per_kw,
            utility_rebate_max,
            production_incentive_per_kwh,
            production_incentive_max_benefit,
            production_incentive_years,
            production_incentive_max_kw,
            can_net_meter,
            can_wholesale,
            can_export_beyond_nem_limit,
            can_curtail,
            min_turn_down_fraction
        )
    end
end