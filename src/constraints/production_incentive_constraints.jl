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
    add_prod_incent_vars_and_constraints(m, p)

When pbi_techs is not empty this function is called to add the variables and constraints for modeling production based
incentives.
"""
function add_prod_incent_vars_and_constraints(m, p)

    @variable(m, dvProdIncent[p.pbi_techs] >= 0)
    @variable(m, binProdIncent[p.pbi_techs], Bin)

	##Constraint (6a)-1: Production Incentive Upper Bound
	@constraint(m, ProdIncentUBCon[t in p.pbi_techs],
		m[:dvProdIncent][t] <= m[:binProdIncent][t] * p.pbi_max_benefit[t] * p.pbi_pwf[t] * p.third_party_factor)

	##Constraint (6a)-2: Production Incentive According to Production
	@constraint(m, IncentByProductionCon[t in p.pbi_techs],
		m[:dvProdIncent][t] <= p.hours_per_timestep * p.pbi_benefit_per_kwh[t] * p.pbi_pwf[t] * p.third_party_factor *
			sum(p.production_factor[t, ts] * m[:dvRatedProduction][t,ts] for ts in p.time_steps)
	)
	##Constraint (6b): System size max to achieve production incentive
	@constraint(m, IncentBySystemSizeCon[t in p.pbi_techs],
		m[:dvSize][t]  <= p.pbi_max_kw[t] + p.max_sizes[t] * (1 - m[:binProdIncent][t])
    )

	m[:TotalProductionIncentive] = @expression(m, sum(m[:dvProdIncent][t] for t in p.pbi_techs))
end
