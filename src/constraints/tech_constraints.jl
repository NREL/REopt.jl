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
function add_tech_size_constraints(m, p; _n="")

    # PV techs can be constrained by space available based on location at site (roof, ground, both)
    @constraint(m, [loc in p.pvlocations],
        sum(m[Symbol("dvSize"*_n)][t] * p.pv_to_location[t][loc] for t in p.pvtechs) <= p.maxsize_pv_locations[loc]
    )

    # max size limit
    @constraint(m, [t in p.techs],
        m[Symbol("dvSize"*_n)][t] <= p.max_sizes[t]
    )

    ##Constraint (7c): Minimum size for each tech
    @constraint(m, [t in p.techs],
        m[Symbol("dvSize"*_n)][t] >= p.min_sizes[t]
    )

    @constraint(m, [t in p.techs],
        m[Symbol("dvPurchaseSize"*_n)][t] >= m[Symbol("dvSize"*_n)][t] - p.existing_sizes[t]
    )

    ## Constraint (7d): Non-turndown technologies are always at rated production
    @constraint(m, [t in p.techs_no_turndown, ts in p.time_steps],
        m[Symbol("dvRatedProduction"*_n)][t,ts] == m[Symbol("dvSize"*_n)][t]
    )
end