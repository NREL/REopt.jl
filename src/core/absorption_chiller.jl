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
`AbsorptionChiller` is an optional REopt input with the following keys and default values and default values and default values:
```julia
    min_ton::Real = 0.0,
    max_ton::Real = 0.0,
    cop_thermal::Real,
    cop_electric::Real = 14.1,
    installed_cost_per_ton::Real,
    om_cost_per_ton::Real,
    macrs_option_years::Real = 0,
    macrs_bonus_fraction::Real = 0.8
```
"""
struct AbsorptionChiller <: AbstractThermalTech
    min_ton::Real
    max_ton::Real
    cop_thermal::Real
    cop_electric::Real
    installed_cost_us_dollars_per_ton::Real
    om_cost_us_dollars_per_ton::Real
    macrs_option_years::Real
    macrs_bonus_fraction::Real
    min_kw::Real
    max_kw::Real
    installed_cost_per_kw::Real
    om_cost_per_kw::Real
    function AbsorptionChiller(;
        min_ton::Real = 0.0,
        max_ton::Real = 0.0,
        cop_thermal::Real,
        cop_electric::Real = 14.1,
        installed_cost_per_ton::Real,
        om_cost_per_ton::Real,
        macrs_option_years::Real = 0,
        macrs_bonus_fraction::Real = 0.8,
        )

        min_kw = min_ton * KWH_THERMAL_PER_TONHOUR
        max_kw = max_ton * KWH_THERMAL_PER_TONHOUR
        installed_cost_per_kw = installed_cost_per_ton / KWH_THERMAL_PER_TONHOUR
        om_cost_per_kw = om_cost_per_ton / KWH_THERMAL_PER_TONHOUR

        new(
            min_ton,
            max_ton,
            cop_thermal,
            cop_electric,
            installed_cost_per_ton,
            om_cost_per_ton,
            macrs_option_years,
            macrs_bonus_fraction,
            min_kw,
            max_kw,
            installed_cost_per_kw,
            om_cost_per_kw
        )
    end
end
