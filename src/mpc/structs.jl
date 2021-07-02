# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
"""
    MPCElectricLoad

    Base.@kwdef struct MPCElectricLoad
        loads_kw::Array{Real,1}
        critical_loads_kw::Union{Missing, Array{Real,1}} = missing
    end
"""
Base.@kwdef struct MPCElectricLoad
    loads_kw::Array{Real,1}
    critical_loads_kw::Union{Missing, Array{Real,1}} = missing
end


"""
    MPCFinancial

    Base.@kwdef struct MPCFinancial
        VoLL::Union{Array{R,1}, R} where R<:Real = 1.00
    end
"""
Base.@kwdef struct MPCFinancial
    VoLL::Union{Array{R,1}, R} where R<:Real = 1.00
end


"""
    MPCPV
```julia
Base.@kwdef struct MPCPV
    name::String="PV"
    size_kw::Real = 0
    prod_factor_series_kw::Union{Missing, Array{Real,1}} = missing
end
```
"""
Base.@kwdef struct MPCPV
    name::String="PV"
    size_kw::Real = 0
    prod_factor_series_kw::Union{Missing, Array{Real,1}} = missing
end


struct MPCElectricTariff
    energy_rates::AbstractVector{Float64}

    monthly_demand_rates::AbstractVector{Float64}
    time_steps_monthly::Array{Array{Int64,1},1}  # length = 0 or 12
    monthly_previous_peak_demands::AbstractVector{Float64}

    tou_demand_rates::AbstractVector{Float64}
    tou_demand_ratchet_timesteps::Array{Array{Int64,1},1}  # length = n_tou_demand_ratchets
    tou_previous_peak_demands::AbstractVector{Float64}

    fixed_monthly_charge::Float64
    annual_min_charge::Float64
    min_monthly_charge::Float64

    export_rates::DenseAxisArray{Array{Float64,1}}
    export_bins::Array{Symbol,1}
end


"""
    MPCElectricTariff(d::Dict)

function for parsing user inputs into 
```julia
    struct MPCElectricTariff
        monthly_previous_peak_demands::Array{Float64,1}
        energy_rates::Array{Float64,1} 

        monthly_demand_rates::Array{Float64,1}
        time_steps_monthly::Array{Array{Int64,1},1}  # length = 0 or 12

        tou_demand_rates::Array{Float64,1}
        tou_demand_ratchet_timesteps::Array{Array{Int64,1},1}  # length = n_tou_demand_ratchets
        tou_previous_peak_demands::Array{Float64,1}

        fixed_monthly_charge::Float64
        annual_min_charge::Float64
        min_monthly_charge::Float64

        export_rates::DenseAxisArray{Array{Float64,1}}
        export_bins::Array{Symbol,1}
    end
```

Keys for `d` include:

  - `energy_rates`

    - REQUIRED
    - must have length equal to `ElectricLoad.loads_kw`

  - `monthly_demand_rates`

    - default = [0]

  - `time_steps_monthly`

    - array of arrays for integer time steps that the `monthly_demand_rates` apply to
    - default = [collect(1:length(energy_rates))]

  - `monthly_previous_peak_demands`

    - default = [0]

  - `tou_demand_rates`

    - an array of time-of-use demand rates
    - must have length equal to `tou_demand_timesteps`
    - default = []

  - `tou_demand_timesteps`

    - an array of arrays for the integer time steps that apply to the `tou_demand_rates`
    - default = []

  - `tou_previous_peak_demands`

    - an array of the previous peak demands set in each time-of-use demand period
    - must have length equal to `tou_demand_timesteps`
    - default = []

  - `net_metering`

    - boolean, if `true` then customer DER export is compensated at the `energy_rates`

  - `export_rates`

    - can be a <:Real or Array{<:Real, 1}, or not provided
    - if provided, customer DER export is compensated at the `export_rates`

NOTE: if both `net_metering=true` and `export_rates` are provided then the model can choose from either option.
"""
function MPCElectricTariff(d::Dict)

    energy_rates = d["energy_rates"]

    monthly_demand_rates = get(d, "monthly_demand_rates", [0.0])
    time_steps_monthly = get(d, "time_steps_monthly", [collect(1:length(energy_rates))])
    monthly_previous_peak_demands = get(d, "monthly_previous_peak_demands", [0.0])

    tou_demand_rates = get(d, "tou_demand_rates", Float64[])
    tou_demand_timesteps = get(d, "tou_demand_timesteps", [])
    tou_previous_peak_demands = get(d, "tou_previous_peak_demands", Float64[])
    @assert length(tou_demand_rates) == length(tou_demand_timesteps) == length(tou_previous_peak_demands)

    # TODO can remove these inputs?
    fixed_monthly_charge = 0.0
    annual_min_charge = 0.0
    min_monthly_charge = 0.0

    # TODO handle tiered rates
    export_bins = [:NEM, :WHL]
    nem_rate = []
    NEM = get(d, "net_metering", false)
    if NEM
        nem_rate = [-0.999 * x for x in energy_rates]
    end
    # export_rates can be a <:Real or Array{<:Real, 1}, or not provided
    export_rates = get(d, "export_rates", nothing)
    if !isnothing(export_rates)
        export_rates = convert(Vector{Real}, export_rates)
    end
    whl_rate = create_export_rate(export_rates, length(energy_rates), 1)

    if !NEM & (sum(whl_rate) >= 0)
        export_rates = DenseAxisArray{Array{Float64,1}}(undef, [])
        export_bins = Symbol[]
    elseif !NEM
        export_bins = [:WHL]
        export_rates = DenseAxisArray([whl_rate], export_bins)
    elseif (sum(whl_rate) >= 0)
        export_bins = [:NEM]
        export_rates = DenseAxisArray([nem_rate], export_bins)
    else
        export_bins = [:NEM, :WHL]  # TODO add :EXC to align with REopt Lite API
        export_rates = DenseAxisArray([nem_rate, whl_rate], export_bins)
    end
    
    MPCElectricTariff(
        energy_rates,
        monthly_demand_rates,
        time_steps_monthly,
        monthly_previous_peak_demands,
        tou_demand_rates,
        tou_demand_timesteps,
        tou_previous_peak_demands,
        fixed_monthly_charge,
        annual_min_charge,
        min_monthly_charge,
        export_rates,
        export_bins
    )
end


"""
    MPCElecStorage
```julia
Base.@kwdef struct MPCElecStorage
    size_kw::Float64
    size_kwh::Float64
    charge_efficiency::Float64
    discharge_efficiency::Float64
    soc_min_pct::Float64
    soc_init_pct::Float64
    can_grid_charge::Bool = true
    grid_charge_efficiency::Float64
end
```
"""
Base.@kwdef struct MPCElecStorage
    size_kw::Float64
    size_kwh::Float64
    charge_efficiency::Float64
    discharge_efficiency::Float64
    soc_min_pct::Float64
    soc_init_pct::Float64
    can_grid_charge::Bool = true
    grid_charge_efficiency::Float64
end


Base.@kwdef struct MPCStorage
    types::Array{Symbol,1} = [:elec]
    size_kw::Dict{Symbol, Float64}
    size_kwh::Dict{Symbol, Float64}
    charge_efficiency::Dict{Symbol, Float64} = Dict(:elec => 0.96 * 0.975^2)
    discharge_efficiency::Dict{Symbol, Float64} = Dict(:elec => 0.96 * 0.975^2)
    soc_min_pct::Dict{Symbol, Float64} = Dict(:elec => 0.2)
    soc_init_pct::Dict{Symbol, Float64} = Dict(:elec => 0.5)
    can_grid_charge::Array{Symbol,1} = [:elec]
    grid_charge_efficiency::Dict{Symbol, Float64} = Dict(:elec => 0.96 * 0.975^2)
end


"""

NOTE: d must have symbolic keys
"""
function MPCStorage(d::Dict)
    d2 = Dict()
    d2[:can_grid_charge] = get(d, :can_grid_charge, false) ? [:elec] : Symbol[]
    if haskey(d, :can_grid_charge)
        pop!(d, :can_grid_charge)
    end
    # have to convert to all d values to DenseAxisArray's with storage type as Axis
    # (only modeling elec storage in MPC for now)
    for (k,v) in d
        d2[k] = Dict(:elec => convert(Float64, v))
    end

    return MPCStorage(; d2...)
end


"""
    MPCGenerator

struct with inner constructor:
```julia
function MPCGenerator(;
    size_kw::Real,
    fuel_cost_per_gallon::Float64 = 3.0,
    fuel_slope_gal_per_kwh::Float64 = 0.076,
    fuel_intercept_gal_per_hr::Float64 = 0.0,
    fuel_avail_gal::Float64 = 660.0,
    min_turn_down_pct::Float64 = 0.0,  # TODO change this to non-zero value
    only_runs_during_grid_outage::Bool = true,
    sells_energy_back_to_grid::Bool = false,
    om_cost_per_kwh::Float64=0.0,
    )
```
"""
struct MPCGenerator <: AbstractGenerator
    size_kw
    max_kw
    fuel_cost_per_gallon
    fuel_slope_gal_per_kwh
    fuel_intercept_gal_per_hr
    fuel_avail_gal
    min_turn_down_pct
    only_runs_during_grid_outage
    sells_energy_back_to_grid
    om_cost_per_kwh

    function MPCGenerator(;
        size_kw::Real,
        fuel_cost_per_gallon::Float64 = 3.0,
        fuel_slope_gal_per_kwh::Float64 = 0.076,
        fuel_intercept_gal_per_hr::Float64 = 0.0,
        fuel_avail_gal::Float64 = 660.0,
        min_turn_down_pct::Float64 = 0.0,  # TODO change this to non-zero value
        only_runs_during_grid_outage::Bool = true,
        sells_energy_back_to_grid::Bool = false,
        om_cost_per_kwh::Float64=0.0,
        )

        max_kw = size_kw

        new(
            size_kw,
            max_kw,
            fuel_cost_per_gallon,
            fuel_slope_gal_per_kwh,
            fuel_intercept_gal_per_hr,
            fuel_avail_gal,
            min_turn_down_pct,
            only_runs_during_grid_outage,
            sells_energy_back_to_grid,
            om_cost_per_kwh,
        )
    end
end
