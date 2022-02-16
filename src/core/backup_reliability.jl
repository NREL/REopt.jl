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
BackupReliability

BackupReliability data struct with inner constructor:
```julia
function BackupReliability(;
    gen::Float64 = 0.9998,
    gen_fts::Float64 = 0.0066, 
    gen_ftr::Float64 = 0.00157,
    num_gens::Int = 1,
    gen_capacity::Float64 = 0.0,
    num_battery_bins::Int = 100,
    max_outage_duration::Int = 0,
    marginal_survival::Bool = false,
    microgrid_only::Bool = false
)
```
"""
struct BackupReliability
    gen_oa::Float64
    gen_fts::Float64
    gen_ftr::Float64
    num_gens::Int
    gen_capacity::Float64
    num_battery_bins::Int
    max_outage_duration::Int
    marginal_survival::Bool
    microgrid_only::Bool

    function BackupReliability(;
        gen::Float64 = 0.9998,
        gen_fts::Float64 = 0.0066, 
        gen_ftr::Float64 = 0.00157,
        num_gens::Int = 0,
        gen_capacity::Float64 = 0.0,
        num_battery_bins::Int = 100,
        max_outage_duration::Int = 0,
        marginal_survival::Bool = false,
        microgrid_only::Bool = false
    )
        return new(
            gen_oa,
            gen_fts,
            gen_ftr,
            num_gens,
            gen_capacity,
            num_battery_bins,
            max_outage_duration,
            marginal_survival,
            microgrid_only
        )
    end
end