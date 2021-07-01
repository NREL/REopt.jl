Base.@kwdef struct MPCElectricLoad
    loads_kw::Array{Real,1}
    critical_loads_kw::Union{Missing, Array{Real,1}} = missing
end


Base.@kwdef struct MPCFinancial
    VoLL::Union{Array{R,1}, R} where R<:Real = 1.00
end


Base.@kwdef struct MPCPV
    name::String="PV"
    size_kw::Real = 0
    prod_factor_series_kw::Union{Missing, Array{Real,1}} = missing
end


struct MPCElectricTariff
    previous_peak_demand::Float64
    energy_rates::Array{Float64,1} 

    monthly_demand_rates::Array{Float64,1}
    time_steps_monthly::Array{Array{Int64,1},1}  # length = 0 or 12

    tou_demand_rates::Array{Float64,1}
    tou_demand_ratchet_timesteps::Array{Array{Int64,1},1}  # length = n_tou_demand_ratchets

    fixed_monthly_charge::Float64
    annual_min_charge::Float64
    min_monthly_charge::Float64

    export_rates::DenseAxisArray{Array{Float64,1}}
    export_bins::Array{Symbol,1}
end


function MPCElectricTariff(d::Dict)

    energy_rates = d["energy_rates"]
    previous_peak_demand = get(d, "previous_peak_demand", 0.0)
    # TODO set missing values to zeros of appropriate sizes

    monthly_demand_rates = [get(d, "monthly_demand_rate", 0.0)]
    time_steps_monthly = [collect(range(1, length=length(energy_rates)))]

    tou_demand_rates = get(d, "tou_demand_rates", Float64[])
    tou_demand_timesteps = get(d, "tou_demand_timesteps", [])
    @assert length(tou_demand_rates) == length(tou_demand_timesteps)

    # TODO can remove these inputs?
    fixed_monthly_charge = 0.0
    annual_min_charge = 0.0
    min_monthly_charge = 0.0

    # TODO handle tiered rates
    export_bins = [:NEM, :WHL, :CUR]
    curtail_bins = [:CUR]
    nem_rate = [100.0 for _ in energy_rates]
    if get(d, "net_metering", false)
        nem_rate = [-0.999 * x for x in energy_rates]
    end
    # export_rates can be a <:Real or Array{<:Real, 1}, or not provided
    export_rates = get(d, "export_rates", nothing)
    whl_rate = create_export_rate(export_rates, length(energy_rates), 1)

    NEM = get(d, "net_metering", false)
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
        previous_peak_demand,
        energy_rates,
        monthly_demand_rates,
        time_steps_monthly,
        tou_demand_rates,
        tou_demand_timesteps,
        fixed_monthly_charge,
        annual_min_charge,
        min_monthly_charge,
        export_rates,
        export_bins
    )
end


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
    size_kw::DenseAxisArray{Float64,1}
    size_kwh::DenseAxisArray{Float64,1}
    charge_efficiency::DenseAxisArray{Float64,1} = DenseAxisArray([0.96 * 0.975^2], [:elec])
    discharge_efficiency::DenseAxisArray{Float64,1} = DenseAxisArray([0.96 * 0.975^2], [:elec])
    soc_min_pct::DenseAxisArray{Float64,1} = DenseAxisArray([0.2], [:elec])
    soc_init_pct::DenseAxisArray{Float64,1} = DenseAxisArray([0.5], [:elec])
    can_grid_charge::Array{Symbol,1} = [:elec]
    grid_charge_efficiency::DenseAxisArray{Float64,1} = DenseAxisArray([0.96 * 0.975^2], [:elec])
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
    # (only modeling Elec storage in MPC for now)
    for (k,v) in d
        d2[k] = DenseAxisArray([v], [:elec])
    end

    return MPCStorage(; d2...)
end


"""
    MPCGenerator

struct with inner constructor:
```
function Generator(;
    existing_kw::Real=0,
    min_kw::Real=0,
    max_kw::Real=1.0e6,
    cost_per_kw::Real=500.0,
    om_cost_per_kw::Real=10.0,
    om_cost_per_kwh::Float64=0.0,
    fuel_cost_per_gallon::Float64 = 3.0,
    fuel_slope_gal_per_kwh::Float64 = 0.076,
    fuel_intercept_gal_per_hr::Float64 = 0.0,
    fuel_avail_gal::Float64 = 660.0,
    min_turn_down_pct::Float64 = 0.0,
    only_runs_during_grid_outage::Bool = true,
    sells_energy_back_to_grid::Bool = false
)
```
!!! note
    Not using fuel_cost_per_gallon b/c we assume that any existing fuel
    is a sunk cost, and currently the model only has existing fuel determined by fuel_avail_gal.
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

    function MPCGenerator(;
        size_kw::Real,
        fuel_cost_per_gallon::Float64 = 3.0,
        fuel_slope_gal_per_kwh::Float64 = 0.076,
        fuel_intercept_gal_per_hr::Float64 = 0.0,
        fuel_avail_gal::Float64 = 660.0,
        min_turn_down_pct::Float64 = 0.0,  # TODO change this to non-zero value
        only_runs_during_grid_outage::Bool = true,
        sells_energy_back_to_grid::Bool = false
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
        )
    end
end
