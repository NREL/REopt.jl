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
function add_flexible_hvac_constraints(m, p::AbstractInputs; _n="") 

    binFlexHVAC = @variable(m, binary = true)
    (N, J) = size(p.s.flexible_hvac.input_matrix)
    dvTemperature = @variable(m, [1:N, p.time_steps])
    @variable(m, lower_comfort_slack[p.time_steps] >= 0)
    @variable(m, upper_comfort_slack[p.time_steps] >= 0)

    # initialize space temperatures
    @constraint(m, dvTemperature[:, 1] .== p.s.flexible_hvac.initial_temperatures)

    # TODO time scaling for dt?

    if !isempty(p.techs.heating) && !isempty(p.techs.cooling)
        #=
        add binaries for seasonal comfort bounds
        =#
        if p.s.flexible_hvac.temperature_lower_bound_degC_heating != p.s.flexible_hvac.temperature_lower_bound_degC_cooling ||
            p.s.flexible_hvac.temperature_upper_bound_degC_heating != p.s.flexible_hvac.temperature_upper_bound_degC_cooling
            @warn "Adding binary variables for seasonal comfort limits in FlexibleHVAC model."
            @variable(m, binHeating[p.time_steps], Bin)
            @constraint(m, [t in p.techs.heating, ts in p.time_steps],
                m[Symbol("dvThermalProduction"*_n)][t, ts] <= binHeating[ts] * p.max_sizes[t]
            )
            @constraint(m, [t in p.techs.cooling, ts in p.time_steps],
                m[Symbol("dvThermalProduction"*_n)][t, ts] <= (1 - binHeating[ts]) * p.max_sizes[t]
            )
        end
        # space temperature evolution based on state-space model
        @constraint(m, [n in 1:N, ts in 2:p.time_steps[end]],
            binFlexHVAC => {dvTemperature[n, ts] == 
            sum(p.s.flexible_hvac.system_matrix[n, i] * dvTemperature[i, ts-1] for i=1:N) + 
            sum(p.s.flexible_hvac.input_matrix[n, j] * p.s.flexible_hvac.exogenous_inputs[j, ts-1] for j=1:J) + 
                p.s.flexible_hvac.input_matrix[n, p.s.flexible_hvac.hvac_input_node] * (
                sum(m[Symbol("dvThermalProduction"*_n)][t, ts-1] for t in p.techs.heating) -
                sum(m[Symbol("dvThermalProduction"*_n)][t, ts-1] for t in p.techs.cooling) 
            )}
        )

        if p.s.flexible_hvac.temperature_lower_bound_degC_heating != p.s.flexible_hvac.temperature_lower_bound_degC_cooling
            # comfort limits. not applied to initial_temperatures
            @constraint(m, [ts in 2:p.time_steps[end]], 
                binHeating[ts] * p.s.flexible_hvac.temperature_lower_bound_degC_heating + 
                (1 - binHeating[ts]) * p.s.flexible_hvac.temperature_lower_bound_degC_cooling - 
                lower_comfort_slack[ts] <= 
                dvTemperature[p.s.flexible_hvac.space_temperature_node, ts]
            )
        else
            @constraint(m, [ts in 2:p.time_steps[end]], 
                p.s.flexible_hvac.temperature_lower_bound_degC_heating - 
                lower_comfort_slack[ts] <= 
                dvTemperature[p.s.flexible_hvac.space_temperature_node, ts]
            )
        end

        if p.s.flexible_hvac.temperature_upper_bound_degC_heating != p.s.flexible_hvac.temperature_upper_bound_degC_cooling
            @constraint(m, [ts in 2:p.time_steps[end]],
                dvTemperature[p.s.flexible_hvac.space_temperature_node, ts] <= 
                binHeating[ts] * p.s.flexible_hvac.temperature_upper_bound_degC_heating + 
                (1 - binHeating[ts]) * p.s.flexible_hvac.temperature_upper_bound_degC_cooling + 
                upper_comfort_slack[ts]
            )
        else
            @constraint(m, [ts in 2:p.time_steps[end]],
                dvTemperature[p.s.flexible_hvac.space_temperature_node, ts] <= 
                p.s.flexible_hvac.temperature_upper_bound_degC_heating + 
                upper_comfort_slack[ts]
            )
        end

    elseif !isempty(p.techs.heating)
        @warn "Adding binary variables for seasonal comfort limits in FlexibleHVAC model."
        @variable(m, binHeating[p.time_steps], Bin)
        @constraint(m, [t in p.techs.heating, ts in p.time_steps],
            m[Symbol("dvThermalProduction"*_n)][t, ts] <= binHeating[ts] * p.max_sizes[t]
        )

        @constraint(m, [n in 1:N, ts in 2:p.time_steps[end]],
            binFlexHVAC => {dvTemperature[n, ts] == 
            sum(p.s.flexible_hvac.system_matrix[n, i] * dvTemperature[i, ts-1] for i=1:N) + 
            sum(p.s.flexible_hvac.input_matrix[n, j] * p.s.flexible_hvac.exogenous_inputs[j, ts-1] for j=1:J) + 
             p.s.flexible_hvac.input_matrix[n, p.s.flexible_hvac.hvac_input_node] * (
                sum(m[Symbol("dvThermalProduction"*_n)][t, ts-1] for t in p.techs.heating)
            )}
        )
        # min space temperature 
        @constraint(m, [ts in 2:p.time_steps[end]], 
            p.s.flexible_hvac.temperature_lower_bound_degC_heating - lower_comfort_slack[ts] <= 
            dvTemperature[p.s.flexible_hvac.space_temperature_node, ts]
        )
        
        # max space temperature, conditionally limited when heating
        max_natural_T = maximum(
            p.s.flexible_hvac.bau_hvac.temperatures[p.s.flexible_hvac.space_temperature_node, :]
        )
        @constraint(m, [ts in 2:p.time_steps[end]],
            dvTemperature[p.s.flexible_hvac.space_temperature_node, ts] <= 
            binHeating[ts] * p.s.flexible_hvac.temperature_upper_bound_degC_heating + 
            (1 - binHeating[ts]) * max_natural_T +
            upper_comfort_slack[ts]
        )

    elseif !isempty(p.techs.cooling)
        @warn "Adding binary variables for seasonal comfort limits in FlexibleHVAC model."
        @variable(m, binCooling[p.time_steps], Bin)
        @constraint(m, [t in p.techs.cooling, ts in p.time_steps],
            m[Symbol("dvThermalProduction"*_n)][t, ts] <= binCooling[ts] * p.max_sizes[t]
        )

        @constraint(m, [n in 1:N, ts in 2:p.time_steps[end]],
            binFlexHVAC => {dvTemperature[n, ts] == 
            sum(p.s.flexible_hvac.system_matrix[n, i] * dvTemperature[i, ts-1] for i=1:N) + 
            sum(p.s.flexible_hvac.input_matrix[n, j] * p.s.flexible_hvac.exogenous_inputs[j, ts-1] for j=1:J) -
             p.s.flexible_hvac.input_matrix[n, p.s.flexible_hvac.hvac_input_node] * (
                sum(m[Symbol("dvThermalProduction"*_n)][t, ts-1] for t in p.techs.cooling) 
            )}
        )

        # min space temperature, conditionally limited when cooling
        min_natural_T = minimum(
            p.s.flexible_hvac.bau_hvac.temperatures[p.s.flexible_hvac.space_temperature_node, :]
        )
        @constraint(m, [ts in 2:p.time_steps[end]],
            (1 - binCooling[ts]) * min_natural_T +
            binCooling[ts] * p.s.flexible_hvac.temperature_lower_bound_degC_cooling - 
            lower_comfort_slack[ts] <= 
            dvTemperature[p.s.flexible_hvac.space_temperature_node, ts]
        )

        # max space temperature
        @constraint(m, [ts in 2:p.time_steps[end]],
            dvTemperature[p.s.flexible_hvac.space_temperature_node, ts] <= 
            p.s.flexible_hvac.temperature_upper_bound_degC_cooling + 
            upper_comfort_slack[ts]
        )
    end

    dvComfortLimitViolationCost = @expression(m,  
        1e9 * sum(lower_comfort_slack[ts] + upper_comfort_slack[ts] for ts in p.time_steps)
    )

    @variable(m, dvFlexHVACcost >= 0)
    @constraint(m, binFlexHVAC => { dvFlexHVACcost >= p.s.flexible_hvac.installed_cost})
    if :TotalTechCapCosts in keys(m.obj_dict)
        m[:TotalTechCapCosts] += dvFlexHVACcost
    end

    # If not buying FlexibleHVAC then the BAU (deadband) thermal loads must be met
    # NOTE indicator constraints cannot have line breaks (fails silently)
    if !isempty(p.techs.heating)
        @constraint(m, [ts in p.time_steps],
            !binFlexHVAC => { sum(m[Symbol("dvThermalProduction"*_n)][t, ts] for t in p.techs.heating) == p.s.flexible_hvac.bau_hvac.existing_boiler_kw_thermal[ts]
            }
        )
    end
    if !isempty(p.techs.cooling)
        @constraint(m, [ts in p.time_steps],
            !binFlexHVAC => { sum(m[Symbol("dvThermalProduction"*_n)][t, ts] for t in p.techs.cooling) == p.s.flexible_hvac.bau_hvac.existing_chiller_kw_thermal[ts]
            }
        )
    end

    m[Symbol("binFlexHVAC"*_n)] = binFlexHVAC
    m[Symbol("dvTemperature"*_n)] = dvTemperature
    m[Symbol("dvComfortLimitViolationCost"*_n)] = dvComfortLimitViolationCost
    nothing
end


"""
    function add_flexible_hvac_constraints(m, p::REoptInputs{BAUScenario}; _n="")

For the BAU scenario we enforce the deadband control pattern using the values from BAU_HVAC.
"""
function add_flexible_hvac_constraints(m, p::REoptInputs{BAUScenario}; _n="") 

    # If not buying FlexibleHVAC then the BAU (deadband) thermal loads must be met
    # TODO account for different tech efficiencies in following?

    if !isempty(p.techs.heating)
        @constraint(m, [ts in p.time_steps],
            sum(m[Symbol("dvThermalProduction"*_n)][t, ts] for t in p.techs.heating) == 
            p.s.flexible_hvac.existing_boiler_kw_thermal[ts]
        )
    end
    if !isempty(p.techs.cooling)
        @constraint(m, [ts in p.time_steps],
            sum(m[Symbol("dvThermalProduction"*_n)][t, ts] for t in p.techs.cooling) == 
            p.s.flexible_hvac.existing_chiller_kw_thermal[ts]
        )
    end

    m[Symbol("binFlexHVAC"*_n)] = 0
    m[Symbol("dvTemperature"*_n)] = p.s.flexible_hvac.temperatures
    m[Symbol("dvComfortLimitViolationCost"*_n)] = 0.0
    nothing
end
