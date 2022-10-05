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
function add_ghp_constraints(m, p; _n="")
    # add_ghp_heating_elec was used in API's reopt_model.jl for "NewMaxSize" values, but these are not in REopt.jl currently
    # add_ghp_heating_elec = 1.0

    m[:GHPCapCosts] = @expression(m, p.third_party_factor *
        sum(p.ghp_installed_cost[g] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options)
    )

    m[:GHPOMCosts] = @expression(m, p.third_party_factor * p.pwf_om *
        sum(p.ghp_om_cost_year_one[g] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options)
    )

    if p.require_ghp_purchase == 1
        @constraint(m, GHPOptionSelect,
            sum(m[Symbol("binGHP"*_n)][g] for g in p.ghp_options) == 1
        )
    else
        @constraint(m, GHPOptionSelect,
            sum(m[Symbol("binGHP"*_n)][g] for g in p.ghp_options) <= 1
        )
    end
end