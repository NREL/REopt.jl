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
    ElectricUtility

    Base.@kwdef struct ElectricUtility
        outage_start_timestep::Int=0  # for modeling a single outage, with critical load spliced into the baseline load ...
        outage_end_timestep::Int=0  # ... utiltity production_factor = 0 during the outage
        allow_simultaneous_export_import::Bool=true  # if true the site has two meters (in effect)
        # variables below used for minimax the expected outage cost,
        # with max taken over outage start time, expectation taken over outage duration
        outage_start_timesteps::Array{Int,1}=Int[]  # we minimize the maximum outage cost over outage start times
        outage_durations::Array{Int,1}=Int[]  # one-to-one with outage_probabilities, outage_durations can be a random variable
        outage_probabilities::Array{Real,1}=[1.0]
        outage_timesteps::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:maximum(outage_durations)
        scenarios::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:length(outage_durations)
    end

"""
Base.@kwdef struct ElectricUtility
    outage_start_timestep::Int=0  # for modeling a single outage, with critical load spliced into the baseline load ...
    outage_end_timestep::Int=0  # ... utiltity production_factor = 0 during the outage
    allow_simultaneous_export_import::Bool=true  # if true the site has two meters (in effect)
    # variables below used for minimax the expected outage cost,
    # with max taken over outage start time, expectation taken over outage duration
    outage_start_timesteps::Array{Int,1}=Int[]  # we minimize the maximum outage cost over outage start times
    outage_durations::Array{Int,1}=Int[]  # one-to-one with outage_probabilities, outage_durations can be a random variable
    outage_probabilities::Array{Real,1}=[1.0]
    outage_timesteps::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:maximum(outage_durations)
    scenarios::Union{Missing, UnitRange} = isempty(outage_durations) ? missing : 1:length(outage_durations)
end