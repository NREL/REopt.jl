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
function add_thermosyphon_expressions(m,p)
	# NOTE: uncomment to use binary dv
	if !isnothing(p.s.thermosyphon)#p.s.thermosyphon.active_cooling_rate_mmbtu_per_hour > 0
		@expression(m, ThermosyphonActiveCooling[ts in p.time_steps], m[:binThermosyphonIsActiveInTS][ts] * p.s.thermosyphon.active_cooling_rate_mmbtu_per_hour)
		@expression(m, ThermosyphonElectricConsumption[ts in p.time_steps], m[:binThermosyphonIsActiveInTS][ts] * p.s.thermosyphon.active_cooling_rate_mmbtu_per_hour / p.s.thermosyphon.coefficient_of_performance_series_mmbtu_per_kwh[ts] )
	else
		@expression(m, ThermosyphonActiveCooling[ts in p.time_steps], 0)
		@expression(m, ThermosyphonElectricConsumption[ts in p.time_steps], 0)
	end

	# NOTE: uncomment to use continuous dv
	# @variable(m, dvThermosyphonActiveCooling[ts in p.time_steps] >= 0)
	# @expression(m, ThermosyphonActiveCooling[ts in p.time_steps], dvThermosyphonActiveCooling[ts])
	# @constraint(m, [ts in p.time_steps], 
	# 	m[:dvThermosyphonActiveCooling][ts] <= p.s.thermosyphon.active_cooling_rate_mmbtu_per_hour
	# )
	# @expression(m, ThermosyphonElectricConsumption[ts in p.time_steps], m[:dvThermosyphonActiveCooling][ts] / p.s.thermosyphon.coefficient_of_performance_series_mmbtu_per_kwh[ts] )
	# @constraint(m, [ts in p.s.thermosyphon.time_steps_passively_cooling],
	# 	m[:dvThermosyphonActiveCooling][ts] == 0.0
	# )
end


function add_thermosyphon_annual_active_cooling_constraint(m,p)
	# @expression(m, ThermosyphonActiveCooling[ts in p.time_steps], m[:binThermosyphonIsActiveInTS][ts] * p.s.thermosyphon.active_cooling_rate_mmbtu_per_hour)
	if !isnothing(p.s.thermosyphon)
		@constraint(m, ThermosyphonAnnualActiveCoolingCon,
			p.s.thermosyphon.min_annual_active_cooling_mmbtu <=
			sum( m[:ThermosyphonActiveCooling] )
			<= p.s.thermosyphon.min_annual_active_cooling_mmbtu + p.s.thermosyphon.active_cooling_rate_mmbtu_per_hour
		)
		@constraint(m, ThermosyphonMonthlyActiveCoolingCon[mth in p.months],
			p.s.thermosyphon.min_monthly_active_cooling_mmbtu[mth] <=
			sum( m[:ThermosyphonActiveCooling][ts] for ts in p.s.electric_tariff.time_steps_monthly[mth])
			<= p.s.thermosyphon.min_annual_active_cooling_mmbtu/2
		)
	end
end


# #added to add_variables!() instead
# function add_binThermosyphonIsActiveInTS_var(m,p)
# 	# m[Symbol("binThermosyphonIsActiveInTS"*_n)] = @variable(m, [ts in p.time_steps], Bin)
# 	@warn """Adding binary variable to model thermosyphon. 
# 			Some solvers are very slow with integer variables"""
# 	@variable(m, binThermosyphonIsActiveInTS[ts in p.time_steps], Bin)
# 	for ts in p.s.thermosyphon.time_steps_passively_cooling
#         fix(m[:binThermosyphonIsActiveInTS][ts], 0.0, force=true)
# 	end
# end
# #added to load balance constraints instead
# function add_thermosyphon_available_energy_constraint(m, p)
# 	@expression(m, ThermosyphonElectricConsumption[ts in p.time_steps], m[:binThermosyphonIsActiveInTS][ts] * p.s.thermosyphon.active_cooling_rate_mmbtu_per_hour / p.s.thermosyphon.coefficient_of_performance_series_mmbtu_per_kwh[ts] )
# 	@constraint(m, ThermosyphonAvailableEnergyCon[ts in p.s.thermosyphon.time_steps_can_actively_cool], m[:ThermosyphonElectricConsumption][ts] == sum(p.production_factor[t,ts] * p.levelization_factor[t] * m[:dvRatedProduction][t,ts] for t in p.techs.elec) +
# 		sum( m[:dvDischargeFromStorage][b,ts] for b in p.s.storage.types ) -
# 		sum( sum(m[:dvProductionToStorage][b,t,ts] for b in p.s.storage.types) +
# 			m[:dvProductionToCurtail][t,ts]
# 			for t in p.techs.elec
# 		)
# 	)
# end


# function add_thermosyphon_constraints(m, p)
#     add_binThermosyphonIsActiveInTS_var(m,p)
#     add_thermosyphon_annual_active_cooling_constraint(m,p)
#     add_thermosyphon_available_energy_constraint(m,p)
# end
