function simulate_outage(;init_time_step, diesel_kw, fuel_available, b, m, diesel_min_turndown, 
                         batt_kwh, batt_kw, batt_roundtrip_efficiency, n_time_steps, n_steps_per_hour, batt_soc_kwh, crit_load)
    
    fuel_available_init = fuel_available
    batt_soc_kwh_init = batt_soc_kwh  # SOC is now directly in kWh

    outage_sims = [143]
    for i in 0:(n_time_steps - 1)
        t = (init_time_step - 1 + i) % n_time_steps + 1  # for wrapping around end of year
        load_kw = crit_load[t]
        
        # Debugging for the specified initial timesteps
        if init_time_step in outage_sims
            println("======= Timestep $t =======")
            println("Initial Battery SOC (kWh): $batt_soc_kwh_init")
            println("Initial Fuel Available (L): $fuel_available_init")
            println("Load (kW): $load_kw")
        end
        
        # Calculate generator contribution
        fuel_needed = (m * max(load_kw, diesel_min_turndown * diesel_kw) + b) / n_steps_per_hour

        if fuel_needed <= fuel_available_init
            generator_contribution = min(diesel_kw, load_kw)
            load_kw -= generator_contribution
            fuel_available_init -= (m * generator_contribution + b) / n_steps_per_hour
            init_time_step in outage_sims && println("Generator meets load. Remaining Load (kW): $load_kw, Fuel Used: $((m * generator_contribution + b) / n_steps_per_hour), Remaining Fuel (L): $fuel_available_init")
        else
            generator_contribution = max(0, (fuel_available_init * n_steps_per_hour - b) / m)
            load_kw -= generator_contribution
            fuel_available_init = 0
            init_time_step in outage_sims && println("Generator partially meets load. Remaining Load (kW): $load_kw, All fuel used.")
        end

        # Charge the battery with any excess generation
        excess_gen_kw = diesel_kw - generator_contribution
        batt_soc_kwh_init += excess_gen_kw / n_steps_per_hour * batt_roundtrip_efficiency
        batt_soc_kwh_init = min(batt_soc_kwh_init, batt_kwh)

        # Battery provides the remaining load
        if batt_soc_kwh_init * n_steps_per_hour >= load_kw
            batt_soc_kwh_init -= load_kw / n_steps_per_hour
            load_kw = 0
            init_time_step in outage_sims && println("Battery meets remaining load. New SOC (kWh): $batt_soc_kwh_init")
        else
            load_kw -= batt_soc_kwh_init * n_steps_per_hour
            init_time_step in outage_sims && println("Battery partially meets load. SOC before depletion (kWh): $batt_soc_kwh_init")
            batt_soc_kwh_init = 0
            init_time_step in outage_sims && println("Battery is empty. Remaining Load (kW): $load_kw")
        end

        if round(load_kw, digits=5) > 0
            init_time_step in outage_sims && println("System outage. Duration till outage: $(i / n_steps_per_hour) hours")
            return i / n_steps_per_hour
        end
    end

    return n_time_steps / n_steps_per_hour
end 

function simulate_outages(;batt_kwh=0, batt_kw=0, pv_kw_ac_hourly=[], init_soc=[], critical_loads_kw=[], wind_kw_ac_hourly=[],
                     batt_roundtrip_efficiency=0.829, diesel_kw=0, fuel_available=0, b=0, m=0, diesel_min_turndown=0.3)
    n_time_steps = length(critical_loads_kw)
    n_steps_per_hour = Int(n_time_steps / 8760)
    r = repeat([0.0], n_time_steps)

    if batt_kw == 0 || batt_kwh == 0
        init_soc = repeat([0], n_time_steps)  # default is 0

        if (isempty(pv_kw_ac_hourly) || (sum(pv_kw_ac_hourly) == 0)) && (isempty(wind_kw_ac_hourly) || (sum(wind_kw_ac_hourly) == 0)) && diesel_kw == 0
            # no pv, generator, wind, nor battery --> no resilience
            return Dict(
                "resilience_by_time_step" => r,
                "resilience_hours_min" => 0,
                "resilience_hours_max" => 0,
                "resilience_hours_avg" => 0,
                "outage_durations" => Int[],
                "probs_of_surviving" => Float64[],
            )
        end
    end

    if isempty(pv_kw_ac_hourly)
        pv_kw_ac_hourly = repeat([0], n_time_steps)
    end
    if isempty(wind_kw_ac_hourly)
        wind_kw_ac_hourly = repeat([0], n_time_steps)
    end
    load_minus_der = [ld - pv - wd for (pv, wd, ld) in zip(pv_kw_ac_hourly, wind_kw_ac_hourly, critical_loads_kw)]
    
    # outer loop: do simulation starting at each time step
    for time_step in 1:n_time_steps
        r[time_step] = simulate_outage(;
            init_time_step = time_step,
            diesel_kw = diesel_kw,
            fuel_available = fuel_available,
            b = b, m = m,
            diesel_min_turndown = diesel_min_turndown,
            batt_kwh = batt_kwh,
            batt_kw = batt_kw,
            batt_roundtrip_efficiency = batt_roundtrip_efficiency,
            n_time_steps = n_time_steps,
            n_steps_per_hour = n_steps_per_hour,
            batt_soc_kwh = init_soc[time_step] * batt_kwh,
            crit_load = load_minus_der
        )
    end
    results = process_results(r, n_time_steps)
    return results
end

function simulate_outages(d::Dict, p::REoptInputs; microgrid_only::Bool=false)
    batt_roundtrip_efficiency = (p.s.storage.attr["ElectricStorage"].charge_efficiency *
                                p.s.storage.attr["ElectricStorage"].discharge_efficiency)

    # TODO handle generic PV names
    pv_kw_ac_hourly = zeros(length(p.time_steps))
    if "PV" in keys(d) && !(microgrid_only && !Bool(get(d["Outages"], "PV_upgraded", false)))
        pv_kw_ac_hourly = (
            get(d["PV"], "electric_to_storage_series_kw", zeros(length(p.time_steps)))
          + get(d["PV"], "electric_curtailed_series_kw", zeros(length(p.time_steps)))
          + get(d["PV"], "electric_to_load_series_kw", zeros(length(p.time_steps)))
          + get(d["PV"], "electric_to_grid_series_kw", zeros(length(p.time_steps)))
        )
    end

    wind_kw_ac_hourly = zeros(length(p.time_steps))
    if "Wind" in keys(d) && !(microgrid_only && !Bool(get(d["Outages"], "Wind_upgraded", false)))
        wind_kw_ac_hourly = (
            get(d["Wind"], "electric_to_storage_series_kw", zeros(length(p.time_steps)))
          + get(d["Wind"], "electric_curtailed_series_kw", zeros(length(p.time_steps)))
          + get(d["Wind"], "electric_to_load_series_kw", zeros(length(p.time_steps)))
          + get(d["Wind"], "electric_to_grid_series_kw", zeros(length(p.time_steps)))
        )
    end

    batt_kwh = 0
    batt_kw = 0
    init_soc = zeros(length(p.time_steps))
    if "ElectricStorage" in keys(d)
        batt_kwh = get(d["ElectricStorage"], "size_kwh", 0)
        batt_kw = get(d["ElectricStorage"], "size_kw", 0)
        init_soc = get(d["ElectricStorage"], "soc_series_fraction", zeros(length(p.time_steps)))
    end
    if microgrid_only && !Bool(get(d["Outages"], "storage_upgraded", false))
        batt_kwh = 0
        batt_kw = 0
        init_soc = zeros(length(p.time_steps))
    end

    diesel_kw = 0
    if "Generator" in keys(d)
        diesel_kw = get(d["Generator"], "size_kw", 0)
    end
    if microgrid_only
        diesel_kw = get(d["Outages"], "generator_microgrid_size_kw", 0)
    end

	fuel_slope_gal_per_kwhe, fuel_intercept_gal_per_hr = generator_fuel_slope_and_intercept(
		electric_efficiency_full_load=p.s.generator.electric_efficiency_full_load, 
		electric_efficiency_half_load=p.s.generator.electric_efficiency_half_load,
        fuel_higher_heating_value_kwh_per_gal = p.s.generator.fuel_higher_heating_value_kwh_per_gal
	)

    simulate_outages(;
        batt_kwh = batt_kwh, 
        batt_kw = batt_kw, 
        pv_kw_ac_hourly = pv_kw_ac_hourly,
        init_soc = init_soc, 
        critical_loads_kw = p.s.electric_load.critical_loads_kw, 
        wind_kw_ac_hourly = wind_kw_ac_hourly,
        batt_roundtrip_efficiency = batt_roundtrip_efficiency,
        diesel_kw = diesel_kw, 
        fuel_available = p.s.generator.fuel_avail_gal,
        b = fuel_intercept_gal_per_hr,
        m = fuel_slope_gal_per_kwhe, 
        diesel_min_turndown = p.s.generator.min_turn_down_fraction
    )
end

function process_results(r, n_time_steps)

    r_min = minimum(r)
    r_max = maximum(r)
    r_avg = round((float(sum(r)) / float(length(r))), digits=2)

    x_vals = collect(range(1, stop=Int(floor(r_max)+1)))
    y_vals = Array{Float64, 1}()

    for hrs in x_vals
        push!(y_vals, round(sum([h >= hrs ? 1 : 0 for h in r]) / n_time_steps, 
                            digits=4))
    end
    return Dict(
        "resilience_by_time_step" => r,
        "resilience_hours_min" => r_min,
        "resilience_hours_max" => r_max,
        "resilience_hours_avg" => r_avg,
        "outage_durations" => x_vals,
        "probs_of_surviving" => y_vals,
    )
end