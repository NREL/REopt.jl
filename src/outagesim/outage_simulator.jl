# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met
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


function simulate_outage(;init_time_step, diesel_kw, fuel_available, b, m, diesel_min_turndown, batt_kwh, batt_kw,
                    batt_roundtrip_efficiency, n_timesteps, n_steps_per_hour, batt_soc_kwh, crit_load)
    """
    Determine how long the critical load can be met with gas generator and energy storage.
    :param init_time_step: Int, initial time step
    :param diesel_kw: float, generator capacity
    :param fuel_available: float, gallons
    :param b: float, diesel fuel burn rate intercept coefficient (y = m*x + b)  [gal/hr]
    :param m: float, diesel fuel burn rate slope (y = m*x + b)  [gal/kWh]
    :param diesel_min_turndown:
    :param batt_kwh: float, battery capacity
    :param batt_kw: float, battery inverter capacity (AC rating)
    :param batt_roundtrip_efficiency:
    :param batt_soc_kwh: float, battery state of charge in kWh
    :param n_timesteps: Int, number of time steps in a year
    :param n_steps_per_hour: Int, number of time steps per hour
    :param crit_load: list of float, load after DER (PV, Wind, ...)
    :return: float, number of hours that the critical load can be met using load following
    """
    for i in 0:n_timesteps-1
        t = (init_time_step - 1 + i) % n_timesteps + 1  # for wrapping around end of year
        load_kw = crit_load[t]

        if load_kw < 0  # load is met
            if batt_soc_kwh < batt_kwh  # charge battery if there's room in the battery
                batt_soc_kwh += minimum([
                    batt_kwh - batt_soc_kwh,     # room available
                    batt_kw / n_steps_per_hour * batt_roundtrip_efficiency,  # inverter capacity
                    -load_kw / n_steps_per_hour * batt_roundtrip_efficiency,  # excess energy
                ])
            end

        else  # check if we can meet load with generator then storage
            fuel_needed = (m * maximum([load_kw, diesel_min_turndown * diesel_kw]) + b) / n_steps_per_hour
            # (gal/kWh * kW + gal/hr) * hr = gal
            if load_kw <= diesel_kw && fuel_needed <= fuel_available  # diesel can meet load
                fuel_available -= fuel_needed
                if load_kw < diesel_min_turndown * diesel_kw  # extra generation goes to battery
                    if batt_soc_kwh < batt_kwh  # charge battery if there's room in the battery
                        batt_soc_kwh += minimum([
                            batt_kwh - batt_soc_kwh,     # room available
                            batt_kw / n_steps_per_hour * batt_roundtrip_efficiency,  # inverter capacity
                            (diesel_min_turndown * diesel_kw - load_kw) / n_steps_per_hour * batt_roundtrip_efficiency  # excess energy
                        ])
                    end
                end
                load_kw = 0

            else  # diesel can meet part or no load
                if fuel_needed > fuel_available && load_kw <= diesel_kw  # tank is limiting factor
                    load_kw -= maximum([0, (fuel_available * n_steps_per_hour - b) / m])  # (gal/hr - gal/hr) * kWh/gal = kW
                    fuel_available = 0

                elseif fuel_needed <= fuel_available && load_kw > diesel_kw  # diesel capacity is limiting factor
                    load_kw -= diesel_kw
                    # run diesel gen at max output
                    fuel_available = maximum([0, fuel_available - (diesel_kw * m + b) / n_steps_per_hour])
                                                                # (kW * gal/kWh + gal/hr) * hr = gal
                else  # fuel_needed > fuel_available && load_kw > diesel_kw  # limited by fuel and diesel capacity
                    # run diesel at full capacity and drain tank
                    load_kw -= minimum([diesel_kw, maximum([0, (fuel_available * n_steps_per_hour - b) / m])])
                    fuel_available = 0
                end

                if minimum([batt_kw, batt_soc_kwh * n_steps_per_hour]) >= load_kw  # battery can carry balance
                    # prevent battery charge from going negative
                    batt_soc_kwh = maximum([0, batt_soc_kwh - load_kw / n_steps_per_hour])
                    load_kw = 0
                end
            end
        end

        if round(load_kw, digits=5) > 0  # failed to meet load in this time step
            return i / n_steps_per_hour
        end
    end

    return n_timesteps / n_steps_per_hour  # met the critical load for all time steps
end


function simulate_outages(;batt_kwh=0, batt_kw=0, pv_kw_ac_hourly=[], init_soc=0, critical_loads_kw=[], wind_kw_ac_hourly=[],
                     batt_roundtrip_efficiency=0.829, diesel_kw=0, fuel_available=0, b=0, m=0, diesel_min_turndown=0.3,
                     )
    """
    :param batt_kwh: float, battery storage capacity
    :param batt_kw: float, battery inverter capacity
    :param pv_kw_ac_hourly: list of floats, AC production of PV system
    :param init_soc: list of floats between 0 and 1 inclusive, initial state-of-charge
    :param critical_loads_kw: list of floats
    :param wind_kw_ac_hourly: list of floats, AC production of wind turbine
    :param batt_roundtrip_efficiency: roundtrip battery efficiency
    :param diesel_kw: float, diesel generator capacity
    :param fuel_available: float, gallons of diesel fuel available
    :param b: float, diesel fuel burn rate intercept coefficient (y = m*x + b*rated_capacity)  [gal/kwh/kw]
    :param m: float, diesel fuel burn rate slope (y = m*x + b*rated_capacity)  [gal/kWh]
    :param diesel_min_turndown: minimum generator turndown in fraction of generator capacity (0 to 1)
    :return: dict,
        {
            "resilience_by_timestep": r,
            "resilience_hours_min": r_min,
            "resilience_hours_max": r_max,
            "resilience_hours_avg": r_avg,
            "outage_durations": x_vals,
            "probs_of_surviving": y_vals,
            "probs_of_surviving_by_month": y_vals_group_month,
            "probs_of_surviving_by_hour_of_the_day": y_vals_group_hour,
        }
    """
    n_timesteps = length(critical_loads_kw)
    n_steps_per_hour = Int(n_timesteps / 8760)
    r = repeat([0], n_timesteps)

    if batt_kw == 0 || batt_kwh == 0
        init_soc = repeat([0], n_timesteps)  # default is 0

        if (isempty(pv_kw_ac_hourly) || (sum(pv_kw_ac_hourly) == 0)) && diesel_kw == 0
            # no pv, generator, nor battery --> no resilience
            return Dict(
                "resilience_by_timestep" => r,
                "resilience_hours_min" => 0,
                "resilience_hours_max" => 0,
                "resilience_hours_avg" => 0,
                "outage_durations" => [],
                "probs_of_surviving" => [],
            )
        end
    end

    if isempty(pv_kw_ac_hourly)
        pv_kw_ac_hourly = repeat([0], n_timesteps)
    end
    if isempty(wind_kw_ac_hourly)
        wind_kw_ac_hourly = repeat([0], n_timesteps)
    end
    load_minus_der = [ld - pv - wd for (pv, wd, ld) in zip(pv_kw_ac_hourly, wind_kw_ac_hourly, critical_loads_kw)]
    """
    Simulation starts here
    """
    # outer loop: do simulation starting at each time step
    
    for time_step in 1:n_timesteps
        r[time_step] = simulate_outage(;
            init_time_step=time_step,
            diesel_kw=diesel_kw,
            fuel_available=fuel_available,
            b=b, m=m,
            diesel_min_turndown=diesel_min_turndown,
            batt_kwh=batt_kwh,
            batt_kw=batt_kw,
            batt_roundtrip_efficiency=batt_roundtrip_efficiency,
            n_timesteps=n_timesteps,
            n_steps_per_hour=n_steps_per_hour,
            batt_soc_kwh=init_soc[time_step] * batt_kwh,
            crit_load=load_minus_der
        )
    end
    results = process_results(r, n_timesteps)
    return results
end


function process_results(r, n_timesteps)

    r_min = minimum(r)
    r_max = maximum(r)
    r_avg = round((float(sum(r)) / float(length(r))), digits=2)

    x_vals = collect(range(1, stop=Int(floor(r_max)+1)))
    y_vals = Array{Float64, 1}()

    for hrs in x_vals
        push!(y_vals, round(sum([h >= hrs ? 1 : 0 for h in r]) / n_timesteps, 
                            digits=4))
    end
    return Dict(
        "resilience_by_timestep" => r,
        "resilience_hours_min" => r_min,
        "resilience_hours_max" => r_max,
        "resilience_hours_avg" => r_avg,
        "outage_durations" => x_vals,
        "probs_of_surviving" => y_vals,
    )
end


function simulate_outages(d::Dict)
    batt_roundtrip_efficiency = d["inputs"].storage.charge_efficiency[:elec] * 
                                d["inputs"].storage.discharge_efficiency[:elec]
    if "PVtoLoad" in keys(d)
        pv_kw_ac_hourly = d["PVtoBatt"] + d["PVtoCUR"] + d["PVtoLoad"] + d["PVtoNEM"] + d["PVtoWHL"]
    else
        pv_kw_ac_hourly = repeat([0], length(d["inputs"].time_steps))
    end

    simulate_outages(;
        batt_kwh=get(d, "batt_kwh", 0), 
        batt_kw=get(d, "batt_kw", 0), 
        pv_kw_ac_hourly=pv_kw_ac_hourly,
        init_soc=d["year_one_soc_series_pct"], 
        critical_loads_kw=d["inputs"].elec_load.critical_loads_kw, 
        wind_kw_ac_hourly=[],
        batt_roundtrip_efficiency=batt_roundtrip_efficiency,
        diesel_kw=get(d, "Generator_mg_kw", get(d, "generator_kw", 0)), 
        fuel_available=d["inputs"].generator.fuel_avail_gal,
        b=d["inputs"].generator.fuel_intercept_gal_per_hr,
        m=d["inputs"].generator.fuel_slope_gal_per_kwh, 
        diesel_min_turndown=d["inputs"].generator.min_turn_down_pct
    )
end
